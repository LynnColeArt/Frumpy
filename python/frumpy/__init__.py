"""Frumpy's bounded NumPy-compatible CPU array API, backed by Fortran."""
import operator
import numpy as np
from . import _ffi
from ._array import (ndarray, asarray, binary, unary, dtype_id, order_id, shape_buffer,
                     axis_value)

__version__ = "0.1.0"
bool_, int32, int64, float32, float64 = np.bool_, np.int32, np.int64, np.float32, np.float64


def empty(shape, dtype=float64, order="C"):
    dims = shape_buffer(shape)
    return ndarray(_ffi.make("create", dtype_id(dtype), dims.size, dims.ctypes.data, order_id(order)))


def full(shape, fill_value, dtype=None, order="C"):
    value = np.asarray(fill_value, dtype=dtype)
    if value.ndim != 0:
        raise ValueError("full requires a scalar fill value")
    dims = shape_buffer(shape)
    return ndarray(_ffi.make("full", dtype_id(value.dtype), dims.size, dims.ctypes.data,
                             order_id(order), value.ctypes.data))


def zeros(shape, dtype=float64, order="C"):
    return full(shape, 0, dtype, order)


def ones(shape, dtype=float64, order="C"):
    return full(shape, 1, dtype, order)


def array(values, dtype=None, order="C"):
    result = asarray(values, dtype, order)
    return result.copy(order) if isinstance(values, ndarray) else result


def copy(source, order="C"):
    return asarray(source, order="K").copy(order)


def ascontiguousarray(source, dtype=None):
    return asarray(source, dtype, order="K")._view(10)


def arange(start, stop=None, step=1.):
    if stop is None:
        start, stop = 0., start
    return ndarray(_ffi.make("arange", float(start), float(stop), float(step)))


def linspace(start, stop, num=50, endpoint=True):
    count = operator.index(num)
    if count < 0 or count > 2**63 - 1:
        raise ValueError("num is outside int64 range")
    return ndarray(_ffi.make("linspace", float(start), float(stop), count, bool(endpoint)))


def reshape(source, shape):
    return asarray(source, order="K").reshape(shape)


def transpose(source):
    return asarray(source, order="K").T


def swapaxes(source, axis1, axis2):
    return asarray(source, order="K").swapaxes(axis1, axis2)


def squeeze(source, axis=None):
    return asarray(source, order="K").squeeze(axis)


def expand_dims(source, axis):
    source = asarray(source, order="K")
    return source._view(5, (axis_value(axis, source.ndim, insertion=True),))


def ravel(source):
    return asarray(source, order="K").ravel()


def _linalg(op, lhs, rhs):
    lhs, rhs = asarray(lhs, order="K"), asarray(rhs, order="K")
    return ndarray(_ffi.make("linalg", op, lhs._handle, rhs._handle))


def outer(lhs, rhs):
    return _linalg(1, lhs, rhs)


def dot(lhs, rhs):
    return _linalg(2, lhs, rhs)


def matmul(lhs, rhs):
    return _linalg(3, lhs, rhs)


ndarray.__matmul__ = lambda self, other: matmul(self, other)
ndarray.__rmatmul__ = lambda self, other: matmul(other, self)


def where(condition, lhs, rhs):
    condition, lhs, rhs = (asarray(a, order="K") for a in (condition, lhs, rhs))
    return ndarray(_ffi.make("where", condition._handle, lhs._handle, rhs._handle))


def take(source, indices, axis=None):
    source = asarray(source, order="K")
    if axis is None:
        source = source.ravel()
        axis = 0
    indices = np.asarray(indices)
    if indices.ndim != 1 or indices.dtype.kind not in "iu":
        raise TypeError("take requires one-dimensional integer indices")
    if indices.dtype.kind == "u" and indices.size and int(indices.max()) > 2**63 - 1:
        raise OverflowError("index exceeds int64")
    indices = np.ascontiguousarray(indices, dtype=np.int64)
    return ndarray(_ffi.make("take", source._handle, indices.ctypes.data, indices.size,
                             axis_value(axis, source.ndim)))


def _join(stack_flag, arrays, axis):
    arrays = [asarray(a, order="K") for a in arrays]
    if not arrays:
        raise ValueError("joining requires at least one array")
    axis = axis_value(axis, arrays[0].ndim, insertion=bool(stack_flag))
    handles = np.asarray([a._handle for a in arrays], dtype=np.int64)
    return ndarray(_ffi.make("join", stack_flag, handles.ctypes.data, handles.size, axis))


def concatenate(arrays, axis=0):
    return _join(0, arrays, axis)


def stack(arrays, axis=0):
    return _join(1, arrays, axis)


def _sort(indices, source, axis):
    source = asarray(source, order="K")
    if axis is None:
        source, axis = source.ravel(), 0
    return ndarray(_ffi.make("sort", indices, source._handle, axis_value(axis, source.ndim)))


def sort(source, axis=-1):
    return _sort(0, source, axis)


def argsort(source, axis=-1):
    return _sort(1, source, axis)


def searchsorted(source, values, side="left"):
    if side not in ("left", "right"):
        raise ValueError("side must be left or right")
    source, values = asarray(source, order="K"), asarray(values, order="K")
    return ndarray(_ffi.make("searchsorted", source._handle, values._handle, side == "right"))


def flatnonzero(source):
    source = asarray(source, order="K")
    return ndarray(_ffi.make("flatnonzero", source._handle))


for _op, _name in enumerate(("add", "subtract", "multiply", "divide", "equal", "not_equal",
                             "less", "less_equal", "greater", "greater_equal", "logical_and",
                             "logical_or", "logical_xor"), 1):
    globals()[_name] = lambda lhs, rhs, op=_op: binary(op, lhs, rhs)
for _op, _name in enumerate(("negative", "absolute", "sqrt", "exp", "log", "sin", "cos",
                             "logical_not"), 1):
    globals()[_name] = lambda source, op=_op: unary(op, source)
for _op, _name in enumerate(("sum", "prod", "min", "max", "mean", "all", "any"), 1):
    globals()[_name] = lambda source, axis=None, keepdims=False, op=_op: asarray(
        source, order="K")._reduce(op, axis, keepdims)

from . import linalg, random  # noqa: E402: modules use the established array boundary
