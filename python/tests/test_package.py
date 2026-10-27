"""Public Python API: native execution, ownership, coercion and bounded behavior."""
import gc
import numpy as np
import pytest
import frumpy as fp

DTYPES = [np.bool_, np.int32, np.int64, np.float32, np.float64]


@pytest.mark.parametrize("dtype", DTYPES)
def test_constructors_views(dtype):
    source = np.arange(12).reshape(3, 4).astype(dtype)
    a = fp.asarray(source)
    np.testing.assert_array_equal(a.numpy(), source)
    source[:] = 0
    assert a.numpy()[2, 3] != 0
    for order in ["C", "F"]:
        for make, oracle in [(fp.zeros, np.zeros), (fp.ones, np.ones)]:
            actual = make((2, 3), dtype=dtype, order=order)
            np.testing.assert_array_equal(actual.numpy(), oracle((2, 3), dtype=dtype))
        np.testing.assert_array_equal(fp.full((2, 3), 2, dtype=dtype).numpy(),
                                      np.full((2, 3), 2, dtype=dtype))
    expected = np.arange(12).reshape(3, 4).astype(dtype)
    for key in [slice(None, None, -1), (None, Ellipsis, 1), (1, slice(None, None, 2)),
                (Ellipsis,), (slice(99), slice(-99, 99, 3)), (slice(0, 0, -1), Ellipsis)]:
        np.testing.assert_array_equal(a[key].numpy(), expected[key])
    assert a[-1, -1] == expected[-1, -1]
    np.testing.assert_array_equal(a.T.numpy(), expected.T)
    np.testing.assert_array_equal(a.reshape(-1).numpy(), expected.reshape(-1))
    np.testing.assert_array_equal(a.swapaxes(-1, 0).numpy(), expected.swapaxes(-1, 0))
    np.testing.assert_array_equal(fp.squeeze(fp.expand_dims(a, -1), -1).numpy(), expected)
    np.testing.assert_array_equal(a.T.ravel().numpy(), expected.T.ravel())
    assert a.T.flatten().flags.owndata
    assert not a.T.flags.owndata
    with pytest.raises(NotImplementedError):
        a.T.reshape(12)
    with pytest.raises(ValueError):
        np.array(a, copy=False)
    with pytest.raises(IndexError):
        a[99]
    with pytest.raises(TypeError):
        a[[0, 1]]


@pytest.mark.parametrize("left", DTYPES)
@pytest.mark.parametrize("right", DTYPES)
def test_arithmetic_cast(left, right):
    a, b = np.array([1, 2], dtype=left), np.array(2, dtype=right)
    x, y = fp.asarray(a), fp.asarray(b)
    for native, oracle in [(fp.add, np.add), (fp.multiply, np.multiply),
                           (fp.divide, np.divide), (fp.less, np.less), (fp.equal, np.equal)]:
        actual = native(x, y)
        expected = oracle(a, b)
        assert actual.dtype == expected.dtype
        np.testing.assert_array_equal(actual.numpy(), expected)
    np.testing.assert_array_equal(x.astype(right).numpy(), a.astype(right))


def test_scalar_promotion_and_no_fallback(monkeypatch):
    a = fp.asarray([1, 2], dtype=np.float32)
    assert (a + 1.).dtype == np.dtype("float32")
    assert (a + np.float64(1)).dtype == np.dtype("float64")
    b = fp.asarray([1, 2], dtype=np.int32)
    with pytest.raises(OverflowError):
        b + 2**50
    with pytest.raises(TypeError):
        fp.asarray([1 + 2j])
    def forbidden(*args, **kwargs):
        raise AssertionError("NumPy execution fallback")
    monkeypatch.setattr(np, "add", forbidden)
    monkeypatch.setattr(np.linalg, "solve", forbidden)
    np.testing.assert_array_equal((a + a).numpy(), [2., 4.])
    np.testing.assert_allclose(fp.linalg.solve(fp.asarray([[2.]]), fp.asarray([4.])).numpy(), [2.])
    with pytest.raises(TypeError):
        np.sin(a)


def test_lifetime_assignment_errors():
    parent = fp.asarray(np.arange(12.).reshape(3, 4))
    view = parent[::-1, ::2]
    del parent
    gc.collect()
    np.testing.assert_array_equal(view.numpy(), [[8., 10.], [4., 6.], [0., 2.]])
    other = view.T
    view.close()
    np.testing.assert_array_equal(other.numpy(), [[8., 4., 0.], [10., 6., 2.]])
    with pytest.raises(ReferenceError):
        view.numpy()
    a = fp.asarray(np.arange(6.))
    a[1:] = a[:-1]
    np.testing.assert_array_equal(a.numpy(), [0., 0., 1., 2., 3., 4.])
    a[::2] = -1.
    np.testing.assert_array_equal(a.numpy(), [-1., 0., -1., 2., -1., 4.])
    for _ in range(30):
        with pytest.raises(ValueError):
            a[:] = fp.asarray([1., 2.])
        with pytest.raises(NotImplementedError):
            a.astype(np.int64, casting="no")
    np.testing.assert_array_equal(a.numpy(), [-1., 0., -1., 2., -1., 4.])
    np.testing.assert_array_equal(a[a > 0].numpy(), [2., 4.])


@pytest.mark.parametrize("dtype", DTYPES)
def test_reductions(dtype):
    data = np.array([[1, 2], [3, 4]], dtype=dtype)
    a = fp.asarray(data)
    names = ["all", "any"] if dtype is np.bool_ else ["sum", "prod", "min", "max", "mean"]
    for name in names:
        for axis in [None, 0, -1]:
            for keep in [False, True]:
                actual = getattr(a, name)(axis=axis, keepdims=keep)
                expected = getattr(np, name)(data, axis=axis, keepdims=keep)
                np.testing.assert_allclose(actual.numpy(), expected)
                assert actual.dtype == expected.dtype


def test_selection_numerical_random():
    a = fp.asarray([[4., 1.], [1., 3.]])
    b = fp.asarray([2., 5.])
    for native, oracle in [(fp.outer, np.outer), (fp.dot, np.dot), (fp.matmul, np.matmul),
                           (fp.linalg.solve, np.linalg.solve)]:
        np.testing.assert_allclose(native(a, b).numpy(), oracle(a.numpy(), b.numpy()))
    np.testing.assert_allclose(fp.linalg.vector_norm(a).numpy(), np.linalg.vector_norm(a.numpy()))
    np.testing.assert_allclose(fp.linalg.matrix_norm(a).numpy(), np.linalg.matrix_norm(a.numpy()))
    for name in ["sort", "argsort"]:
        np.testing.assert_array_equal(getattr(fp, name)(a).numpy(), getattr(np, name)(a.numpy()))
    np.testing.assert_array_equal(fp.take(a, [1, 0], axis=0).numpy(), a.numpy()[[1, 0]])
    for name in ["concatenate", "stack"]:
        np.testing.assert_array_equal(getattr(fp, name)([a, a]).numpy(),
                                      getattr(np, name)([a.numpy(), a.numpy()]))
    np.testing.assert_array_equal(fp.where(a > 2, a, 0.).numpy(), np.where(a.numpy() > 2, a.numpy(), 0.))
    np.testing.assert_array_equal(fp.flatnonzero(a > 2).numpy(), [0, 3])
    np.testing.assert_array_equal(fp.searchsorted(fp.asarray([1., 2., 2.]), [2.], side="right").numpy(), [3])
    np.testing.assert_allclose(fp.arange(0., 1., .1).numpy(), np.arange(0., 1., .1))
    np.testing.assert_allclose(fp.linspace(0., 1., 4).numpy(), np.linspace(0., 1., 4))
    rng = fp.random.default_rng(42)
    rng.standard_normal(3)
    state = rng.state
    expected = rng.standard_normal((2, 3)).numpy()
    rng.state = state
    np.testing.assert_array_equal(rng.standard_normal((2, 3)).numpy(), expected)
    assert 0 <= rng.random() < 1
    rng.close()
    with pytest.raises(ReferenceError):
        rng.random()


@pytest.mark.parametrize('axis', [2, -2, 2**32, -(2**32), 2**64])
@pytest.mark.parametrize('dtype', DTYPES)
def test_scalar_reduction_axis_does_not_wrap(axis, dtype):
    a = fp.asarray(np.array(1, dtype=dtype))
    operation = a.all if dtype is np.bool_ else a.sum
    with pytest.raises((IndexError, ValueError, OverflowError)):
        operation(axis=axis)


def test_layout_flags_are_read_only():
    a = fp.asarray(np.arange(6.).reshape(2, 3)).T
    for name in ('c_contiguous', 'f_contiguous', 'owndata'):
        with pytest.raises(AttributeError):
            setattr(a.flags, name, True)
    contiguous = fp.asarray(a, order='C')
    assert contiguous is not a
    assert contiguous.flags.c_contiguous
    assert contiguous.strides == (16, 8)
    np.testing.assert_array_equal(contiguous.numpy(), a.numpy())


@pytest.mark.parametrize('size', [0, 1, 15, 16, 17, 31, 32, 33, 65, 257, 1025])
@pytest.mark.parametrize('layout', ['C', 'F', 'reverse', 'step', 'transpose'])
def test_stable_sort_run_boundaries(size, layout):
    rng = np.random.default_rng(512)
    data = rng.integers(-5, 6, (3, size)).astype(np.float64)
    if size:
        payloads = np.arange(data[:, ::7].size, dtype=np.uint64).reshape(data[:, ::7].shape)
        data[:, ::7].view(np.uint64)[:] = payloads + np.uint64(0x7ff8000000000001)
        data[:, 1::7] = -0.0
        data[:, 2::7] = 0.0
        data[:, 3::11] = np.inf
        data[:, 4::11] = -np.inf
    source = fp.asarray(data, order='F' if layout == 'F' else 'C')
    if layout == 'reverse':
        data, source = data[:, ::-1], source[:, ::-1]
    elif layout == 'step':
        data, source = data[:, ::2], source[:, ::2]
    elif layout == 'transpose':
        data, source = data.T, source.T
    original = source.numpy().view(np.uint64).copy()
    for axis in range(data.ndim):
        expected_indices = np.argsort(data, axis=axis, kind='stable')
        expected_values = np.take_along_axis(data, expected_indices, axis=axis)
        with fp.argsort(source, axis=axis) as indices, fp.sort(source, axis=axis) as values:
            np.testing.assert_array_equal(indices.numpy(), expected_indices)
            np.testing.assert_array_equal(values.numpy().view(np.uint64), expected_values.view(np.uint64))
    np.testing.assert_array_equal(source.numpy().view(np.uint64), original)
