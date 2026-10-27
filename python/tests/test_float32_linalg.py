"""Float32 native/ABI/Python linalg: shape rules, storage and numerical contracts."""
import numpy as np
import pytest
import frumpy as fp
from test_frumpy_differential import execute, matmul_cases, solve_cases, batched_solve_cases
from test_c_boundary import abi, handles  # Reuse raw-ABI fixtures, independent of the wrapper.


def cases():
    for a, b in matmul_cases():
        yield 'matmul', a.astype(np.float32), b.astype(np.float32)
    for a, b in solve_cases()[:-1]:  # The float64-only 1e100 range exceeds float32.
        yield 'solve', a.astype(np.float32), b.astype(np.float32)
    for a, b in batched_solve_cases():
        try:
            np.linalg.solve(a, b)
        except ValueError:
            continue
        yield 'solve', a.astype(np.float32), b.astype(np.float32)


@pytest.mark.parametrize('operation,a,b', list(cases()))
@pytest.mark.parametrize('entry', ['native', 'abi', 'python'])
def test_float32_linalg(frumpy_driver, handles, operation, a, b, entry):
    expected = a @ b if operation == 'matmul' else np.linalg.solve(a, b)
    if entry == 'native':
        status, actual = execute(frumpy_driver, operation+'_r32', a, b)
        assert status == 0
    elif entry == 'abi':
        lhs, rhs = handles.put(a), handles.put(b)
        actual = handles.get(handles.make('linalg', 3 if operation == 'matmul' else 4, lhs, rhs))
        np.testing.assert_array_equal(handles.get(lhs), a)
        np.testing.assert_array_equal(handles.get(rhs), b)
    else:
        with fp.asarray(a) as lhs, fp.asarray(b) as rhs:
            result = lhs @ rhs if operation == 'matmul' else fp.linalg.solve(lhs, rhs)
            np.testing.assert_array_equal(lhs.numpy(), a)
            np.testing.assert_array_equal(rhs.numpy(), b)
        with result:
            assert result.flags.owndata and result.flags.c_contiguous
            actual = result.numpy()
    assert actual.dtype == np.float32
    assert actual.shape == expected.shape
    np.testing.assert_allclose(actual, expected, rtol=2e-5, atol=2e-5)


@pytest.mark.parametrize('operation', ['matmul', 'solve'])
@pytest.mark.parametrize('layout', ['F', 'reverse', 'step', 'offset', 'zero'])
def test_float32_linalg_views(frumpy_driver, operation, layout):
    a = np.array([[4, 1, 0], [1, 5, 1], [0, 1, 6]], dtype=np.float32)
    b = np.arange(6, dtype=np.float32).reshape(3, 2)
    if layout == 'F':
        a, b = np.asfortranarray(a), np.asfortranarray(b)
    elif layout == 'reverse':
        a, b = a[::-1, ::-1], b[::-1]
    elif layout in ('step', 'offset'):
        storage = np.zeros((7, 7), dtype=np.float32)
        view = storage[1:7:2, 1:7:2] if layout == 'step' else storage[1:4, 2:5]
        view[:] = a
        a = view
    else:
        b = np.broadcast_to(b[:1], (3, 2))
    expected = a @ b if operation == 'matmul' else np.linalg.solve(a, b)
    code, actual = execute(frumpy_driver, operation+'_r32', a, b)
    assert code == 0
    np.testing.assert_allclose(actual, expected, rtol=2e-5, atol=2e-5)
    with fp.asarray(a, order='K') as lhs, fp.asarray(b, order='K') as rhs:
        # Native tests above preserve arbitrary strides; these exercise C/F import too.
        with (lhs @ rhs if operation == 'matmul' else fp.linalg.solve(lhs, rhs)) as result:
            np.testing.assert_allclose(result.numpy(), expected, rtol=2e-5, atol=2e-5)


@pytest.mark.parametrize('nrhs', [0, 1, 3])
@pytest.mark.parametrize('batched', [False, True])
def test_float32_singular(frumpy_driver, handles, nrhs, batched):
    a = np.eye(2, dtype=np.float32)
    if batched:
        a = np.stack([a, np.zeros_like(a)])
    else:
        a[:] = 0
    b = np.ones((2, nrhs), dtype=np.float32)
    assert execute(frumpy_driver, 'solve_r32', a, b)[0] == 7
    handles.make('linalg', 4, handles.put(a), handles.put(b), status=7)
    with fp.asarray(a) as lhs, fp.asarray(b) as rhs:
        with pytest.raises(ValueError, match='singular'):
            fp.linalg.solve(lhs, rhs)


@pytest.mark.parametrize('op', [3, 4])
@pytest.mark.parametrize('value', [np.nan, np.inf, -np.inf])
def test_float32_nonfinite(handles, op, value):
    a = np.eye(2, dtype=np.float32)
    a[0, 0] = value
    handles.make('linalg', op, handles.put(a), handles.put(np.eye(2, dtype=np.float32)), status=6)


@pytest.mark.parametrize('left,right', [(np.float32,np.float64), (np.float64,np.float32),
                                       (np.int32,np.int32)])
@pytest.mark.parametrize('op', [3, 4])
def test_float32_linalg_promotion_remains_explicit(handles, left, right, op):
    handles.make('linalg', op, handles.put(np.eye(2,dtype=left)),
                 handles.put(np.eye(2,dtype=right)), status=5)


@pytest.mark.parametrize('operation,a,b', [
    ('matmul', np.array(1), np.eye(2)),
    ('matmul', np.eye(2), np.array(1)),
    ('matmul', np.ones((2, 3)), np.ones((2, 4))),
    ('matmul', np.ones((2, 2, 3)), np.ones((3, 3, 4))),
    ('solve', np.ones(2), np.ones(2)),
    ('solve', np.ones((2, 3)), np.ones(2)),
    ('solve', np.eye(2), np.ones(3)),
    ('solve', np.eye(2), np.array(1)),
    ('solve', np.ones((2, 2, 2)), np.ones((3, 2, 1))),
])
def test_float32_invalid_shapes(frumpy_driver, handles, operation, a, b):
    a, b = a.astype(np.float32), b.astype(np.float32)
    with pytest.raises(ValueError):
        np.matmul(a, b) if operation == 'matmul' else np.linalg.solve(a, b)
    assert execute(frumpy_driver, operation+'_r32', a, b)[0] == 1
    handles.make('linalg', 3 if operation == 'matmul' else 4,
                 handles.put(a), handles.put(b), status=1)
    with fp.asarray(a) as lhs, fp.asarray(b) as rhs:
        with pytest.raises(ValueError):
            lhs @ rhs if operation == 'matmul' else fp.linalg.solve(lhs, rhs)


@pytest.mark.parametrize('scale', [1e-20, 1., 1e20])
@pytest.mark.parametrize('n', [2, 7, 32])
def test_float32_solve_residual(frumpy_driver, n, scale):
    rng = np.random.default_rng(20261027)
    a = ((rng.normal(size=(n, n)) + n*np.eye(n))*scale).astype(np.float32)
    b = (rng.normal(size=(n, 3))*scale).astype(np.float32)
    status, actual = execute(frumpy_driver, 'solve_r32', a, b)
    assert status == 0
    np.testing.assert_allclose(actual, np.linalg.solve(a,b), rtol=2e-5, atol=2e-5)
    a64, b64, x64 = a.astype(float), b.astype(float), actual.astype(float)
    relative_residual = np.linalg.norm(a64@x64-b64, np.inf) / (
        np.linalg.norm(a64, np.inf)*np.linalg.norm(x64, np.inf)+np.linalg.norm(b64, np.inf))
    assert relative_residual < 32*np.finfo(np.float32).eps


@pytest.mark.parametrize('operation', ['matmul', 'solve'])
@pytest.mark.parametrize('layout', ['reverse', 'step', 'offset'])
def test_float32_python_strided_handles(operation, layout):
    a = np.array([[4, 1, 0], [1, 5, 1], [0, 1, 6]], dtype=np.float32)
    storage = np.zeros((7, 7), dtype=np.float32)
    key = (slice(1, 7, 2), slice(1, 7, 2)) if layout == 'step' else (slice(1, 4), slice(2, 5))
    storage[key] = a
    if layout == 'reverse':
        key = (slice(3, 0, -1), slice(4, 1, -1))
    expected_a = storage[key]
    b = np.arange(6, dtype=np.float32).reshape(3, 2)
    expected = expected_a@b if operation == 'matmul' else np.linalg.solve(expected_a, b)
    with fp.asarray(storage) as owner, fp.asarray(b) as rhs:
        with owner[key] as lhs:
            assert lhs.strides == expected_a.strides
            with (lhs@rhs if operation == 'matmul' else fp.linalg.solve(lhs, rhs)) as result:
                np.testing.assert_allclose(result.numpy(), expected, rtol=2e-5, atol=2e-5)
                assert result.flags.owndata and result.flags.c_contiguous


def test_float32_ill_conditioned_residual(frumpy_driver):
    n = 6
    a = (1 / (np.arange(n)[:,None] + np.arange(n)[None,:] + 1)).astype(np.float32)
    b = np.ones(n, dtype=np.float32)
    code, x = execute(frumpy_driver, 'solve_r32', a, b)
    assert code == 0
    aa, xx, bb = a.astype(float), x.astype(float), b.astype(float)
    residual = np.linalg.norm(aa@xx-bb,np.inf)
    scale = np.linalg.norm(aa,np.inf)*np.linalg.norm(xx,np.inf)+np.linalg.norm(bb,np.inf)
    assert residual / scale < 32*np.finfo(np.float32).eps
    # Forward agreement with NumPy's widened solve is deliberately not promised here.
