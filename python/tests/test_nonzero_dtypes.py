"""Coordinate extraction across native, C and Python boundaries."""
import ctypes as C
import numpy as np
import pytest
import frumpy as fp
from test_c_boundary import abi, handles
from test_frumpy_differential import execute

DTYPES = [np.bool_, np.int32, np.int64, np.float32, np.float64]

@pytest.mark.parametrize('dtype', DTYPES)
@pytest.mark.parametrize('shape', [(), (0,), (7,), (2,3), (2,0,3), (2,3,4)])
@pytest.mark.parametrize('layout', ['C','F','reverse','step'])
def test_coordinate_results(handles, dtype, shape, layout):
    a = np.asarray((np.arange(np.prod(shape,dtype=int)).reshape(shape) % 3).astype(dtype))
    if dtype == np.int64:
        a[a != 0] += 2**60
    owner = fp.asarray(np.array(a, order='F' if layout == 'F' else 'C'))
    source = owner
    if a.ndim and layout in ('reverse','step'):
        key = (..., slice(None,None,-1 if layout=='reverse' else 2))
        a, source = a[key], owner[key]
    with fp.argwhere(source) as coords:
        expected = np.argwhere(a)
        np.testing.assert_array_equal(coords.numpy(), expected)
        assert coords.dtype == np.dtype(np.int64)
    raw = handles.put(a)
    np.testing.assert_array_equal(handles.get(handles.make('argwhere',raw)), np.argwhere(a))
    if not a.ndim:
        with pytest.raises(ValueError): fp.nonzero(source)
    else:
        expected = np.nonzero(a)
        axes = fp.nonzero(source)
        assert isinstance(axes, tuple) and len(axes)==a.ndim
        ids = np.full(a.ndim,-1,dtype=np.int64)
        assert handles.lib.frumpy_nonzero(raw,ids.ctypes.data,ids.size)==0
        handles.ids.extend(map(int,ids))
        source.close()
        for axis, want, handle in zip(axes,expected,ids):
            np.testing.assert_array_equal(axis.numpy(), want)
            np.testing.assert_array_equal(handles.get(int(handle)),want)
            assert axis.dtype == np.dtype(np.int64)
            axis.close()
    if source is not owner: source.close()
    owner.close()

@pytest.mark.parametrize('dtype', [np.float32,np.float64])
def test_nonfinite_truth(dtype):
    a=np.array([0.,-0.,np.nan,np.inf,-np.inf,np.nextafter(dtype(0),dtype(1))],dtype=dtype)
    with fp.argwhere(a) as result:
        np.testing.assert_array_equal(result.numpy(),np.argwhere(a))
    axes=fp.nonzero(a)
    np.testing.assert_array_equal(axes[0].numpy(),np.nonzero(a)[0]);axes[0].close()


@pytest.mark.parametrize('dtype', DTYPES)
@pytest.mark.parametrize('shape', [(), (0,), (5,), (2,3), (2,0,3), (2,3,4)])
@pytest.mark.parametrize('layout', ['C','F','reverse','step','broadcast'])
def test_native_coordinates(frumpy_driver, dtype, shape, layout):
    a=np.asarray((np.arange(np.prod(shape,dtype=int)).reshape(shape)%3).astype(dtype))
    if layout=='F':a=np.array(a,order='F')
    elif layout=='broadcast':a=np.broadcast_to(np.array(1,dtype=dtype),shape)
    elif a.ndim and layout in ('reverse','step'):a=a[...,::-1 if layout=='reverse' else 2]
    for operation in ('argwhere','nonzero'):
        code,result=execute(frumpy_driver,'coords_'+operation,a,axis=DTYPES.index(dtype)+1)
        if not a.ndim and operation=='nonzero':
            assert code==1
        else:
            assert code==0
            np.testing.assert_array_equal(result,np.argwhere(a))

@pytest.mark.parametrize('dtype',DTYPES)
@pytest.mark.parametrize('value',[0,1,-1])
def test_scalar_contract(handles,dtype,value):
    a=np.array(value,dtype=dtype)
    with fp.argwhere(a) as result:
        assert result.shape==((1,0) if bool(a) else (0,0))
    with pytest.raises(ValueError):fp.nonzero(a)
    raw=handles.put(a)
    ids=np.full(2,-1,dtype=np.int64)
    assert handles.lib.frumpy_nonzero(raw,ids.ctypes.data,2)==1
    assert not ids.any()


def test_c_capacity_and_handles(handles):
    raw=handles.put(np.ones((2,3,4),dtype=np.int32))
    ids=np.full(32,-1,dtype=np.int64)
    for count in (0,1,2):
        assert handles.lib.frumpy_nonzero(raw,ids.ctypes.data,count)==1
        assert not ids[:count].any()
    assert handles.lib.frumpy_nonzero(raw,None,3)==1
    assert handles.lib.frumpy_nonzero(raw,ids.ctypes.data,-1)==1
    assert handles.lib.frumpy_nonzero(raw,ids.ctypes.data,33)==1
    assert handles.lib.frumpy_nonzero(-1,ids.ctypes.data,32)==8
    assert not ids.any()
    assert handles.lib.frumpy_nonzero(raw,ids.ctypes.data,32)==0
    assert not ids[3:].any()
    handles.ids.extend(map(int,ids[:3]))
    assert handles.lib.frumpy_release(int(ids[0]))==0
    handles.ids.remove(int(ids[0]))
    np.testing.assert_array_equal(handles.get(int(ids[2])),np.nonzero(np.ones((2,3,4)))[2])


@pytest.mark.parametrize('dtype',DTYPES)
def test_rank_limit_and_method(dtype):
    a=np.ones((1,)*32,dtype=dtype)
    with fp.asarray(a) as source:
        axes=source.nonzero()
        assert len(axes)==32
        for axis in axes:
            np.testing.assert_array_equal(axis.numpy(),[0]);axis.close()
        with fp.argwhere(source) as result:
            np.testing.assert_array_equal(result.numpy(),np.zeros((1,32),dtype=np.int64))


@pytest.mark.parametrize('dtype',DTYPES)
@pytest.mark.parametrize('fill',[0,1])
def test_uniform_inputs(dtype,fill):
    a=np.full((3,4),fill,dtype=dtype)
    axes=fp.nonzero(a)
    for axis,want in zip(axes,np.nonzero(a)):
        np.testing.assert_array_equal(axis.numpy(),want);axis.close()
    with fp.argwhere(a) as result:
        np.testing.assert_array_equal(result.numpy(),np.argwhere(a))
