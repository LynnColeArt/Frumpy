"""Same-dtype insertion contracts through native, C and Python interfaces."""
import numpy as np
import pytest
import frumpy as fp
from test_c_boundary import abi, handles
from test_frumpy_differential import execute
DTYPES=[np.bool_,np.int32,np.int64,np.float32,np.float64]

@pytest.mark.parametrize('dtype',DTYPES)
@pytest.mark.parametrize('side',['left','right'])
@pytest.mark.parametrize('length',[0,1,2,33,257])
@pytest.mark.parametrize('shape',[(),(0,),(9,),(3,4),(2,0,3)])
@pytest.mark.parametrize('layout',['C','F','step','reverse','zero'])
def test_search_dtypes(frumpy_driver,handles,dtype,side,length,shape,layout):
    source=np.sort((np.arange(length)%7-3).astype(dtype),kind='stable')
    values=(np.arange(np.prod(shape,dtype=int))%11-5).astype(dtype).reshape(shape)
    if layout=='step':
        source=np.repeat(source,2)[::2]
        if values.ndim:values=values[...,::2]
    if layout=='reverse':
        source=source[::-1].copy()[::-1]
        if values.ndim:values=values[...,::-1]
    if layout=='F' and values.ndim:values=np.asfortranarray(values)
    if layout=='zero':
        source=np.broadcast_to(np.array(1,dtype=dtype),(length,))
        values=np.broadcast_to(np.array(1,dtype=dtype),shape)
    expected=np.searchsorted(source,values,side=side)
    code,native=execute(frumpy_driver,'search_typed',source,values,axis=DTYPES.index(dtype)+1,side=int(side=='right'))
    assert code==0
    raw=handles.get(handles.make('searchsorted',handles.put(source),handles.put(values),int(side=='right')))
    with fp.searchsorted(source,values,side=side) as result:
        assert result.dtype==np.dtype(np.int64)
        for actual in [native,raw,result.numpy()]:
            assert actual.shape==np.shape(expected) and actual.dtype==np.dtype(np.int64)
            np.testing.assert_array_equal(actual,expected)

@pytest.mark.parametrize('dtype',DTYPES)
@pytest.mark.parametrize('side',['left','right'])
def test_search_extremes_views_and_lifetime(handles,dtype,side):
    if np.dtype(dtype).kind=='i':
        info=np.iinfo(dtype);a=np.array([info.min,info.min+1,-1,0,info.max-1,info.max,info.max],dtype=dtype)
    elif np.dtype(dtype).kind=='f':
        a=np.array([-np.inf,-1,-0.,0.,1,np.inf,np.nan,np.nan],dtype=dtype)
    else:a=np.array([False,False,True,True])
    q=np.concatenate([a,a[::-1]])
    backing=a[::-1].copy()
    with fp.asarray(backing) as owner,owner[::-1] as source,fp.asarray(q) as query_owner,query_owner[::-1] as queries:
        before=source.numpy()
        result=fp.searchsorted(source,queries,side=side)
        np.testing.assert_array_equal(source.numpy(),before)
    with result:
        assert result.flags.owndata and result.flags.c_contiguous
        np.testing.assert_array_equal(result.numpy(),np.searchsorted(a,q[::-1],side=side))
    raw=handles.get(handles.make('searchsorted',handles.put(a),handles.put(q),int(side=='right')))
    np.testing.assert_array_equal(raw,np.searchsorted(a,q,side=side))

@pytest.mark.parametrize('lhs',DTYPES)
@pytest.mark.parametrize('rhs',DTYPES)
def test_search_mixed_rejected(handles,lhs,rhs):
    if lhs==rhs:return
    a=np.array([0,1],dtype=lhs);q=np.array([1],dtype=rhs)
    handles.make('searchsorted',handles.put(a),handles.put(q),0,status=5)
    with pytest.raises(TypeError):fp.searchsorted(a,q)

@pytest.mark.parametrize('dtype',DTYPES)
@pytest.mark.parametrize('shape',[(),(2,3)])
def test_search_rank_and_flag_errors(handles,dtype,shape):
    source=handles.put(np.ones(shape,dtype=dtype));query=handles.put(np.array(1,dtype=dtype))
    handles.make('searchsorted',source,query,0,status=1)
    handles.make('searchsorted',handles.put(np.ones(3,dtype=dtype)),query,2,status=1)
    with pytest.raises(ValueError):fp.searchsorted(np.ones(3,dtype=dtype),np.array(1,dtype=dtype),side='other')
