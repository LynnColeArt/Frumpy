"""Float32 norm shape/API compatibility and the widened scaled accumulation policy."""
import numpy as np
import pytest
import frumpy as fp
from test_c_boundary import abi, handles
from test_frumpy_differential import execute

@pytest.mark.parametrize('shape',[(),(0,),(7,),(3,4),(2,3,4),(2,0,4)])
@pytest.mark.parametrize('layout',['C','F','reverse','step','zero'])
@pytest.mark.parametrize('keep',[False,True])
def test_vector_norm(frumpy_driver,handles,shape,layout,keep):
    a=np.arange(np.prod(shape,dtype=int),dtype=np.float32).reshape(shape)/7-1
    if layout=='F':a=np.asfortranarray(a) if a.ndim else a
    if a.ndim and layout=='reverse':a=a[...,::-1]
    if a.ndim and layout=='step':a=a[...,::2]
    if layout=='zero':a=np.broadcast_to(np.float32(.25),a.shape)
    for axis in [None,*range(-a.ndim,a.ndim)]:
        code,x=execute(frumpy_driver,'vector_norm_r32',a,axis=99 if axis is None else axis,side=int(keep))
        assert code==0
        axes=np.array([] if axis is None else [axis],dtype=np.int64)
        raw=handles.get(handles.make('norm',0,handles.put(a),axes.ctypes.data,axes.size,int(keep)))
        with fp.linalg.vector_norm(a,axis=axis,keepdims=keep) as r:
            expected=np.linalg.vector_norm(a,axis=axis,keepdims=keep)
            for actual in [x,raw,r.numpy()]:
                assert actual.dtype==np.float32
                np.testing.assert_allclose(actual,expected,rtol=3e-6,atol=1e-7)

@pytest.mark.parametrize('shape',[(3,4),(2,3,4),(0,3,4),(2,0,4)])
@pytest.mark.parametrize('axes',[(-2,-1),(0,1),(1,0),(-1,0)])
@pytest.mark.parametrize('keep',[False,True])
def test_matrix_norm(frumpy_driver,handles,shape,axes,keep):
    a=np.arange(np.prod(shape),dtype=np.float32).reshape(shape)/7-1
    for source in [a,np.asfortranarray(a),a[...,::-1],a[...,::2]]:
        expected=np.linalg.norm(source,ord='fro',axis=axes,keepdims=keep)
        code,x=execute(frumpy_driver,'matrix_norm_axes_r32',source,side=int(keep),indices=axes)
        assert code==0
        values=np.array(axes,dtype=np.int64)
        raw=handles.get(handles.make('norm',1,handles.put(source),values.ctypes.data,2,int(keep)))
        with fp.linalg.matrix_norm(source,axis=axes,keepdims=keep) as r:
            for actual in [x,raw,r.numpy()]:
                assert actual.dtype==np.float32
                np.testing.assert_allclose(actual,expected,rtol=3e-6,atol=1e-7)

@pytest.mark.parametrize('values',[[1e30,-1e30],[1e-30,-1e-30],[0.,-0.],
    [np.inf,1.],[np.inf,np.nan],[np.nan,1.],[np.finfo(np.float32).max]*2,
    [np.nextafter(np.float32(0),np.float32(1))]*2,[]])
@pytest.mark.parametrize('matrix',[False,True])
def test_norm_precision(frumpy_driver,handles,values,matrix):
    a=np.array(values,dtype=np.float32)
    if matrix:a=a.reshape(1,-1)
    op='matrix_norm' if matrix else 'vector_norm'
    with np.errstate(all='ignore'):
        expected=np.float32(np.sqrt(np.sum(a.astype(np.float64)**2)))
    code,x=execute(frumpy_driver,op+'_r32',a,axis=99)
    assert code==0
    raw=handles.get(handles.make('norm',int(matrix),handles.put(a),None,0,0))
    with getattr(fp.linalg,op)(a) as r:
        for actual in [x,raw,r.numpy()]:
            np.testing.assert_array_equal(actual,expected)
            if expected==0:assert not np.signbit(actual)

@pytest.mark.parametrize('matrix,shape,axes,status',[(0,(2,3),[2],2),(0,(),[0],2),
    (1,(2,),[],1),(1,(2,3),[0,0],2),(1,(2,3),[0,2],2)])
def test_norm_invalid(handles,matrix,shape,axes,status):
    values=np.array(axes,dtype=np.int64)
    handles.make('norm',matrix,handles.put(np.ones(shape,dtype=np.float32)),
                 values.ctypes.data,len(axes),0,status=status)


def test_norm_real_views():
    a=np.arange(48,dtype=np.float32).reshape(6,8)
    with fp.asarray(a) as owner,owner[1:5:2,::-2] as view:
        for op in ['vector_norm','matrix_norm']:
            with getattr(fp.linalg,op)(view) as r:
                np.testing.assert_allclose(r.numpy(),getattr(np.linalg,op)(a[1:5:2,::-2]),rtol=2e-6)


def test_norm_small_contributions():
    a=np.ones(65537,dtype=np.float32);a[0]=2**12
    expected=np.float32(np.sqrt(np.sum(a.astype(np.float64)**2)))
    with fp.linalg.vector_norm(a) as r:
        assert r.item()==expected

@pytest.mark.parametrize('dtype',[np.bool_,np.int32,np.int64])
def test_norm_integral_stays_unsupported(handles,dtype):
    a=np.ones((2,2),dtype=dtype)
    for matrix,name in [(0,'vector_norm'),(1,'matrix_norm')]:
        handles.make('norm',matrix,handles.put(a),None,0,0,status=5)
        with pytest.raises(TypeError):getattr(fp.linalg,name)(a)
