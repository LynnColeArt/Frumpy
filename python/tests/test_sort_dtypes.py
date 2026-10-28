"""Stable five-dtype ordering, including exact integer and floating bit order."""
import numpy as np
import pytest
import frumpy as fp
from test_c_boundary import abi, handles
from test_frumpy_differential import execute
DTYPES=[np.bool_,np.int32,np.int64,np.float32,np.float64]

@pytest.mark.parametrize('dtype',DTYPES)
@pytest.mark.parametrize('op',['sort','argsort'])
@pytest.mark.parametrize('shape',[(),(0,),(1,),(31,),(32,),(33,),(65,),(3,35),(2,3,17),(0,3),(2,0)])
@pytest.mark.parametrize('layout',['C','F','reverse','step','zero'])
def test_stable_dtypes(frumpy_driver,handles,dtype,op,shape,layout):
    a=((np.arange(np.prod(shape,dtype=int))*37)%11-5).astype(dtype).reshape(shape)
    if layout=='F':a=np.asfortranarray(a) if a.ndim else a
    if layout=='reverse' and a.ndim:a=a[...,::-1]
    if layout=='step' and a.ndim:a=a[...,::2]
    if layout=='zero':a=np.broadcast_to(np.array(1,dtype=dtype),a.shape)
    axes=list(range(-a.ndim,a.ndim)) if a.ndim else [-1,0]
    for axis in axes:
        try:expected=getattr(np,op)(a,axis=axis,kind='stable')
        except (ValueError,IndexError):expected=None
        code,native=execute(frumpy_driver,'order_'+op,a,axis=DTYPES.index(dtype)+1,side=axis)
        raw=handles.make('sort',int(op=='argsort'),handles.put(a),axis,status=2 if expected is None else 0)
        if expected is None:
            assert code==2
            with pytest.raises(IndexError):getattr(fp,op)(a,axis=axis)
        else:
            assert code==0
            with getattr(fp,op)(a,axis=axis) as result:
                for actual in [native,handles.get(raw),result.numpy()]:
                    assert actual.dtype==np.dtype(np.int64 if op=='argsort' else dtype)
                    np.testing.assert_array_equal(actual,expected)
    with getattr(fp,op)(a,axis=None) as result:
        np.testing.assert_array_equal(result.numpy(),getattr(np,op)(a,axis=None,kind='stable'))

@pytest.mark.parametrize('dtype',DTYPES)
@pytest.mark.parametrize('op',['sort','argsort'])
def test_order_extremes_and_views(handles,dtype,op):
    if np.dtype(dtype).kind=='i':
        info=np.iinfo(dtype);a=np.array([info.max,info.max-1,info.min,info.min+1,info.max,0],dtype=dtype)
    elif np.dtype(dtype).kind=='f':
        uint=np.uint32 if dtype==np.float32 else np.uint64
        bits=[0x7fc00001,0x7fc00002] if dtype==np.float32 else [0x7ff8000000000001,0x7ff8000000000002]
        a=np.concatenate([np.array([np.inf,-0.,0.,-np.inf],dtype=dtype),np.array(bits,dtype=uint).view(dtype)])
    else:a=np.array([True,False,True,False,False,True])
    a=np.tile(a,17).reshape(3,34)
    with fp.asarray(a,order='F') as source,source[::-1,::-1] as view:
        before=view.numpy()
        result=getattr(fp,op)(view,axis=-1)
        expected=getattr(np,op)(before,axis=-1,kind='stable')
        np.testing.assert_array_equal(view.numpy(),before)
    with result:
        actual=result.numpy()
        assert result.flags.owndata
        if op=='sort' and np.dtype(dtype).kind=='f':
            np.testing.assert_array_equal(actual.view(uint),expected.view(uint))
        else:np.testing.assert_array_equal(actual,expected)
    raw=handles.get(handles.make('sort',int(op=='argsort'),handles.put(a),1))
    expected=getattr(np,op)(a,axis=1,kind='stable')
    if op=='sort' and np.dtype(dtype).kind=='f':np.testing.assert_array_equal(raw.view(uint),expected.view(uint))
    else:np.testing.assert_array_equal(raw,expected)

@pytest.mark.parametrize('dtype',DTYPES)
@pytest.mark.parametrize('axis',[-2147483648,-3,2,2147483647])
def test_order_invalid_axis(handles,dtype,axis):
    handle=handles.put(np.ones((2,3),dtype=dtype))
    for op in [0,1]:handles.make('sort',op,handle,axis,status=2)
