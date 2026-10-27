"""Optimized floating casts preserve NumPy values and the general stride path."""
import numpy as np
import pytest
import frumpy as fp
from test_c_boundary import abi, handles
from test_frumpy_differential import execute

DTYPES=[np.bool_,np.int32,np.int64,np.float32,np.float64]

@pytest.mark.parametrize('source_dtype',DTYPES)
@pytest.mark.parametrize('target_dtype',[np.float32,np.float64])
@pytest.mark.parametrize('layout',['C','offset','singleton','F','step','reverse','zero','empty','scalar'])
def test_float_cast_layouts(frumpy_driver,handles,source_dtype,target_dtype,layout):
    storage=np.arange(24).astype(source_dtype)
    a=storage.reshape(4,6)
    if layout=='offset':a=storage[3:21].reshape(3,6)
    if layout=='singleton':a=np.lib.stride_tricks.as_strided(storage,shape=(1,24,1),strides=(0,storage.itemsize,-99*storage.itemsize))
    if layout=='F':a=np.asfortranarray(a)
    if layout=='step':a=a[:,::2]
    if layout=='reverse':a=a[::-1,::-1]
    if layout=='zero':a=np.broadcast_to(storage[:1],(4,6))
    if layout=='empty':a=a[:0]
    if layout=='scalar':a=storage[3].reshape(())
    expected=a.astype(target_dtype)
    code,native=execute(frumpy_driver,'cast_array',a,axis=DTYPES.index(source_dtype)+1,side=DTYPES.index(target_dtype)+1,indices=[4])
    assert code==0
    raw=handles.get(handles.make('cast',handles.put(a),DTYPES.index(target_dtype)+1,4))
    with fp.asarray(a,order='K') as source,source.astype(target_dtype) as result:
        for actual in (native,raw,result.numpy()):
            assert actual.dtype==expected.dtype
            np.testing.assert_array_equal(actual,expected)

@pytest.mark.parametrize('source_dtype',[np.int64,np.float32,np.float64])
@pytest.mark.parametrize('target_dtype',[np.float32,np.float64])
def test_float_cast_extremes(frumpy_driver,source_dtype,target_dtype):
    if source_dtype==np.int64:
        a=np.array([2**63-1,-2**63,2**53+1,-2**53+3,2**24+1],dtype=source_dtype)
    else:
        a=np.array([0.,-0.,np.nan,np.inf,-np.inf,np.finfo(source_dtype).max,
                    np.finfo(source_dtype).tiny,np.nextafter(source_dtype(0),source_dtype(1))],dtype=source_dtype)
    with np.errstate(all='ignore'):expected=a.astype(target_dtype)
    code,actual=execute(frumpy_driver,'cast_array',a,axis=DTYPES.index(source_dtype)+1,side=DTYPES.index(target_dtype)+1,indices=[4])
    assert code==0
    np.testing.assert_array_equal(actual,expected)
    np.testing.assert_array_equal(np.signbit(actual[expected==0]),np.signbit(expected[expected==0]))
