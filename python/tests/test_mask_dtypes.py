"""Five-dtype full-shape masking and failure-atomic assignment."""
import numpy as np
import pytest
import frumpy as fp
from test_c_boundary import abi, handles
from test_frumpy_differential import execute

DTYPES = [np.bool_, np.int32, np.int64, np.float32, np.float64]

@pytest.mark.parametrize('dtype', DTYPES)
@pytest.mark.parametrize('shape', [(), (0,), (7,), (2,3), (2,0,3), (2,3,4)])
@pytest.mark.parametrize('reverse', [False, True])
def test_mask_extract_assign(handles, dtype, shape, reverse):
    data = np.arange(np.prod(shape, dtype=int)).reshape(shape).astype(dtype)
    if dtype == np.int64:
        data += 2**60
    mask = np.asarray(np.arange(data.size).reshape(shape) % 2 == 0)
    owner = fp.asarray(data)
    source = owner[..., ::-1] if reverse and shape else owner
    expected = data[..., ::-1].copy() if reverse and shape else data.copy()
    with source[mask] as extracted:
        np.testing.assert_array_equal(extracted.numpy(), expected[mask])
        assert extracted.dtype == np.dtype(dtype)
    raw = handles.put(expected)
    condition = handles.put(mask)
    np.testing.assert_array_equal(handles.get(handles.make('mask_select', raw, condition)), expected[mask])
    values = np.arange(np.count_nonzero(mask)).astype(dtype)
    source[mask] = values
    expected[mask] = values
    np.testing.assert_array_equal(source.numpy(), expected)
    assert handles.lib.frumpy_mask_assign(raw, condition, handles.put(values)) == 0
    np.testing.assert_array_equal(handles.get(raw), expected)
    source[...] = np.array(1, dtype=dtype)
    expected[...] = 1
    np.testing.assert_array_equal(source.numpy(), expected)
    if source is not owner:
        source.close()
    owner.close()

@pytest.mark.parametrize('dtype', DTYPES)
def test_overlap_and_atomic_errors(handles, dtype):
    original = np.arange(6).astype(dtype)
    with fp.asarray(original) as a:
        a[1:] = a[:-1]
        expected = original.copy(); expected[1:] = expected[:-1]
        np.testing.assert_array_equal(a.numpy(), expected)
        mask = np.ones(6, dtype=bool)
        a[mask] = a[::-1]
        expected[mask] = expected[::-1].copy()
        np.testing.assert_array_equal(a.numpy(), expected)
        for bad in (np.ones(2, dtype=dtype), np.ones((1,6), dtype=dtype)):
            with pytest.raises(ValueError):
                a[mask] = bad
            np.testing.assert_array_equal(a.numpy(), expected)
        other = np.float32 if dtype != np.float32 else np.int32
        with pytest.raises(TypeError):
            a[mask] = np.ones(6, dtype=other)
        np.testing.assert_array_equal(a.numpy(), expected)
    target = handles.put(original)
    bad_mask = handles.put(np.ones(5, dtype=bool))
    assert handles.lib.frumpy_mask_assign(target, bad_mask, target) == 1
    np.testing.assert_array_equal(handles.get(target), original)


def test_boolean_mask_alias():
    with fp.asarray(np.array([True, False, True, True])) as a:
        mask = a[::-1]
        a[mask] = np.array(False)
        np.testing.assert_array_equal(a.numpy(), [False, False, True, False])
        mask.close()


@pytest.mark.parametrize('dtype', DTYPES)
@pytest.mark.parametrize('layout', ['C', 'F', 'reverse', 'step', 'broadcast'])
@pytest.mark.parametrize('shape', [(), (0,), (7,), (2,3), (2,0,3), (2,3,4)])
def test_native_masking(frumpy_driver, dtype, layout, shape):
    a = np.arange(np.prod(shape, dtype=int)).reshape(shape).astype(dtype)
    if dtype == np.int64:
        a += 2**60
    if layout == 'F':
        a = np.array(a, order='F')
    elif layout == 'broadcast':
        a = np.broadcast_to(np.array(1, dtype=dtype), shape)
    elif a.ndim and layout in ('reverse', 'step'):
        a = a[..., ::-1 if layout == 'reverse' else 2]
    mask = np.asarray(np.arange(a.size).reshape(a.shape) % 2 == 0)
    dtype_id = DTYPES.index(dtype) + 1
    code, result = execute(frumpy_driver, 'select_mask', mask, a, axis=dtype_id)
    assert code == 0
    np.testing.assert_array_equal(result, a[mask])
    values = np.arange(np.count_nonzero(mask)).astype(dtype)
    # Zero-stride writes intentionally alias: test them separately in native invariants.
    if layout == 'broadcast':
        return
    code, result = execute(frumpy_driver, 'select_mask_assign', mask, a, values, axis=dtype_id, owns=False)
    assert code == 0
    expected = a.copy(); expected[mask] = values
    np.testing.assert_array_equal(result, expected)
    rhs = np.array(1, dtype=dtype)
    code, result = execute(frumpy_driver, 'select_assign', a, rhs, axis=dtype_id, owns=False)
    assert code == 0
    np.testing.assert_array_equal(result, np.full(a.shape, 1, dtype=dtype))


@pytest.mark.parametrize('dtype', DTYPES)
@pytest.mark.parametrize('selected', [False, True])
@pytest.mark.parametrize('rhs_kind', ['scalar', 'singleton', 'exact'])
def test_empty_and_uniform_masks(handles, dtype, selected, rhs_kind):
    initial = np.arange(6).reshape(2, 3).astype(dtype)
    mask = np.full((2, 3), selected)
    count = np.count_nonzero(mask)
    rhs = np.array(1, dtype=dtype) if rhs_kind == 'scalar' else np.ones(
        1 if rhs_kind == 'singleton' else count, dtype=dtype)
    expected = initial.copy(); expected[mask] = rhs
    with fp.asarray(initial) as a:
        a[mask] = rhs
        np.testing.assert_array_equal(a.numpy(), expected)
    target, condition, values = (handles.put(v) for v in (initial, mask, rhs))
    assert handles.lib.frumpy_mask_assign(target, condition, values) == 0
    np.testing.assert_array_equal(handles.get(target), expected)


@pytest.mark.parametrize('dtype', DTYPES)
def test_direct_abi_errors_and_aliases(handles, dtype):
    original = np.arange(6).astype(dtype)
    a = handles.put(original)
    condition = handles.put(np.ones(6, dtype=bool))
    bad = handles.put(np.ones(2, dtype=dtype))
    assert handles.lib.frumpy_assign(a, bad) == 1
    assert handles.lib.frumpy_mask_assign(a, condition, bad) == 1
    wrong_dtype = np.int32 if dtype != np.int32 else np.float32
    wrong = handles.put(np.ones(6, dtype=wrong_dtype))
    assert handles.lib.frumpy_assign(a, wrong) == 5
    assert handles.lib.frumpy_mask_assign(a, condition, wrong) == 5
    assert handles.lib.frumpy_mask_assign(a, wrong, a) == 5
    assert handles.lib.frumpy_mask_assign(a, -1, a) == 8
    assert handles.lib.frumpy_mask_assign(a, condition, -1) == 8
    np.testing.assert_array_equal(handles.get(a), original)
    reverse = handles.view(6, a, [5, -1, -1])
    assert handles.lib.frumpy_mask_assign(a, condition, reverse) == 0
    np.testing.assert_array_equal(handles.get(a), original[::-1])
    assert handles.lib.frumpy_mask_assign(a, condition, a) == 0
    np.testing.assert_array_equal(handles.get(a), original[::-1])
    out = handles.make('mask_select', a, condition)
    assert handles.lib.frumpy_release(a) == 0
    handles.ids.remove(a)
    assert handles.lib.frumpy_release(reverse) == 0
    handles.ids.remove(reverse)
    np.testing.assert_array_equal(handles.get(out), original[::-1])


@pytest.mark.parametrize('dtype', [np.float32, np.float64])
def test_mask_float_payloads(dtype):
    uint = np.uint32 if dtype == np.float32 else np.uint64
    bits = np.array([0, 1 << (np.dtype(dtype).itemsize * 8 - 1),
                     0x7fc00031 if dtype == np.float32 else 0x7ff8000000000031], dtype=uint)
    values = bits.view(dtype)
    mask = np.ones(3, dtype=bool)
    with fp.asarray(values) as source, fp.asarray(np.zeros(3, dtype=dtype)) as target:
        with source[mask] as result:
            np.testing.assert_array_equal(result.numpy().view(uint), bits)
        target[mask] = source
        np.testing.assert_array_equal(target.numpy().view(uint), bits)
        target[:] = source[::-1]
        np.testing.assert_array_equal(target.numpy().view(uint), bits[::-1])


@pytest.mark.parametrize('dtype', DTYPES)
def test_transposed_masks_and_broadcast_assignment(dtype):
    original = np.arange(24).reshape(2, 3, 4).astype(dtype)
    expected = original.transpose(2, 1, 0).copy()
    with fp.asarray(original) as owner, fp.asarray(np.ones((2, 3, 4), dtype=bool)) as mask_owner:
        target = owner.transpose()
        mask = mask_owner.transpose()[::-1]
        with target[mask] as extracted:
            np.testing.assert_array_equal(extracted.numpy(), expected.ravel())
        values = np.arange(6).reshape(3, 2).astype(dtype)
        target[:] = values
        expected[:] = values
        np.testing.assert_array_equal(target.numpy(), expected)
        target.close(); mask.close()


@pytest.mark.parametrize('dtype', DTYPES)
@pytest.mark.parametrize('layout', ['C', 'F', 'step', 'reverse', 'irregular'])
@pytest.mark.parametrize('masked', [False, True])
def test_scalar_fill_alias_snapshot(dtype, layout, masked):
    data = np.arange(24).reshape(4, 6).astype(dtype)
    if dtype == np.bool_:
        data = (np.arange(24).reshape(4, 6) % 3 == 0)
    with fp.asarray(data, order='F' if layout == 'F' else 'C') as owner:
        target = owner[:, ::2] if layout == 'step' else owner[::-1, ::-1] if layout == 'reverse' else (
            owner[::2, ::-1] if layout == 'irregular' else owner)
        before = target.numpy()
        # The captured element lies late in the traversal, but inside the write set.
        rhs = target[-1:, -1:].squeeze().reshape((1,))
        expected = before.copy()
        value = before[-1, -1]
        if masked:
            mask = np.arange(expected.size).reshape(expected.shape) % 2 == 0
            target[mask] = rhs
            expected[mask] = value
        else:
            target[:] = rhs
            expected[:] = value
        np.testing.assert_array_equal(target.numpy(), expected)
        rhs.close()
        if target is not owner:
            target.close()


@pytest.mark.parametrize('dtype', DTYPES)
def test_scalar_fill_preserves_shape_rejections(dtype):
    with fp.asarray(np.zeros(4, dtype=dtype)) as target:
        rhs = np.ones((1, 1), dtype=dtype)
        with pytest.raises(ValueError):
            target[:] = rhs
        with pytest.raises(ValueError):
            target[np.ones(4, dtype=bool)] = rhs
        np.testing.assert_array_equal(target.numpy(), np.zeros(4, dtype=dtype))


@pytest.mark.parametrize('dtype', [np.float32, np.float64])
@pytest.mark.parametrize('masked', [False, True])
def test_scalar_fill_float_bits(dtype, masked):
    uint = np.uint32 if dtype == np.float32 else np.uint64
    for bits in (1 << (np.dtype(dtype).itemsize * 8 - 1),
                 0x7fc00031 if dtype == np.float32 else 0x7ff8000000000031):
        scalar = np.array(bits, dtype=uint).view(dtype)
        with fp.asarray(np.zeros((3,4), dtype=dtype)) as target:
            if masked:
                target[np.ones(target.shape, dtype=bool)] = scalar
            else:
                target[:] = scalar
            np.testing.assert_array_equal(target.numpy().view(uint), np.full((3,4), bits, dtype=uint))
