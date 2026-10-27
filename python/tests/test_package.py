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


@pytest.mark.parametrize("dtype", [np.float32, np.float64])
@pytest.mark.parametrize("operation", ["add", "subtract", "multiply", "divide"])
@pytest.mark.parametrize("layout", ["offset", "singleton", "scalar_left", "scalar_right", "row"])
def test_contiguous_arithmetic(dtype, operation, layout):
    a = np.arange(1, 25, dtype=dtype).reshape(4, 6)
    backing = fp.asarray(np.concatenate([np.zeros((1, 6), dtype=dtype), a]))
    fa = backing[1:]
    b = np.full(a.shape, 2, dtype=dtype)
    if layout == "singleton":
        a, fa, b = a[:, None, :], fa[:, None, :], b[:, None, :]
    elif layout == "scalar_left":
        b, a = a, np.array(2, dtype=dtype)
        fa = fp.asarray(a)
    elif layout == "scalar_right":
        b = np.array(2, dtype=dtype)
    elif layout == "row":
        b = b[0]
    fb = fp.asarray(b)
    with getattr(fp, operation)(fa, fb) as actual:
        np.testing.assert_array_equal(actual.numpy(), getattr(np, operation)(a, b))
    np.testing.assert_array_equal(fa.numpy(), a)


@pytest.mark.parametrize("dtype", [np.float32, np.float64])
@pytest.mark.parametrize("operation", ["sum", "mean", "prod", "min", "max"])
@pytest.mark.parametrize("axis", [None, 0, 1])
@pytest.mark.parametrize("special", [False, True])
def test_contiguous_reduction_order(dtype, operation, axis, special):
    # Cancellation, signed zeros and non-finite values must match strided traversal bitwise.
    a = np.resize(np.array([1e16, 1, -1e16, 3, -0., 0., 1, -1, 2], dtype=dtype), (3, 65))
    if operation == "prod":
        a = np.resize(np.array([1, -1, .5, 2, -0., 0.], dtype=dtype), a.shape)
    if special:
        a[0, 0], a[1, 8], a[2, -1] = np.nan, np.inf, -np.inf
    padded = np.zeros((3, 130), dtype=dtype)
    padded[:, ::2] = a
    contiguous, backing = fp.asarray(a), fp.asarray(padded)
    strided = backing[:, ::2]
    with getattr(contiguous, operation)(axis=axis) as fast, \
            getattr(strided, operation)(axis=axis) as fallback:
        bits = np.uint32 if dtype == np.float32 else np.uint64
        np.testing.assert_array_equal(fast.numpy().view(bits), fallback.numpy().view(bits))


@pytest.mark.parametrize("dtype", [np.float32, np.float64])
@pytest.mark.parametrize("operation", ["add", "subtract", "multiply", "divide"])
@pytest.mark.parametrize("layout", ["step", "reverse", "reverse_step", "transpose", "row"])
def test_uniform_strided_arithmetic(dtype, operation, layout):
    data = (np.arange(48, dtype=dtype) + 1).reshape(4, 12)
    owner = fp.asarray(data)
    a, fa = data[:, ::2], owner[:, ::2]
    if layout == "reverse":
        a, fa = data[::-1, ::-1], owner[::-1, ::-1]
    elif layout == "reverse_step":
        a, fa = data[::-1, ::-2], owner[::-1, ::-2]
    elif layout == "transpose":
        a, fa = a.T, fa.T
    b = np.full(a.shape, 2, dtype=dtype)
    if layout == "row":
        b = b[0]
    with fp.asarray(b) as fb, getattr(fp, operation)(fa, fb) as actual:
        np.testing.assert_array_equal(actual.numpy(), getattr(np, operation)(a, b))
    with fp.asarray(np.array(2, dtype=dtype)) as scalar, \
            getattr(fp, operation)(scalar, fa) as actual:
        np.testing.assert_array_equal(actual.numpy(), getattr(np, operation)(2, a))
    np.testing.assert_array_equal(owner.numpy(), data)


@pytest.mark.parametrize("dtype", DTYPES)
@pytest.mark.parametrize("rank", [0, 1, 8, 32])
def test_result_metadata_buffers(dtype, rank):
    shape = (1,) * rank
    a = fp.ones(shape, dtype=dtype)
    result = a + a
    a.close()
    assert result.shape == shape
    assert result.ndim == rank
    assert result.size == 1
    assert result.dtype == np.dtype(dtype)
    assert result.strides == (result.dtype.itemsize,) * rank
    assert result.flags.c_contiguous and result.flags.f_contiguous and result.flags.owndata
    np.testing.assert_array_equal(result.numpy(), np.ones(shape, dtype=dtype) + np.ones(shape, dtype=dtype))
    result.close()


@pytest.mark.parametrize("dtype", [np.float32, np.float64])
@pytest.mark.parametrize("width", [0, 1, 4, 8, 17, 128])
@pytest.mark.parametrize("layout", ["row", "column", "transpose", "reversed"])
def test_row_arithmetic(dtype, width, layout):
    a = (np.arange(3 * width, dtype=dtype) + 1).reshape(3, width)
    if layout == "transpose":
        a = a.T.copy().T
    elif layout == "reversed":
        a = a[:, ::-1]
    owner = fp.asarray(np.ascontiguousarray(a[:, ::-1])) if layout == "reversed" else fp.asarray(a, order="K")
    fa = owner[:, ::-1] if layout == "reversed" else owner
    b = np.full((3, 1) if layout == "column" else (1, width), 2, dtype=dtype)
    with fp.asarray(b) as fb:
        for operation in ("add", "subtract", "multiply", "divide"):
            with getattr(fp, operation)(fa, fb) as actual:
                np.testing.assert_array_equal(actual.numpy(), getattr(np, operation)(a, b))
    np.testing.assert_array_equal(fa.numpy(), a)


@pytest.mark.parametrize("shape", [(1, 1, 1), (1, 17, 3), (3, 17, 1), (7, 9, 11), (2, 0, 3)])
@pytest.mark.parametrize("layout", ["C", "F", "leftF", "rightF", "offset", "stepped"])
def test_matmul_output_layout(shape, layout):
    m, k, n = shape
    a = np.arange(m*k, dtype=np.float64).reshape(m,k) / max(1,k)
    b = np.arange(k*n, dtype=np.float64).reshape(k,n) / max(1,n)
    if layout == "F":
        a, b = np.asfortranarray(a), np.asfortranarray(b)
    if layout == "leftF":
        a = np.asfortranarray(a)
    elif layout == "rightF":
        b = np.asfortranarray(b)
    fa, fb = fp.asarray(a, order="K"), fp.asarray(b, order="K")
    if layout == "offset":
        fa = fp.asarray(np.concatenate([np.zeros((1,k)), a]))[1:]
        fb = fp.asarray(np.concatenate([np.zeros((1,n)), b]))[1:]
    elif layout == "stepped":
        pa, pb = np.zeros((m, k*2)), np.zeros((k,n*2))
        pa[:, ::2], pb[:, ::2] = a, b
        fa, fb = fp.asarray(pa)[:, ::2], fp.asarray(pb)[:, ::2]
    with fa @ fb as actual:
        np.testing.assert_allclose(actual.numpy(), a @ b, rtol=2e-12, atol=2e-12)
        assert actual.flags.c_contiguous
    np.testing.assert_array_equal(fa.numpy(), a)
    np.testing.assert_array_equal(fb.numpy(), b)


@pytest.mark.parametrize('closed_side', ['left', 'right'])
def test_binary_array_pair_rejects_closed_handle(closed_side):
    left, right = fp.ones(3), fp.ones(3)
    (left if closed_side == 'left' else right).close()
    try:
        with pytest.raises(ReferenceError):
            left + right
    finally:
        left.close()
        right.close()


def test_binary_array_pair_preserves_view_metadata():
    with fp.asarray(np.arange(12.).reshape(3, 4)) as owner:
        with owner[:, ::-1] as left, owner.T as right:
            with fp.ones((1, 4)) as ones, left + ones as result:
                np.testing.assert_array_equal(result.numpy(), np.arange(12.).reshape(3, 4)[:, ::-1] + 1)
            with right + right as result:
                np.testing.assert_array_equal(result.numpy(), np.arange(12.).reshape(3, 4).T * 2)
            assert left.strides == (32, -8)
            assert right.flags.f_contiguous


@pytest.mark.parametrize("order", ["C", "F"])
def test_float32_matmul_solve_package(order):
    a = np.array([[4, 1], [1, 3]], dtype=np.float32, order=order)
    b = np.array([[1, 2], [3, 4]], dtype=np.float32, order=order)
    with fp.asarray(a, order='K') as lhs, fp.asarray(b, order='K') as rhs:
        with lhs @ rhs as product, fp.linalg.solve(lhs, rhs) as solution:
            assert product.dtype == solution.dtype == np.dtype(np.float32)
            np.testing.assert_allclose(product.numpy(), a@b, rtol=2e-5, atol=2e-5)
            np.testing.assert_allclose(solution.numpy(), np.linalg.solve(a,b), rtol=2e-5, atol=2e-5)


@pytest.mark.parametrize("operation", ["dot", "outer"])
def test_float32_products_package(operation):
    a = np.arange(12,dtype=np.float32).reshape(3,4)
    b = np.arange(8,dtype=np.float32).reshape(4,2)
    with fp.asarray(a) as lhs,fp.asarray(b) as rhs:
        result = getattr(fp,operation)(lhs,rhs)
    with result:
        assert result.dtype == np.dtype(np.float32)
        assert result.flags.owndata and result.flags.c_contiguous
        np.testing.assert_allclose(result.numpy(),getattr(np,operation)(a,b),rtol=2e-5,atol=2e-5)
