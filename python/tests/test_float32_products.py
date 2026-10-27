"""Float32 products: NumPy shapes/IEEE behavior and bounded pairwise accumulation."""
import numpy as np
import pytest
import frumpy as fp
from test_c_boundary import abi, handles
from test_frumpy_differential import execute, dot_cases, layouts


def product_cases():
    for a, b in dot_cases():
        yield 'dot', a.astype(np.float32), b.astype(np.float32)
    for a in layouts()+[np.array(-0.),np.array(3.),np.arange(24.).reshape(2,3,4)]:
        for b in [np.array(2.),np.array([-0.,0.,-2.,3.]),np.arange(6.).reshape(2,3).T,np.empty((0,2))]:
            yield 'outer', a.astype(np.float32), b.astype(np.float32)


@pytest.mark.parametrize('operation,a,b',list(product_cases()))
@pytest.mark.parametrize('entry',['native','abi','python'])
def test_float32_products(frumpy_driver,handles,operation,a,b,entry):
    oracle=getattr(np,operation)
    try:
        expected=oracle(a,b)
    except ValueError:
        if entry=='native':
            assert execute(frumpy_driver,operation+'_r32',a,b)[0]==1
        elif entry=='abi':
            handles.make('linalg',1 if operation=='outer' else 2,handles.put(a),handles.put(b),status=1)
        else:
            with fp.asarray(a) as left,fp.asarray(b) as right:
                with pytest.raises(ValueError):getattr(fp,operation)(left,right)
        return
    if entry=='native':
        code,actual=execute(frumpy_driver,operation+'_r32',a,b)
        assert code==0
    elif entry=='abi':
        left,right=handles.put(a),handles.put(b)
        actual=handles.get(handles.make('linalg',1 if operation=='outer' else 2,left,right))
        np.testing.assert_array_equal(handles.get(left),a)
        np.testing.assert_array_equal(handles.get(right),b)
    else:
        with fp.asarray(a) as left,fp.asarray(b) as right:
            result=getattr(fp,operation)(left,right)
            np.testing.assert_array_equal(left.numpy(),a)
            np.testing.assert_array_equal(right.numpy(),b)
        with result:
            assert result.flags.owndata and result.flags.c_contiguous
            actual=result.numpy()
    assert actual.dtype==np.float32
    assert actual.shape==np.shape(expected)
    np.testing.assert_allclose(actual,expected,rtol=2e-5,atol=2e-5)
    if operation=='outer' or a.ndim==0 or b.ndim==0:
        # Scalar dot preserves IEEE multiply signs; NumPy dot may normalize zeros via BLAS.
        with np.errstate(all='ignore'):
            signed_expected = expected if operation=='outer' else np.multiply(a,b)
        np.testing.assert_array_equal(np.signbit(actual[actual==0]),
                                      np.signbit(np.asarray(signed_expected)[actual==0]))


def pairwise(products):
    if len(products)<=32:
        total=np.float32(0)
        for term in products:total=np.float32(total+term)
        return total
    mid=len(products)//2
    return np.float32(pairwise(products[:mid])+pairwise(products[mid:]))


@pytest.mark.parametrize('n',[0,1,31,32,33,64,127,128,129,4096,65536])
@pytest.mark.parametrize('kind',['random','cancellation','reverse','zero_stride'])
def test_float32_dot_accumulation(frumpy_driver,n,kind):
    rng=np.random.default_rng(20261028)
    a=rng.uniform(-1,1,n).astype(np.float32)
    b=rng.uniform(-1,1,n).astype(np.float32)
    if kind=='cancellation' and n>=2:
        a[:]=1;a[0]=2**24;a[-1]=-2**24;b[:]=1
    elif kind=='reverse':
        a,b=a[::-1],b[::-1]
    elif kind=='zero_stride':
        a=np.broadcast_to(np.float32(.25),(n,));b[:]=.5
    code,x=execute(frumpy_driver,'dot_r32',a,b)
    assert code==0
    products=a*b
    expected=pairwise(products)
    # The arithmetic policy is checked independently of NumPy's BLAS reduction tree.
    np.testing.assert_allclose(x,expected,rtol=2e-6,atol=2e-6)
    reference=np.dot(a.astype(float),b.astype(float))
    depth=32+int(np.ceil(np.log2(max(1,n))))
    bound=2*depth*np.finfo(np.float32).eps*np.sum(np.abs(a.astype(float)*b.astype(float)))
    assert abs(float(x)-reference)<=bound
    if n==0:assert not np.signbit(x)


@pytest.mark.parametrize('operation',['dot','outer'])
@pytest.mark.parametrize('a,b',[
    (np.array([np.nan,1]),np.array([1,2])),
    (np.array([np.inf,1]),np.array([1,2])),
    (np.array([np.inf,-np.inf]),np.array([1,1])),
    (np.array([-0.]),np.array(2.)),
    (np.array([np.finfo(np.float32).max]),np.array([2.])),
    (np.array([np.finfo(np.float32).tiny]),np.array([.5])),
    (np.empty(0),np.empty(0)),
])
def test_float32_product_ieee(frumpy_driver,handles,operation,a,b):
    a,b=a.astype(np.float32),b.astype(np.float32)
    with np.errstate(all='ignore'):expected=getattr(np,operation)(a,b)
    code,actual=execute(frumpy_driver,operation+'_r32',a,b)
    assert code==0
    np.testing.assert_array_equal(actual,expected)
    raw=handles.get(handles.make('linalg',1 if operation=='outer' else 2,handles.put(a),handles.put(b)))
    np.testing.assert_array_equal(raw,expected)
    with fp.asarray(a) as left,fp.asarray(b) as right,getattr(fp,operation)(left,right) as result:
        np.testing.assert_array_equal(result.numpy(),expected)


@pytest.mark.parametrize('operation',['dot','outer'])
@pytest.mark.parametrize('layout',['reverse','step','offset','F'])
def test_float32_product_views(frumpy_driver,operation,layout):
    storage=np.arange(48,dtype=np.float32).reshape(6,8)
    key={'reverse':(slice(4,0,-1),slice(6,0,-2)),
         'step':(slice(0,6,2),slice(0,8,2)),
         'offset':(slice(1,4),slice(2,6)),
         'F':(slice(None),slice(None))}[layout]
    a=storage[key]
    if layout=='F':a=np.asfortranarray(a)
    b=np.arange(a.shape[-1]*2,dtype=np.float32).reshape(a.shape[-1],2)
    code,x=execute(frumpy_driver,operation+'_r32',a,b)
    assert code==0
    np.testing.assert_allclose(x,getattr(np,operation)(a,b),rtol=2e-5,atol=2e-5)
    with fp.asarray(storage if layout!='F' else a,order='K') as owner,fp.asarray(b) as rhs:
        with owner[key if layout!='F' else (...,)] as lhs:
            with getattr(fp,operation)(lhs,rhs) as result:
                np.testing.assert_allclose(result.numpy(),getattr(np,operation)(a,b),rtol=2e-5,atol=2e-5)


@pytest.mark.parametrize('operation',[1,2])
@pytest.mark.parametrize('left,right',[(np.float32,np.float64),(np.float64,np.float32),(np.int32,np.int32)])
def test_float32_product_promotion_explicit(handles,operation,left,right):
    handles.make('linalg',operation,handles.put(np.ones(3,dtype=left)),
                 handles.put(np.ones(3,dtype=right)),status=5)
