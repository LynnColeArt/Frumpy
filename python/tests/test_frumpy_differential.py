"""Execute compiled Frumpy against NumPy using the same shapes, strides and values."""

import subprocess

import numpy as np
import pytest


def encode_array(array):
    array = np.asarray(array)
    strides = tuple(stride // array.itemsize for stride in array.strides)
    low = sum(min(0, (n - 1) * s) for n, s in zip(array.shape, strides)) if array.size else 0
    high = sum(max(0, (n - 1) * s) for n, s in zip(array.shape, strides)) if array.size else -1
    storage = np.zeros(high - low + 1, dtype=array.dtype)
    for index in np.ndindex(array.shape):
        storage[-low + sum(i * s for i, s in zip(index, strides))] = array[index]
    values = (str(int(x)) if array.dtype.kind == "b" else str(float(x)) for x in storage)
    return "\n".join([
        f"{array.ndim} {1 - low} {storage.size}",
        " ".join(map(str, array.shape)), " ".join(map(str, strides)), " ".join(values),
    ]) + "\n"


def execute(driver, operation, *arrays, axis=-1, side=0, indices=None):
    payload = f"{operation} {axis} {side}\n" + "".join(encode_array(a) for a in arrays)
    if indices is not None:
        payload += f"{len(indices)}\n" + " ".join(map(str, indices)) + "\n"
    run = subprocess.run([str(driver)], input=payload, capture_output=True, text=True, timeout=10)
    assert run.returncode == 0, f"{operation} crashed:\n{run.stdout}\n{run.stderr}"
    lines = run.stdout.splitlines()
    status = int(lines[0])
    if status:
        return status, None
    rank = int(lines[1])
    shape = tuple(map(int, lines[2].split()))
    strides = tuple(map(int, lines[3].split()))
    offset, c_flag, f_flag, owns = lines[4].split()
    assert len(shape) == rank == len(strides)
    assert owns == "T", f"{operation} must own its result"
    dtype = np.int64 if operation in ("argsort", "searchsorted", "nonzero") else np.float64
    if operation.endswith("_r32"):
        dtype = np.float32
    itemsize = np.dtype(dtype).itemsize
    storage = np.fromstring(lines[5] if len(lines) > 5 else "", sep=" ", dtype=dtype)
    result = np.ndarray(shape, dtype=dtype, buffer=storage, offset=(int(offset) - 1) * itemsize,
                        strides=tuple(s * itemsize for s in strides))
    assert result.flags.c_contiguous == (c_flag == "T")
    assert result.flags.f_contiguous == (f_flag == "T")
    return status, result


def check(driver, operation, expected, *arrays, **kwargs):
    status, actual = execute(driver, operation, *arrays, **kwargs)
    assert status == 0, f"{operation} returned Frumpy status {status}"
    assert actual.shape == np.shape(expected)
    if actual.dtype.kind == "i":
        np.testing.assert_array_equal(actual, expected)
    else:
        np.testing.assert_allclose(actual, expected, rtol=1e-13, atol=1e-13, equal_nan=True)


def layouts():
    base = np.array([[3., 1., 3.], [6., 5., 4.]])
    return [base, np.asfortranarray(base), base.T, base[:, ::-1], base[::-1, ::2],
            np.broadcast_to(base[:1], (3, 3)), np.empty((0, 3)), np.empty((2, 0)),
            np.array([np.nan, 2., -np.inf, np.nan, np.inf, -0., 0., 2.])]


@pytest.mark.parametrize("source", layouts())
@pytest.mark.parametrize("operation", ["sort", "argsort"])
def test_sorting(frumpy_driver, source, operation):
    for axis in range(-source.ndim, source.ndim):
        expected = getattr(np, operation)(source, axis=axis, kind="stable")
        check(frumpy_driver, operation, expected, source, axis=axis)


@pytest.mark.parametrize("axis", [-2, -1, 0, 1, 99])
@pytest.mark.parametrize("operation", ["sort", "argsort"])
def test_sort_scalar(frumpy_driver, axis, operation):
    source = np.array(3.)
    try:
        expected = getattr(np, operation)(source, axis=axis, kind="stable")
    except (ValueError, IndexError):
        assert execute(frumpy_driver, operation, source, axis=axis)[0] == 2
    else:
        check(frumpy_driver, operation, expected, source, axis=axis)


@pytest.mark.parametrize("source", [np.array([]), np.array([1., 3., 3., 7.]),
    np.array([-np.inf, 0., 2., np.inf, np.nan, np.nan]),
    np.array([7., 3., 3., 1.])[::-1], np.array([1., 99., 3., 99., 7.])[::2]])
@pytest.mark.parametrize("values", [np.array([np.nan, -np.inf, 0., 1., 3., 8., np.inf]),
    np.array([[3., 2.], [1., 0.]]).T, np.array(3.), np.empty((0, 2))])
@pytest.mark.parametrize("side", ["left", "right"])
def test_searchsorted(frumpy_driver, source, values, side):
    check(frumpy_driver, "searchsorted", np.searchsorted(source, values, side=side),
          source, values, side=int(side == "right"))


@pytest.mark.parametrize("condition,lhs,rhs", [
    (np.array([[True], [False]]), np.arange(3.), np.array(-1.)),
    (np.empty((0, 3), dtype=bool), np.ones((1, 3)), np.array(2.)),
    (np.array(True), np.empty((2, 0)), np.ones((1, 1))),
    (np.array(False), np.array(1.), np.array(2.)),
    (np.array([[True, False], [False, True]]).T, np.arange(4.).reshape(2, 2)[:, ::-1],
     np.asfortranarray(np.arange(4.).reshape(2, 2))),
])
def test_where(frumpy_driver, condition, lhs, rhs):
    check(frumpy_driver, "where", np.where(condition, lhs, rhs), condition, lhs, rhs)


@pytest.mark.parametrize("source", layouts()[:-1] + [np.array(5.)])
def test_take(frumpy_driver, source):
    indices = [0, -1, 0] if source.size else []
    check(frumpy_driver, "take", np.take(source, indices), source, indices=indices, side=1)
    for axis in range(-source.ndim, source.ndim):
        indices = [0, -1, 0] if source.shape[axis] else []
        check(frumpy_driver, "take", np.take(source, indices, axis=axis), source,
              indices=indices, axis=axis)


@pytest.mark.parametrize("source", layouts()[:-1] + [np.array(5.)])
@pytest.mark.parametrize("operation", ["concatenate", "stack"])
def test_join(frumpy_driver, source, operation):
    rhs = source.copy(order="K") + 10
    rank = source.ndim + (operation == "stack")
    for axis in range(-rank, rank):
        check(frumpy_driver, operation, getattr(np, operation)([source, rhs], axis=axis),
              source, rhs, axis=axis)


@pytest.mark.parametrize("mask", [np.array(True), np.array(False), np.empty((0, 3), dtype=bool),
    np.array([[True, False, True], [False, True, False]])[:, ::-1],
    np.asfortranarray(np.array([[True, False], [False, True]])),
    np.broadcast_to(np.array([True, False]), (3, 2))])
def test_nonzero_flat_subset(frumpy_driver, mask):
    check(frumpy_driver, "nonzero", np.flatnonzero(mask), mask)


@pytest.mark.parametrize("operation", ["sort", "argsort", "take", "stack", "concatenate"])
@pytest.mark.parametrize("axis", [-5, 5])
def test_invalid_axes(frumpy_driver, operation, axis):
    a = np.arange(6.).reshape(2, 3)
    arrays = (a, a) if operation in ("stack", "concatenate") else (a,)
    kwargs = {"indices": [0]} if operation == "take" else {}
    assert execute(frumpy_driver, operation, *arrays, axis=axis, **kwargs)[0] == 2


def test_invalid_inputs(frumpy_driver):
    a = np.arange(6.).reshape(2, 3)
    assert execute(frumpy_driver, "where", np.ones((4,), dtype=bool), a, a)[0] == 1
    assert execute(frumpy_driver, "take", a, axis=1, indices=[3])[0] == 1
    assert execute(frumpy_driver, "take", a, axis=1, indices=[-4])[0] == 1
    assert execute(frumpy_driver, "stack", a, np.ones((3, 2)), axis=0)[0] == 1
    assert execute(frumpy_driver, "concatenate", a, np.ones((3, 2)), axis=0)[0] == 1
    assert execute(frumpy_driver, "searchsorted", a, np.array(2.))[0] == 1


def test_vertical_slice(frumpy_driver):
    expected = (np.zeros((2, 3)) + np.full(3, 2.)).reshape(3, 2).sum(axis=1)
    check(frumpy_driver, "vertical_slice", expected)


@pytest.mark.parametrize("axis", [-1, 0])
def test_take_scalar_axis(frumpy_driver, axis):
    a = np.array(5.)
    check(frumpy_driver, "take", np.take(a, [0, -1], axis=axis), a,
          axis=axis, indices=[0, -1])


@pytest.mark.parametrize("axis", [0, 1, -1])
@pytest.mark.parametrize("empty_first", [False, True])
def test_concatenate_unequal_extents(frumpy_driver, axis, empty_first):
    shape = [2, 3]
    shape[axis] = 0 if empty_first else 1
    a = np.ones(shape, order="F")
    b = np.arange(6.).reshape(2, 3)[:, ::-1]
    check(frumpy_driver, "concatenate", np.concatenate([a, b], axis=axis), a, b, axis=axis)


@pytest.mark.parametrize("seed", [19, 42, 731])
def test_seeded_strided_operations(frumpy_driver, seed):
    rng = np.random.default_rng(seed)
    base = rng.integers(-5, 6, (3, 4, 5)).astype(np.float64)
    a = base[::-1, ::2, ::-1].transpose(2, 0, 1)
    b = np.asfortranarray(rng.normal(size=a.shape))
    mask = rng.integers(0, 2, (a.shape[0], 1, a.shape[2])).astype(bool)
    check(frumpy_driver, "where", np.where(mask, a, b), mask, a, b)
    for axis in range(a.ndim):
        check(frumpy_driver, "sort", np.sort(a, axis=axis, kind="stable"), a, axis=axis)
        check(frumpy_driver, "argsort", np.argsort(a, axis=axis, kind="stable"), a, axis=axis)
        check(frumpy_driver, "take", np.take(a, [0, -1, 0], axis=axis), a,
              axis=axis, indices=[0, -1, 0])
        check(frumpy_driver, "stack", np.stack([a, b], axis=axis), a, b, axis=axis)
        check(frumpy_driver, "concatenate", np.concatenate([a, b], axis=axis), a, b, axis=axis)
    sorted_source = np.sort(base.ravel())
    check(frumpy_driver, "searchsorted", np.searchsorted(sorted_source, a), sorted_source, a)


def float32_pairs():
    base = np.arange(1, 13, dtype=np.float32).reshape(3, 4)
    return [
        (base, base + np.float32(0.5)),
        (np.asfortranarray(base), np.asfortranarray(base + 1)),
        (base.T, np.array(3, dtype=np.float32)),
        (base[:, ::-1], np.arange(1, 5, dtype=np.float32)),
        (base[::-1, ::2], np.ones((3, 1), dtype=np.float32)),
        (np.broadcast_to(base[:1], (3, 4)), base[:, ::-1]),
        (np.array(2, dtype=np.float32), np.array(3, dtype=np.float32)),
        (np.empty((0, 4), dtype=np.float32), np.ones((1, 4), dtype=np.float32)),
        (np.empty((3, 0), dtype=np.float32), np.ones((3, 1), dtype=np.float32)),
        (np.array([16777216, 16777218, 1e-30], dtype=np.float32),
         np.array([1, 3, 1e-10], dtype=np.float32)),
        (np.array([np.nan, np.inf, -np.inf, 0., -0., 1., -1., 3e38], dtype=np.float32),
         np.array([1., np.inf, -np.inf, -0., 0., 0., 0., 3e38], dtype=np.float32)),
    ]


@pytest.mark.parametrize('operation', ['add', 'subtract', 'multiply', 'divide'])
@pytest.mark.parametrize('lhs,rhs', float32_pairs())
def test_float32_binary(frumpy_driver, operation, lhs, rhs):
    with np.errstate(all='ignore'):
        expected = getattr(np, operation)(lhs, rhs)
    status, actual = execute(frumpy_driver, operation + '_r32', lhs, rhs)
    assert status == 0
    assert actual.dtype == expected.dtype == np.dtype('float32')
    assert actual.shape == expected.shape
    np.testing.assert_array_equal(actual, expected)
    zeros = expected == 0
    np.testing.assert_array_equal(np.signbit(actual[zeros]), np.signbit(expected[zeros]))


@pytest.mark.parametrize('operation', ['add', 'subtract', 'multiply', 'divide'])
def test_float32_incompatible_shapes(frumpy_driver, operation):
    lhs = np.ones((2, 3), dtype=np.float32)
    rhs = np.ones((4,), dtype=np.float32)
    with pytest.raises(ValueError):
        getattr(np, operation)(lhs, rhs)
    assert execute(frumpy_driver, operation + '_r32', lhs, rhs)[0] == 1


def reduction_float32_layouts():
    base = np.arange(1, 25, dtype=np.float32).reshape(2, 3, 4) / np.float32(16)
    return [base, np.asfortranarray(base), base.transpose(2, 0, 1),
            base[::-1, :, ::-1], base[:, ::2, 1::2],
            np.broadcast_to(base[:1, :1], (3, 2, 4)),
            np.empty((0,), dtype=np.float32), np.empty((0, 0), dtype=np.float32),
            np.empty((0, 3), dtype=np.float32), np.empty((3, 0), dtype=np.float32),
            np.empty((2, 0, 3), dtype=np.float32), np.array(-0., dtype=np.float32),
            np.array([np.inf, -np.inf, 1.], dtype=np.float32),
            np.array([[3., np.nan, 2.], [np.nan, 4., 1.]], dtype=np.float32),
            np.array([0., -0.], dtype=np.float32), np.array([-0., 0.], dtype=np.float32),
            np.array([1e20, 1e20, 1e20], dtype=np.float32),
            np.random.default_rng(42).uniform(0.9, 1.1, (3, 5, 7)).astype(np.float32)]


@pytest.mark.parametrize('operation', ['sum', 'prod', 'mean', 'min', 'max'])
@pytest.mark.parametrize('source', reduction_float32_layouts())
@pytest.mark.parametrize('keepdims', [False, True])
def test_float32_reductions(frumpy_driver, operation, source, keepdims):
    import warnings

    axes = [None] + list(range(-max(1, source.ndim), max(1, source.ndim)))
    for axis in axes:
        # The bridge uses a separate all-axes flag, leaving every integer axis testable.
        side = int(keepdims) + (2 if axis is None else 0)
        with warnings.catch_warnings(), np.errstate(all='ignore'):
            warnings.simplefilter('ignore', RuntimeWarning)
            try:
                expected = getattr(np, operation)(source, axis=axis, keepdims=keepdims)
            except (ValueError, IndexError) as error:
                status, _ = execute(frumpy_driver, operation + '_r32', source,
                                    axis=0 if axis is None else axis, side=side)
                expected_status = 2 if isinstance(error, np.exceptions.AxisError) else 6
                assert status == expected_status
                continue
        status, actual = execute(frumpy_driver, operation + '_r32', source,
                                 axis=0 if axis is None else axis, side=side)
        assert status == 0
        assert actual.shape == np.shape(expected)
        assert actual.dtype == np.asarray(expected).dtype == np.dtype('float32')
        if operation in ('min', 'max'):
            np.testing.assert_array_equal(actual, expected)
        else:
            np.testing.assert_allclose(actual, expected, rtol=3e-6, atol=1e-7, equal_nan=True)
        zeros = np.asarray(expected) == 0
        np.testing.assert_array_equal(np.signbit(actual[zeros]), np.signbit(np.asarray(expected)[zeros]))


@pytest.mark.parametrize('operation', ['sum', 'prod', 'mean', 'min', 'max'])
@pytest.mark.parametrize('axis', [-2147483648, -4, 3, 2147483647])
def test_float32_reduction_invalid_axes(frumpy_driver, operation, axis):
    source = np.ones((2, 3, 4), dtype=np.float32)
    with pytest.raises(np.exceptions.AxisError):
        getattr(np, operation)(source, axis=axis)
    assert execute(frumpy_driver, operation + '_r32', source, axis=axis)[0] == 2


@pytest.mark.parametrize('operation', ['sum', 'mean'])
def test_float32_reduction_cancellation(frumpy_driver, operation):
    source = np.r_[np.float32(1e8), np.ones(256, dtype=np.float32), np.float32(-1e8)]
    expected = getattr(np, operation)(source)
    status, actual = execute(frumpy_driver, operation + '_r32', source, side=2)
    assert status == 0
    np.testing.assert_array_equal(actual, expected)

    # Reduction trees are an explicit numerical boundary, not bitwise NumPy parity.
    source = np.tile(np.array([1e8, 1., -1e8, 1.], dtype=np.float32), 4)
    status, actual = execute(frumpy_driver, operation + '_r32', source, side=2)
    assert status == 0
    expected_frumpy = np.float32(2 if operation == 'sum' else 2 / 16)
    np.testing.assert_array_equal(actual, expected_frumpy)
    assert getattr(np, operation)(source) == np.float32(0)


def unary_r32_layouts():
    base = np.linspace(-3, 3, 24, dtype=np.float32).reshape(4, 6)
    limits = np.finfo(np.float32)
    random_bits = np.random.default_rng(20260907).integers(0, 2**32, 2048, dtype=np.uint32)
    return [
        random_bits.view(np.float32),
        base, np.asfortranarray(base), base.T, base[::-1, ::-1], base[::2, 1::2],
        np.broadcast_to(base[:1, :1], (3, 4)),
        np.empty((0, 3), dtype=np.float32), np.empty((2, 0), dtype=np.float32),
        np.array(2, dtype=np.float32), np.array(-0., dtype=np.float32),
        np.array([np.nan, -np.inf, np.inf, -0., 0., -1., 1.], dtype=np.float32),
        np.array([limits.smallest_subnormal, -limits.smallest_subnormal,
                  limits.tiny, -limits.tiny, limits.max, -limits.max], dtype=np.float32),
        np.array([-104., -103., -90., 88., 89., 1e10, -1e20], dtype=np.float32),
        np.array([np.nextafter(np.float32(1), np.float32(0)), 1.,
                  np.nextafter(np.float32(1), np.float32(2))], dtype=np.float32),
    ]


@pytest.mark.parametrize("source", unary_r32_layouts())
@pytest.mark.parametrize("operation", ["negate", "abs", "sqrt", "exp", "log", "sin", "cos"])
def test_numpy_unary_r32(frumpy_driver, source, operation):
    oracle = np.negative if operation == "negate" else getattr(np, operation)
    with np.errstate(all="ignore"):
        expected = oracle(source)
    status, actual = execute(frumpy_driver, operation + "_r32", source)
    assert status == 0
    assert actual.dtype == np.float32
    assert actual.shape == source.shape
    assert actual.flags.c_contiguous
    np.testing.assert_array_equal(np.isnan(actual), np.isnan(expected))
    np.testing.assert_array_equal(np.isinf(actual), np.isinf(expected))
    non_nan = ~np.isnan(expected)
    np.testing.assert_array_equal(np.signbit(actual[non_nan]), np.signbit(expected[non_nan]))
    if operation in ("negate", "abs"):
        np.testing.assert_array_equal(actual, expected)
    else:
        # The compiler's real32 intrinsics and NumPy's vector math need not round identically.
        finite = np.isfinite(expected)
        np.testing.assert_array_max_ulp(actual[finite], expected[finite], maxulp=4)
