"""Same-dtype selection: native descriptor layouts, direct ABI and public views."""
import numpy as np
import pytest
import frumpy as fp
from test_c_boundary import abi, handles
from test_frumpy_differential import execute

DTYPES = [np.bool_, np.int32, np.int64, np.float32, np.float64]


def values(dtype, shape):
    a = np.arange(np.prod(shape, dtype=int), dtype=np.int64).reshape(shape)
    if dtype == np.int64:
        a += 2**60  # A floating-point round trip would lose adjacent keys.
    if dtype == np.bool_:
        return (a % 3 == 0)
    return a.astype(dtype)


def layout_pair(dtype, shape, layout):
    a = values(dtype, shape)
    if layout == 'F' and a.ndim:
        a = np.asfortranarray(a)
    b = fp.asarray(a)
    if a.ndim and layout == 'reverse':
        a, b = a[..., ::-1], b[..., ::-1]
    if a.ndim and layout == 'step':
        a, b = a[..., ::2], b[..., ::2]
    return a, b


def same(actual, expected):
    assert actual.shape == expected.shape
    assert actual.dtype == expected.dtype
    np.testing.assert_array_equal(actual, expected)
    if actual.dtype.kind == 'f':
        np.testing.assert_array_equal(np.signbit(actual), np.signbit(expected))


@pytest.mark.parametrize('dtype', DTYPES)
@pytest.mark.parametrize('shape', [(), (0,), (7,), (2, 3), (2, 0, 3), (2, 3, 4)])
@pytest.mark.parametrize('layout', ['C', 'F', 'reverse', 'step'])
def test_where_dtypes(frumpy_driver, handles, dtype, shape, layout):
    a, source = layout_pair(dtype, shape, layout)
    mask = np.arange(a.size).reshape(a.shape) % 2 == 0
    rhs = np.array(1, dtype=dtype)
    expected = np.where(mask, a, rhs)
    code, native = execute(frumpy_driver, 'select_where', mask, a, rhs, axis=DTYPES.index(dtype)+1)
    assert code == 0
    raw = handles.make('where', handles.put(mask), handles.put(a), handles.put(rhs))
    with fp.where(mask, source, rhs) as result:
        source.close()
        for actual in (native, handles.get(raw), result.numpy()):
            same(actual, expected)
        assert result.flags.owndata and result.flags.c_contiguous


@pytest.mark.parametrize('dtype', DTYPES)
@pytest.mark.parametrize('layout', ['C', 'F', 'reverse', 'step'])
def test_where_three_way_broadcast(frumpy_driver, dtype, layout):
    a, source = layout_pair(dtype, (2, 1, 4), layout)
    rhs = values(dtype, (3, 1))
    mask = np.broadcast_to(np.array([True, False])[:, None, None], (2, 3, 1))
    expected = np.where(mask, a, rhs)
    code, native = execute(frumpy_driver, 'select_where', mask, a, rhs, axis=DTYPES.index(dtype)+1)
    assert code == 0
    same(native, expected)
    with fp.where(mask, source, rhs) as result:
        same(result.numpy(), expected)
    source.close()


@pytest.mark.parametrize('dtype', DTYPES)
@pytest.mark.parametrize('shape', [(), (0,), (7,), (2, 3), (0, 3), (2, 0), (2, 3, 4)])
@pytest.mark.parametrize('layout', ['C', 'F', 'reverse', 'step'])
def test_take_dtypes(frumpy_driver, handles, dtype, shape, layout):
    a, source = layout_pair(dtype, shape, layout)
    for axis in [None] + list(range(-max(1, a.ndim), max(1, a.ndim))):
        extent = a.size if axis is None or not a.ndim else a.shape[axis]
        indices = np.array([0, -1, 0], dtype=np.int64) if extent else np.empty(0, dtype=np.int64)
        expected = np.take(a, indices, axis=axis)
        code, native = execute(frumpy_driver, 'select_take_flat' if axis is None else 'select_take',
                               a, axis=DTYPES.index(dtype)+1, side=0 if axis is None else axis, indices=indices)
        assert code == 0
        raw_input = a.ravel() if axis is None else a
        raw = handles.make('take', handles.put(raw_input), indices.ctypes.data, indices.size,
                           0 if axis is None else axis)
        with fp.take(source, indices, axis=axis) as result:
            for actual in (native, handles.get(raw), result.numpy()):
                same(actual, expected)
            assert result.flags.owndata and result.flags.c_contiguous
    source.close()


@pytest.mark.parametrize('dtype', DTYPES)
@pytest.mark.parametrize('shape', [(), (0,), (7,), (2, 3), (0, 3), (2, 0), (2, 3, 4)])
@pytest.mark.parametrize('layout', ['C', 'F', 'reverse', 'step'])
@pytest.mark.parametrize('operation', ['concatenate', 'stack'])
def test_join_dtypes(frumpy_driver, handles, dtype, shape, layout, operation):
    a, source = layout_pair(dtype, shape, layout)
    rank = a.ndim + (operation == 'stack')
    if not rank:
        with pytest.raises(ValueError):
            fp.concatenate([source, source])
        source.close()
        return
    for axis in range(-rank, rank):
        expected = getattr(np, operation)([a, a], axis=axis)
        code, native = execute(frumpy_driver, 'select_'+operation, a, a,
                               axis=DTYPES.index(dtype)+1, side=axis)
        assert code == 0
        ids = np.array([handles.put(a), handles.put(a)], dtype=np.int64)
        raw = handles.make('join', int(operation == 'stack'), ids.ctypes.data, ids.size, axis)
        with getattr(fp, operation)([source, source], axis=axis) as result:
            for actual in (native, handles.get(raw), result.numpy()):
                same(actual, expected)
            assert result.flags.owndata
            if operation == 'stack':
                assert result.flags.c_contiguous
            elif a.flags.f_contiguous and not a.flags.c_contiguous:
                assert result.flags.f_contiguous
    source.close()


@pytest.mark.parametrize('dtype', DTYPES)
def test_selection_errors_and_zero_strides(frumpy_driver, handles, dtype):
    a = values(dtype, (2, 3))
    aid = handles.put(a)
    condition = handles.put(np.ones((2, 3), dtype=bool))
    other = np.zeros((4,), dtype=dtype)
    handles.make('where', condition, aid, handles.put(other), status=1)
    for axis in (-2147483648, 2147483647, 2, -3):
        indices = np.array([0], dtype=np.int64)
        handles.make('take', aid, indices.ctypes.data, 1, axis, status=2)
    for index in (-2**63, 2**63-1, 3, -4):
        indices = np.array([index], dtype=np.int64)
        handles.make('take', aid, indices.ctypes.data, 1, 1, status=1)
        code, _ = execute(frumpy_driver, 'select_take', a, axis=DTYPES.index(dtype)+1, side=1, indices=indices)
        assert code == 1
    mismatch = np.int32 if dtype != np.int32 else np.float32
    bid = handles.put(a.astype(mismatch))
    handles.make('where', condition, aid, bid, status=5)
    ids = np.array([aid, bid], dtype=np.int64)
    for stacking in (0, 1):
        handles.make('join', stacking, ids.ctypes.data, 2, 0, status=5)
    handles.make('where', aid, aid, aid, status=5 if dtype != np.bool_ else 0)
    zero = np.broadcast_to(np.array(1, dtype=dtype), (2, 3))
    for operation in ('concatenate', 'stack'):
        code, native = execute(frumpy_driver, 'select_'+operation, zero, zero,
                               axis=DTYPES.index(dtype)+1, side=-1)
        assert code == 0
        same(native, getattr(np, operation)([zero, zero], axis=-1))
    code, native = execute(frumpy_driver, 'select_take_flat', zero, axis=DTYPES.index(dtype)+1,
                           indices=[5, 0, -1])
    assert code == 0
    same(native, np.take(zero, [5, 0, -1]))


@pytest.mark.parametrize('dtype', [np.float32, np.float64])
def test_selection_preserves_float_bits(dtype):
    bits = np.array([0, 1 << (np.dtype(dtype).itemsize*8-1),
                     0x7fc00001 if dtype == np.float32 else 0x7ff8000000000001],
                    dtype=np.uint32 if dtype == np.float32 else np.uint64)
    a = bits.view(dtype)
    outputs = [fp.where(np.ones(3, dtype=bool), a, a), fp.take(a, [0, 1, 2]),
               fp.concatenate([a]), fp.stack([a])]
    for output in outputs:
        np.testing.assert_array_equal(output.numpy().ravel().view(bits.dtype), bits)
        output.close()


@pytest.mark.parametrize('dtype', DTYPES)
@pytest.mark.parametrize('axis', [0, 1, -1])
@pytest.mark.parametrize('order', ['C', 'F'])
def test_concatenate_varied_lengths_and_lifetime(frumpy_driver, handles, dtype, axis, order):
    arrays = []
    for length in (0, 2, 5):
        shape = [2, 3, 4]
        shape[axis] = length
        arrays.append(np.array(values(dtype, tuple(shape)), order=order))
    code, native = execute(frumpy_driver, 'select_concatenate', *arrays[1:],
                           axis=DTYPES.index(dtype)+1, side=axis)
    assert code == 0
    same(native, np.concatenate(arrays[1:], axis=axis))
    owners = [fp.asarray(a) for a in arrays]
    result = fp.concatenate(owners, axis=axis)
    expected = np.concatenate(arrays, axis=axis)
    for owner in owners:
        owner.close()
    same(result.numpy(), expected)
    result.close()
    ids = np.array([handles.put(a) for a in arrays], dtype=np.int64)
    output = handles.make('join', 0, ids.ctypes.data, ids.size, axis)
    for handle in ids:
        assert handles.lib.frumpy_release(int(handle)) == 0
        handles.ids.remove(int(handle))
    same(handles.get(output), expected)


@pytest.mark.parametrize('dtype', DTYPES)
def test_join_and_where_rejections(frumpy_driver, handles, dtype):
    a, b = values(dtype, (2, 3)), values(dtype, (3, 2))
    ids = np.array([handles.put(a), handles.put(b)], dtype=np.int64)
    for operation in ('concatenate', 'stack'):
        code, _ = execute(frumpy_driver, 'select_'+operation, a, b,
                           axis=DTYPES.index(dtype)+1, side=0)
        assert code == 1
        handles.make('join', int(operation == 'stack'), ids.ctypes.data, 2, 0, status=1)
        with pytest.raises(ValueError):
            getattr(fp, operation)([a, b])
    for axis in (-2**31, 2**31-1):
        handles.make('join', 1, ids.ctypes.data, 1, axis, status=2)
    handles.make('join', 2, ids.ctypes.data, 1, 0, status=1)
    handles.make('join', 0, ids.ctypes.data, 0, 0, status=1)
    handles.make('take', int(ids[0]), None, -1, 0, status=1)
    handles.make('take', int(ids[0]), None, 2**63-1, 0, status=4)
    mask = np.ones((7,), dtype=bool)
    code, _ = execute(frumpy_driver, 'select_where', mask, a, a, axis=DTYPES.index(dtype)+1)
    assert code == 1
    with pytest.raises(ValueError):
        fp.where(mask, a, a)
