"""Selection contracts around early exits and incremental C-order traversal."""
import numpy as np
import pytest
import frumpy as fp
from test_frumpy_differential import execute
from test_c_boundary import abi, handles

@pytest.mark.parametrize('op',['argmin','argmax'])
@pytest.mark.parametrize('match',[0,1,31,63,None])
@pytest.mark.parametrize('layout',['C','F','reverse','step','zero'])
def test_bool_scan(frumpy_driver,handles,op,match,layout):
    target=op=='argmax'
    a=np.full((4,4,4),not target,dtype=np.bool_)
    if match is not None:a.flat[match]=target
    if layout=='F':a=np.asfortranarray(a)
    if layout=='zero':a=np.broadcast_to(a[:1,:1,:1],(4,4,4))
    if layout=='reverse':a=a[::-1,:,::-1]
    if layout=='step':a=a[:,::2,:]
    for axis in [None,0,1,2]:
        expected=getattr(np,op)(a,axis=axis,keepdims=True)
        code,result=execute(frumpy_driver,'reduce_'+op,a,axis=1,side=99 if axis is None else axis,indices=[1])
        assert code==0
        np.testing.assert_array_equal(result,expected)
        raw=handles.make('reduce',8 if op=='argmin' else 9,handles.put(a),int(axis is not None),axis or 0,1)
        np.testing.assert_array_equal(handles.get(raw),expected)
        with fp.asarray(np.asfortranarray(a)) as owner,owner[::-1,:,::-1] as view:
            with getattr(fp,op)(view,axis=axis,keepdims=True) as actual:
                np.testing.assert_array_equal(actual.numpy(),getattr(np,op)(a[::-1,:,::-1],axis=axis,keepdims=True))

@pytest.mark.parametrize('dtype',[np.int32,np.int64,np.float32,np.float64])
@pytest.mark.parametrize('op',['argmin','argmax'])
@pytest.mark.parametrize('layout',['F','mixed','zero'])
def test_irregular_ties_and_nan(frumpy_driver,dtype,op,layout):
    a=np.asfortranarray(np.arange(210).reshape(5,6,7).astype(dtype))
    a[1,2,3]=a[3,4,5]=-1000 if op=='argmin' else 1000
    if np.dtype(dtype).kind=='f':
        a[0,0,0]=-np.inf if op=='argmin' else np.inf
        a[3,2,1]=np.nan
        a[4,3,2]=np.nan
    if layout=='mixed':a=a[::-2,::2,::-1]
    if layout=='zero':a=np.broadcast_to(a[:1],(5,6,7))
    for axis in [None,0,1,2]:
        code,result=execute(frumpy_driver,'reduce_'+op,a,axis=[np.int32,np.int64,np.float32,np.float64].index(dtype)+2,
                            side=99 if axis is None else axis,indices=[0])
        assert code==0
        np.testing.assert_array_equal(result,getattr(np,op)(a,axis=axis))
        with fp.asarray(a,order='K') as owner,owner[::-1,:,::-1] as view:
            with getattr(fp,op)(view,axis=axis) as actual:
                np.testing.assert_array_equal(actual.numpy(),getattr(np,op)(a[::-1,:,::-1],axis=axis))
