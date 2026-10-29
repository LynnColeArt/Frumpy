"""Finite float32/float64 solve and bounded Euclidean/Frobenius norms."""
import numpy as np
from . import _ffi, _linalg
from ._array import asarray, ndarray, axis_value


def solve(a, b):
    return _linalg(4, a, b)


def vector_norm(source, axis=None, keepdims=False):
    source = asarray(source, order="K")
    axes = np.asarray(() if axis is None else (axis_value(axis, source.ndim),), dtype=np.int64)
    return ndarray(_ffi.make("norm", 0, source._handle, axes.ctypes.data, axes.size, bool(keepdims)))


def matrix_norm(source, axis=(-2, -1), keepdims=False):
    source = asarray(source, order="K")
    if len(axis) != 2:
        raise ValueError("matrix_norm requires two axes")
    axes = np.asarray([axis_value(a, source.ndim) for a in axis], dtype=np.int64)
    return ndarray(_ffi.make("norm", 1, source._handle, axes.ctypes.data, 2, bool(keepdims)))
