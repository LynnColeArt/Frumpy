"""Exercise the published ABI directly, independently of the Python wrapper."""
import ctypes as C
import os
from pathlib import Path
import subprocess

import numpy as np
import pytest

I, H, P = C.c_int32, C.c_int64, C.c_void_p
DTYPES = [np.bool_, np.int32, np.int64, np.float32, np.float64]


@pytest.fixture(scope="session")
def abi(tmp_path_factory):
    library = os.environ.get("FRUMPY_LIBRARY")
    if not library:
        root = Path(__file__).resolve().parents[2]
        build = tmp_path_factory.mktemp("c-boundary")
        subprocess.run(["make", "shared", f"BUILD_DIR={build}"], cwd=root, check=True)
        library = str(build / "libfrumpy.so")
    lib = C.CDLL(library)
    signatures = {
        "import": [I, I, P, I, P, H, P], "export": [H, P, H], "release": [H], "retain": [H],
        "view": [I, H, P, I, P], "binary": [I, H, H, P], "cast": [H, I, I, P],
        "reduce": [I, H, I, I, I, P], "unary": [I, H, P],
        "info": [H, P, P, P, P, I, P, P],
        "linalg": [I, H, H, P], "norm": [I, H, P, I, I, P],
        "rng_create": [H, P], "rng_fill": [H, I, I, P, P],
        "rng_get_state": [H, P, I], "rng_set_state": [H, P, I],
        "full": [I, I, P, I, P, P], "arange": [C.c_double, C.c_double, C.c_double, P],
        "linspace": [C.c_double, C.c_double, H, I, P],
        "where": [H, H, H, P], "mask_select": [H, H, P], "assign": [H, H],
        "take": [H, P, H, I, P], "join": [I, P, I, I, P],
        "sort": [I, H, I, P], "searchsorted": [H, H, I, P], "flatnonzero": [H, P],
    }
    for name, args in signatures.items():
        fn = getattr(lib, "frumpy_" + name)
        fn.argtypes, fn.restype = args, I
    return lib


class Handles:
    def __init__(self, lib):
        self.lib, self.ids = lib, []

    def make(self, operation, *args, status=0):
        out = H(-1)
        actual = getattr(self.lib, "frumpy_" + operation)(*args, C.byref(out))
        assert actual == status, (operation, actual, status)
        if status:
            assert out.value == 0
        else:
            self.ids.append(out.value)
        return out.value

    def put(self, values, order=0):
        a = np.asarray(values)
        shape = np.asarray(a.shape, dtype=np.int64)
        flat = np.ascontiguousarray(a.ravel(order="C"))
        return self.make("import", DTYPES.index(a.dtype.type) + 1, a.ndim,
                         shape.ctypes.data, order, flat.ctypes.data, a.size)

    def get(self, handle):
        dtype, rank, flags, offset = I(), I(), I(), H()
        shape = np.empty(32, dtype=np.int64)
        strides = np.empty(32, dtype=np.int64)
        assert self.lib.frumpy_info(handle, C.byref(dtype), C.byref(rank), shape.ctypes.data,
                                   strides.ctypes.data, 32, C.byref(offset), C.byref(flags)) == 0
        out = np.empty(tuple(shape[:rank.value]), dtype=DTYPES[dtype.value - 1])
        assert self.lib.frumpy_export(handle, out.ctypes.data, out.size) == 0
        return out

    def view(self, operation, handle, params=(), status=0):
        params = np.asarray(params, dtype=np.int64)
        return self.make("view", operation, handle, params.ctypes.data, params.size, status=status)


@pytest.fixture
def handles(abi):
    h = Handles(abi)
    yield h
    for handle in reversed(h.ids):
        assert abi.frumpy_release(handle) == 0


@pytest.mark.parametrize("dtype", DTYPES)
@pytest.mark.parametrize("order", [0, 1])
def test_buffers_views(handles, dtype, order):
    a = np.arange(6).reshape(2, 3).astype(dtype)
    h = handles.put(a, order)
    np.testing.assert_array_equal(handles.get(h), a)
    for operation, params, expected in [
        (2, (), a.T), (3, (0, 1), a.swapaxes(0, 1)),
        (5, (1,), np.expand_dims(a, 1)), (7, (), a.ravel()), (8, (), a.flatten()),
        (9, (1,), a.copy(order="F")), (10, (), np.ascontiguousarray(a)),
        (6, (1, -1, -1, 0, 3, 2), a[::-1, ::2]),
    ]:
        np.testing.assert_array_equal(handles.get(handles.view(operation, h, params)), expected)
    if order == 0:
        np.testing.assert_array_equal(handles.get(handles.view(1, h, (6,))), a.reshape(6))
    else:
        handles.view(1, h, (6,), status=6)
    expanded = handles.view(5, h, (0,))
    np.testing.assert_array_equal(handles.get(handles.view(4, expanded)), a)
    handles.view(3, h, (0,), status=1)
    handles.view(5, h, (2**40,), status=2)


@pytest.mark.parametrize("left", DTYPES)
@pytest.mark.parametrize("right", DTYPES)
def test_binary_cast(handles, left, right):
    a, b = np.array([1, 2], dtype=left), np.array(1, dtype=right)
    x, y = handles.put(a), handles.put(b)
    for op, oracle in enumerate([np.add, np.subtract, np.multiply, np.divide, np.equal,
                                np.not_equal, np.less, np.less_equal, np.greater,
                                np.greater_equal], 1):
        if op == 2 and left is np.bool_ and right is np.bool_:
            handles.make("binary", op, x, y, status=6)
            continue
        expected = oracle(a, b)
        actual = handles.get(handles.make("binary", op, x, y))
        assert actual.dtype == expected.dtype
        np.testing.assert_array_equal(actual, expected)
    cast = handles.make("cast", x, DTYPES.index(right) + 1, 4)
    np.testing.assert_array_equal(handles.get(cast), a.astype(right))


@pytest.mark.parametrize("dtype", DTYPES)
def test_reductions_unary(handles, dtype):
    a = np.array([[1, 2, 3], [4, 5, 6]], dtype=dtype)
    h = handles.put(a)
    reductions = [(6, np.all), (7, np.any)] if dtype is np.bool_ else list(enumerate(
        [np.sum, np.prod, np.min, np.max, np.mean], 1))
    for op, oracle in reductions:
        for axis in [None, 0, -1]:
            for keep in [False, True]:
                result = handles.make("reduce", op, h, axis is not None, axis or 0, keep)
                actual, expected = handles.get(result), oracle(a, axis=axis, keepdims=keep)
                assert actual.dtype == expected.dtype
                np.testing.assert_allclose(actual, expected, rtol=2e-6)
    if dtype in [np.float32, np.float64]:
        for op, oracle in enumerate([np.negative, np.abs, np.sqrt, np.exp, np.log,
                                    np.sin, np.cos], 1):
            np.testing.assert_allclose(handles.get(handles.make("unary", op, h)), oracle(a),
                                       rtol=2e-6, atol=1e-7)
    if dtype is np.bool_:
        np.testing.assert_array_equal(handles.get(handles.make("unary", 8, h)), np.logical_not(a))


def test_numerical_boundary(handles):
    a = np.array([[4., 1.], [1., 3.]])
    b = np.array([2., 5.])
    x, y = handles.put(a), handles.put(b)
    for op, oracle in enumerate([np.outer, np.dot, np.matmul, np.linalg.solve], 1):
        np.testing.assert_allclose(handles.get(handles.make("linalg", op, x, y)), oracle(a, b))
    for matrix in [0, 1]:
        for keep in [0, 1]:
            actual = handles.get(handles.make("norm", matrix, x, None, 0, keep))
            oracle = np.linalg.matrix_norm if matrix else np.linalg.vector_norm
            np.testing.assert_allclose(actual, oracle(a, keepdims=bool(keep)))
    axes = np.array([-1], dtype=np.int64)
    np.testing.assert_allclose(handles.get(handles.make("norm", 0, x, axes.ctypes.data, 1, 0)),
                               np.linalg.vector_norm(a, axis=-1))
    handles.make("linalg", 1, handles.put(np.array([1], dtype=np.int32)), y, status=5)


def test_generator_handles(handles):
    lib = handles.lib
    rng = handles.make("rng_create", 42)
    shape = np.array([2, 3], dtype=np.int64)
    state = np.empty(7, dtype=np.int64)
    assert lib.frumpy_rng_get_state(rng, state.ctypes.data, 7) == 0
    first = handles.get(handles.make("rng_fill", rng, 1, 2, shape.ctypes.data))
    assert lib.frumpy_rng_set_state(rng, state.ctypes.data, 7) == 0
    replay = handles.get(handles.make("rng_fill", rng, 1, 2, shape.ctypes.data))
    np.testing.assert_array_equal(first, replay)
    uniform = handles.get(handles.make("rng_fill", rng, 0, 2, shape.ctypes.data))
    assert np.all((uniform >= 0) & (uniform < 1))
    assert lib.frumpy_rng_get_state(rng, None, 7) == 1
    assert lib.frumpy_rng_get_state(rng, state.ctypes.data, 6) == 1
    invalid = state.copy()
    invalid[0] = 123
    assert lib.frumpy_rng_set_state(rng, invalid.ctypes.data, 7) == 1
    array = handles.put(np.array([1.]))
    assert lib.frumpy_rng_get_state(array, state.ctypes.data, 7) == 8
    handles.make("binary", 1, rng, array, status=8)


@pytest.mark.parametrize("dtype", DTYPES)
def test_full_and_sequences(handles, dtype):
    shape = np.array([2, 3], dtype=np.int64)
    value = np.array(2, dtype=dtype)
    result = handles.make("full", DTYPES.index(dtype) + 1, 2, shape.ctypes.data, 1, value.ctypes.data)
    np.testing.assert_array_equal(handles.get(result), np.full((2, 3), value))
    np.testing.assert_allclose(handles.get(handles.make("arange", -1., 2., .25)),
                               np.arange(-1., 2., .25))
    np.testing.assert_allclose(handles.get(handles.make("linspace", -1., 2., 7, 0)),
                               np.linspace(-1., 2., 7, endpoint=False))
    handles.make("arange", float("nan"), 1., 1., status=6)
    handles.make("arange", 0., 1., 0., status=6)


def test_selection_boundary(handles):
    a = np.array([[3., 1., 2.], [6., 4., 5.]])
    mask = a > 3
    x, y, condition = handles.put(a), handles.put(np.array(0.)), handles.put(mask)
    np.testing.assert_array_equal(handles.get(handles.make("where", condition, x, y)),
                                  np.where(mask, a, 0.))
    np.testing.assert_array_equal(handles.get(handles.make("mask_select", x, condition)), a[mask])
    np.testing.assert_array_equal(handles.get(handles.make("flatnonzero", condition)),
                                  np.flatnonzero(mask))
    indices = np.array([2, 0], dtype=np.int64)
    np.testing.assert_array_equal(handles.get(handles.make("take", x, indices.ctypes.data, 2, 1)),
                                  np.take(a, indices, axis=1))
    sources = np.array([x, x], dtype=np.int64)
    for stack, oracle in [(0, np.concatenate), (1, np.stack)]:
        np.testing.assert_array_equal(handles.get(handles.make("join", stack, sources.ctypes.data,
                                                               2, 0)), oracle([a, a], axis=0))
    for indices_flag, oracle in [(0, np.sort), (1, np.argsort)]:
        np.testing.assert_array_equal(handles.get(handles.make("sort", indices_flag, x, 1)),
                                      oracle(a, axis=1, kind="stable"))
    ordered, queries = np.array([1., 2., 2., 5.]), np.array([0., 2., 6.])
    sh, qh = handles.put(ordered), handles.put(queries)
    for right in [0, 1]:
        np.testing.assert_array_equal(handles.get(handles.make("searchsorted", sh, qh, right)),
                                      np.searchsorted(ordered, queries, side="right" if right else "left"))
    reversed_view = handles.view(6, x, (1, -1, -1, 0, 3, 1))
    assert handles.lib.frumpy_assign(x, reversed_view) == 0
    np.testing.assert_array_equal(handles.get(x), a[::-1])
    assert handles.lib.frumpy_assign(x, x) == 0
    handles.make("join", 0, None, 2, 0, status=1)
    handles.make("take", x, None, 2, 0, status=1)


def test_failures_and_empty_buffers(handles):
    lib = handles.lib
    for dtype in DTYPES:
        empty = np.empty((2, 0), dtype=dtype)
        h = handles.put(empty)
        assert lib.frumpy_export(h, None, 0) == 0
        np.testing.assert_array_equal(handles.get(h), empty)
        scalar = handles.put(np.array(1, dtype=dtype))
        np.testing.assert_array_equal(handles.get(scalar), np.array(1, dtype=dtype))
    x = handles.put(np.array([1., 2.]))
    y = handles.put(np.array([1., 2., 3.]))
    for _ in range(20):
        handles.make("binary", 1, x, y, status=1)
        handles.make("cast", x, 77, 4, status=5)
        handles.make("cast", x, 3, 0, status=6)
        handles.view(6, x, (0, 2, 0), status=1)
        handles.make("reduce", 1, x, 1, 9, 0, status=2)
        handles.make("reduce", 1, x, 9, 0, 0, status=1)
        assert lib.frumpy_assign(x, y) == 1
    np.testing.assert_array_equal(handles.get(x), [1., 2.])
    released = handles.make("import", 5, 0, None, 0, np.array(2.).ctypes.data, 1)
    assert lib.frumpy_release(released) == 0
    handles.ids.remove(released)
    # IDs cannot accidentally name an unrelated newly allocated object.
    handles.put(np.array([9.]))
    handles.make("binary", 1, released, x, status=8)


def test_handle_registry_growth_and_churn(abi):
    # Retained aliases survive rehashing; stale IDs never alias newly created arrays.
    handles = Handles(abi)
    ids = [handles.put(np.array([i], dtype=np.int64)) for i in range(2048)]
    keep = ids[0]
    assert abi.frumpy_retain(keep) == 0
    for handle in ids[::2]:
        assert abi.frumpy_release(handle) == 0
    for i in (0, 1, 127, 1023, 2047):
        np.testing.assert_array_equal(handles.get(ids[i]), [i])
    replacements = [handles.put(np.array([-i], dtype=np.int64)) for i in range(1024)]
    for handle in ids[2::2]:
        assert abi.frumpy_retain(handle) == 8
        assert abi.frumpy_release(handle) == 8
    assert len(set(ids + replacements)) == len(ids + replacements)
    for handle in ids[1::2] + replacements + [keep]:
        assert abi.frumpy_release(handle) == 0
    assert abi.frumpy_release(keep) == 8
    for invalid in (0, -1, -(2**63), 2**63-1):
        assert abi.frumpy_retain(invalid) == 8
        assert abi.frumpy_release(invalid) == 8
    # Exercise registry reuse after all of this test's handles are released.
    fresh = handles.put(np.array([42.]))
    np.testing.assert_array_equal(handles.get(fresh), [42.])
    assert abi.frumpy_release(fresh) == 0
