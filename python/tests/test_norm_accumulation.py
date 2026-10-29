"""Pairwise widened norms: exact finite square sums, layouts and IEEE boundaries."""
import math
import numpy as np
import pytest
import frumpy as fp
from test_c_boundary import abi, handles
from test_frumpy_differential import execute


def reference(a):
    # Float32 products fit exactly in float64. fsum avoids a long sequential reference sum.
    values=np.asarray(a,dtype=np.float32).ravel().astype(np.float64)
    if np.isnan(values).any():return np.float32(np.nan)
    if np.isinf(values).any():return np.float32(np.inf)
    with np.errstate(over='ignore'):
        return np.float32(math.sqrt(math.fsum(float(x)*float(x) for x in values)))

@pytest.mark.parametrize('n',[0,1,63,64,65,127,128,129,4097,65537])
@pytest.mark.parametrize('kind',['random','range','small','ieee'])
@pytest.mark.parametrize('layout',['C','reverse','step','zero'])
def test_widened_norm(frumpy_driver,handles,n,kind,layout):
    rng=np.random.default_rng(n+42)
    a=rng.uniform(-1,1,n).astype(np.float32)
    if kind=='range':
        a=np.ldexp(rng.uniform(.5,1,n),rng.integers(-148,128,n)).astype(np.float32)
    if kind=='small' and n:
        a[:]=1;a[0]=4096
    if kind=='ieee' and n:
        a[-1]=np.inf
        if n>1:a[0]=np.nan
    if layout=='reverse':a=a[::-1]
    if layout=='step':
        storage=np.zeros(2*n,dtype=np.float32);storage[::2]=a;a=storage[::2]
    if layout=='zero':a=np.broadcast_to(np.float32(.125),(n,))
    expected=reference(a)
    code,native=execute(frumpy_driver,'vector_norm_r32',a,axis=99)
    assert code==0
    raw=handles.get(handles.make('norm',0,handles.put(a),None,0,0))
    with fp.linalg.vector_norm(a) as result:
        for actual in [native,raw,result.numpy()]:
            assert actual.dtype==np.float32
            np.testing.assert_allclose(actual,expected,rtol=2*np.finfo(np.float32).eps,atol=0)
            if expected==0:assert not np.signbit(actual)

@pytest.mark.parametrize('axes',[(0,2),(2,0),(0,1),(1,2)])
@pytest.mark.parametrize('layout',['C','F','reverse','step'])
def test_irregular_frobenius(frumpy_driver,axes,layout):
    rng=np.random.default_rng(20261027)
    a=np.ldexp(rng.uniform(.5,1,(7,9,11)),rng.integers(-148,120,(7,9,11))).astype(np.float32)
    if layout=='F':a=np.asfortranarray(a)
    if layout=='reverse':a=a[::-1,:,::-1]
    if layout=='step':a=a[:,::2,:]
    moved=np.moveaxis(a,axes,(-2,-1))
    expected=np.array([reference(x) for x in moved],dtype=np.float32)
    code,actual=execute(frumpy_driver,'matrix_norm_axes_r32',a,indices=axes)
    assert code==0
    np.testing.assert_allclose(actual,expected,rtol=2*np.finfo(np.float32).eps,atol=0)
    with fp.asarray(a,order='K') as source,fp.linalg.matrix_norm(source,axis=axes) as result:
        np.testing.assert_allclose(result.numpy(),expected,rtol=2*np.finfo(np.float32).eps,atol=0)
