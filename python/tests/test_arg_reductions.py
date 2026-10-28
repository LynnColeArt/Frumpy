"""Argmin/argmax contracts across native descriptors, C handles and Python."""
import numpy as np
import pytest
import frumpy as fp
from test_c_boundary import abi, handles
from test_frumpy_differential import execute
DTYPES=[np.bool_,np.int32,np.int64,np.float32,np.float64]

@pytest.mark.parametrize('dtype',DTYPES)
@pytest.mark.parametrize('op',['argmin','argmax'])
@pytest.mark.parametrize('shape',[(),(7,),(3,4),(2,3,4),(0,3),(2,0),(0,0)])
@pytest.mark.parametrize('layout',['C','F','reverse','step','zero'])
@pytest.mark.parametrize('keep',[False,True])
def test_arg_shapes(frumpy_driver,handles,dtype,op,shape,layout,keep):
    a=(np.arange(np.prod(shape,dtype=int))%7-3).reshape(shape).astype(dtype)
    if layout=='F' and a.ndim:a=np.asfortranarray(a)
    if layout=='reverse' and a.ndim:a=a[...,::-1]
    if layout=='step' and a.ndim:a=a[...,::2]
    if layout=='zero':a=np.broadcast_to(np.array(1,dtype=dtype),a.shape)
    axes=[None,*range(-a.ndim,a.ndim)] if a.ndim else [None,0,-1]
    for axis in axes:
        try:expected=getattr(np,op)(a,axis=axis,keepdims=keep)
        except ValueError:expected=None
        code,native=execute(frumpy_driver,'reduce_'+op,a,axis=DTYPES.index(dtype)+1,
                            side=99 if axis is None else axis,indices=[int(keep)])
        raw=handles.make('reduce',8 if op=='argmin' else 9,handles.put(a),int(axis is not None),
                         0 if axis is None else axis,int(keep),status=1 if expected is None else 0)
        if expected is None:
            assert code==1
            with pytest.raises(ValueError):getattr(fp,op)(a,axis=axis,keepdims=keep)
        else:
            assert code==0
            with fp.asarray(a,order='K') as source:
                with getattr(source,op)(axis=axis,keepdims=keep) as method:
                    with getattr(fp,op)(source,axis=axis,keepdims=keep) as public:
                        for actual in [native,handles.get(raw),method.numpy(),public.numpy()]:
                            assert actual.dtype==np.int64
                            assert actual.shape==expected.shape
                            np.testing.assert_array_equal(actual,expected)

@pytest.mark.parametrize('dtype',DTYPES)
@pytest.mark.parametrize('op',['argmin','argmax'])
def test_arg_precision_and_ties(frumpy_driver,handles,dtype,op):
    values=[2,1,1,3,3]
    if dtype==np.int64:values=[2**63-1,2**63-2,-2**63,-2**63+1,-2**63]
    if dtype==np.int32:values=[2**31-1,2**31-2,-2**31,-2**31+1,-2**31]
    cases=[np.array(values,dtype=dtype)]
    if np.dtype(dtype).kind=='f':
        cases.extend(np.array(x,dtype=dtype) for x in [
            [1,np.nan,-np.inf,np.nan,np.inf],[np.nan,2,np.nan],[-0.,0.,-0.],
            [np.inf,np.inf,-np.inf,-np.inf],[np.finfo(dtype).max,-np.finfo(dtype).max],
            [0,np.nextafter(dtype(0),dtype(1)),0]])
    for a in cases:
        for source in [a,a[::-1]]:
            expected=getattr(np,op)(source)
            code,native=execute(frumpy_driver,'reduce_'+op,source,axis=DTYPES.index(dtype)+1,side=99,indices=[0])
            assert code==0
            raw=handles.get(handles.make('reduce',8 if op=='argmin' else 9,handles.put(source),0,0,0))
            with getattr(fp,op)(source) as result:
                for actual in [native,raw,result.numpy()]:np.testing.assert_array_equal(actual,expected)

@pytest.mark.parametrize('op',[8,9])
@pytest.mark.parametrize('axis',[-2147483648,-3,2,2147483647])
def test_arg_invalid_c_axis(handles,op,axis):
    handles.make('reduce',op,handles.put(np.ones((2,3),dtype=np.float32)),1,axis,0,status=2)

@pytest.mark.parametrize('op',['argmin','argmax'])
def test_arg_actual_views(op):
    a=np.arange(48,dtype=np.float32).reshape(6,8);a[3,4]=np.nan
    with fp.asarray(a) as owner,owner[1:5:2,::-2] as view:
        for axis in [None,0,1]:
            with getattr(fp,op)(view,axis=axis) as result:
                np.testing.assert_array_equal(result.numpy(),getattr(np,op)(a[1:5:2,::-2],axis=axis))
