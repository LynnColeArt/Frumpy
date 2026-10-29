"""Floating-result product promotion, checked against NumPy on all interfaces."""
import numpy as np
import pytest
import frumpy as fp
from test_c_boundary import abi, handles
from test_frumpy_differential import execute

DTYPES = [np.bool_, np.int32, np.int64, np.float32, np.float64]
PAIRS = [(a, b) for a in DTYPES for b in DTYPES if np.result_type(a, b).kind == 'f']

@pytest.mark.parametrize('left,right', PAIRS)
@pytest.mark.parametrize('op', ['dot', 'outer', 'matmul'])
@pytest.mark.parametrize('layout', ['C', 'F', 'reverse', 'empty', 'vector', 'batch'])
def test_promoted_products(frumpy_driver, handles, left, right, op, layout):
    a = np.arange(12).reshape(3, 4).astype(left)
    b = np.arange(8).reshape(4, 2).astype(right)
    if layout == 'F': a, b = np.asfortranarray(a), np.asfortranarray(b)
    if layout == 'reverse': a, b = a[:, ::-1], b[::-1, :]
    if layout == 'empty': a, b = a[:, :0], b[:0, :]
    if layout == 'vector': a, b = a[0], b[:, 0]
    if layout == 'batch': a, b = a[None, ...], b[None, ...]
    expected = getattr(np, op)(a, b)
    assert expected.dtype == np.result_type(left, right)
    code, native = execute(frumpy_driver, 'mixed_' + op, a, b,
                           axis=DTYPES.index(left)+1, side=DTYPES.index(right)+1)
    assert code == 0
    raw = handles.get(handles.make('linalg', {'outer':1, 'dot':2, 'matmul':3}[op],
                                   handles.put(a), handles.put(b)))
    with fp.asarray(a, order='K') as x, fp.asarray(b, order='K') as y:
        with getattr(fp, op)(x, y) as result:
            for actual in (native, raw, result.numpy()):
                assert actual.dtype == expected.dtype
                np.testing.assert_allclose(actual, expected, rtol=2e-6, atol=2e-6)

@pytest.mark.parametrize('op', ['dot', 'outer', 'matmul'])
def test_conversion_precedes_arithmetic(handles, op):
    a = np.array([2**30, 2**30], dtype=np.int32)
    b = np.array([4, 4], dtype=np.float32)
    expected = getattr(np, op)(a, b)
    raw = handles.get(handles.make('linalg', {'outer':1, 'dot':2, 'matmul':3}[op],
                                   handles.put(a), handles.put(b)))
    np.testing.assert_array_equal(raw, expected)
    assert raw.dtype == np.float64

@pytest.mark.parametrize('left,right', [(a,b) for a in DTYPES[:3] for b in DTYPES[:3]])
@pytest.mark.parametrize('op', [1,2,3])
def test_integral_products_unsupported(handles, left, right, op):
    handles.make('linalg', op, handles.put(np.ones(2,dtype=left)),
                 handles.put(np.ones(2,dtype=right)), status=5)

@pytest.mark.parametrize('left,right', PAIRS)
@pytest.mark.parametrize('op', ['dot','outer'])
@pytest.mark.parametrize('scalar_left', [False,True])
def test_promoted_scalars(frumpy_driver,handles,left,right,op,scalar_left):
    a=np.array(2 if scalar_left else [1,2],dtype=left)
    b=np.array([1,2] if scalar_left else 2,dtype=right)
    expected=getattr(np,op)(a,b)
    code,native=execute(frumpy_driver,'mixed_'+op,a,b,
                        axis=DTYPES.index(left)+1,side=DTYPES.index(right)+1)
    assert code==0
    raw=handles.get(handles.make('linalg',1 if op=='outer' else 2,handles.put(a),handles.put(b)))
    with getattr(fp,op)(a,b) as result:
        for actual in [native,raw,result.numpy()]:
            assert actual.dtype==expected.dtype
            np.testing.assert_array_equal(actual,expected)

@pytest.mark.parametrize('op',['dot','outer','matmul'])
def test_mixed_real_views(op):
    a=np.arange(48,dtype=np.int32).reshape(6,8)
    b=np.arange(32,dtype=np.float32).reshape(8,4)
    with fp.asarray(a) as owner,fp.asarray(b) as rhs:
        with owner[1:5:2,::-2] as x,rhs[::-2,:] as y:
            with getattr(fp,op)(x,y) as result:
                np.testing.assert_array_equal(result.numpy(),getattr(np,op)(a[1:5:2,::-2],b[::-2,:]))

@pytest.mark.parametrize('op',['dot','outer'])
def test_promoted_ieee(op):
    a=np.array([np.inf,np.nan,-0.],dtype=np.float32)
    b=np.array([1.,2.,3.],dtype=np.float64)
    with np.errstate(all='ignore'):
        expected=getattr(np,op)(a,b)
    with getattr(fp,op)(a,b) as result:
        np.testing.assert_array_equal(result.numpy(),expected)

@pytest.mark.parametrize('op',['dot','matmul'])
def test_promoted_cancellation(frumpy_driver,handles,op):
    a=np.array([2**24,1,-2**24],dtype=np.float32)
    b=np.ones(3,dtype=np.int32)
    expected=np.float64(1)
    code,native=execute(frumpy_driver,'mixed_'+op,a,b,axis=4,side=2)
    assert code==0
    raw=handles.get(handles.make('linalg',2 if op=='dot' else 3,handles.put(a),handles.put(b)))
    with getattr(fp,op)(a,b) as result:
        for actual in [native,raw,result.numpy()]:
            np.testing.assert_array_equal(actual,expected)

@pytest.mark.parametrize('op',['dot','outer','matmul'])
def test_int64_rounding(frumpy_driver,handles,op):
    a=np.array([2**53+1,-2**53+3],dtype=np.int64)
    b=np.array([1,1],dtype=np.float32)
    expected=getattr(np,op)(a,b)
    code,native=execute(frumpy_driver,'mixed_'+op,a,b,axis=3,side=4)
    assert code==0
    raw=handles.get(handles.make('linalg',{'outer':1,'dot':2,'matmul':3}[op],handles.put(a),handles.put(b)))
    with getattr(fp,op)(a,b) as result:
        for actual in [native,raw,result.numpy()]:
            np.testing.assert_array_equal(actual,expected)

@pytest.mark.parametrize('op',[2,3])
def test_mixed_shape_failure_recovery(handles,op):
    a=handles.put(np.ones((2,3),dtype=np.int32))
    b=handles.put(np.ones((4,2),dtype=np.float32))
    for _ in range(10):handles.make('linalg',op,a,b,status=1)
    valid=handles.put(np.ones((3,2),dtype=np.float32))
    np.testing.assert_array_equal(handles.get(handles.make('linalg',op,a,valid)),np.full((2,2),3.))

@pytest.mark.parametrize('left,right',[(a,b) for a,b in PAIRS if a!=b])
def test_mixed_solve_still_unsupported(handles,left,right):
    handles.make('linalg',4,handles.put(np.eye(2,dtype=left)),
                 handles.put(np.ones(2,dtype=right)),status=5)
