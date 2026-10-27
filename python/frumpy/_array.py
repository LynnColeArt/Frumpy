"""Owned native arrays; NumPy is used only for buffer/coercion interoperability."""
import ctypes as C
import math
import operator
from collections import namedtuple

import numpy as np
from . import _ffi

_ArrayFlags = namedtuple("_ArrayFlags", "c_contiguous f_contiguous owndata")

DTYPES = tuple(np.dtype(t) for t in (np.bool_, np.int32, np.int64, np.float32, np.float64))
ORDERS = {"C": 0, "F": 1, "A": 2, "K": 3}
CASTING = {"no": 0, "equiv": 1, "safe": 2, "same_kind": 3, "unsafe": 4}


def dtype_id(dtype):
    dtype = np.dtype(dtype)
    if dtype not in DTYPES or not dtype.isnative:
        raise TypeError(f"unsupported Frumpy dtype: {dtype}")
    return DTYPES.index(dtype) + 1


def order_id(order):
    try:
        return ORDERS[order.upper()]
    except (AttributeError, KeyError):
        raise ValueError("order must be C, F, A or K") from None


def shape_buffer(shape):
    if isinstance(shape, (int, np.integer)):
        shape = (operator.index(shape),)
    shape = tuple(operator.index(n) for n in shape)
    if len(shape) > 32 or any(n < 0 for n in shape):
        raise ValueError("shape requires up to 32 nonnegative dimensions")
    return np.asarray(shape, dtype=np.int64)


def axis_value(axis, ndim, insertion=False):
    axis = operator.index(axis)
    rank = ndim + int(insertion)
    if axis < 0:
        axis += rank
    if not 0 <= axis < rank:
        raise IndexError("axis out of range")
    return axis


class ndarray(_ffi.OwnedHandle):
    """A managed native array. ``numpy()`` and NumPy conversion always copy."""
    __array_priority__ = 1000
    __array_ufunc__ = None

    def __init__(self, handle):
        super().__init__(handle)
        dtype, rank, flags, offset = _ffi.I(), _ffi.I(), _ffi.I(), _ffi.H()
        shape = np.empty(32, dtype=np.int64)
        strides = np.empty(32, dtype=np.int64)
        try:
            _ffi.call("info", handle, C.byref(dtype), C.byref(rank), shape.ctypes.data,
                      strides.ctypes.data, 32, C.byref(offset), C.byref(flags))
        except BaseException:
            self.close()
            raise
        self._dtype = DTYPES[dtype.value - 1]
        self._shape = tuple(int(n) for n in shape[:rank.value])
        self._strides = tuple(int(n) * self.dtype.itemsize for n in strides[:rank.value])
        self._ndim = rank.value
        self._size = math.prod(self.shape)
        self._flags = _ArrayFlags(c_contiguous=bool(flags.value & 1),
                                     f_contiguous=bool(flags.value & 2),
                                     owndata=bool(flags.value & 4))

    @property
    def dtype(self):
        return self._dtype

    @property
    def shape(self):
        return self._shape

    @property
    def strides(self):
        return self._strides

    @property
    def ndim(self):
        return self._ndim

    @property
    def size(self):
        return self._size

    @property
    def flags(self):
        return self._flags

    def numpy(self):
        result = np.empty(self.shape, dtype=self.dtype)
        _ffi.call("export", self._handle, result.ctypes.data, self.size)
        return result

    def __array__(self, dtype=None, copy=None):
        if copy is False:
            raise ValueError("Frumpy NumPy conversion requires a copy")
        result = self.numpy()
        return result if dtype is None else result.astype(dtype, copy=False)

    def __array_function__(self, func, types, args, kwargs):
        return NotImplemented

    def tolist(self):
        return self.numpy().tolist()

    def item(self):
        return self.numpy().item()

    def __repr__(self):
        return f"frumpy.ndarray({self.numpy()!r})"

    def __len__(self):
        if not self.ndim:
            raise TypeError("len() of unsized object")
        return self.shape[0]

    def __bool__(self):
        if self.size != 1:
            raise ValueError("array truth requires exactly one element")
        return bool(self.item())

    def _view(self, op, parameters=()):
        params = np.asarray(parameters, dtype=np.int64)
        return ndarray(_ffi.make("view", op, self._handle, params.ctypes.data, params.size))

    @property
    def T(self):
        return self._view(2)

    def transpose(self):
        return self.T

    def reshape(self, *shape):
        if len(shape) == 1 and not isinstance(shape[0], (int, np.integer)):
            shape = tuple(shape[0])
        shape = [operator.index(n) for n in shape]
        if shape.count(-1) > 1 or any(n < -1 for n in shape):
            raise ValueError("only one inferred dimension is allowed")
        if -1 in shape:
            known = math.prod(n for n in shape if n != -1)
            if not known or self.size % known:
                raise ValueError("cannot infer reshape dimension")
            shape[shape.index(-1)] = self.size // known
        return self._view(1, shape)

    def swapaxes(self, axis1, axis2):
        return self._view(3, (axis_value(axis1, self.ndim), axis_value(axis2, self.ndim)))

    def squeeze(self, axis=None):
        return self._view(4, () if axis is None else (axis_value(axis, self.ndim),))

    def ravel(self):
        return self._view(7)

    def flatten(self):
        return self._view(8)

    def copy(self, order="C"):
        return self._view(9, (order_id(order),))

    def astype(self, dtype, casting="unsafe"):
        if casting not in CASTING:
            raise ValueError("invalid casting policy")
        return ndarray(_ffi.make("cast", self._handle, dtype_id(dtype), CASTING[casting]))

    def _basic_view(self, key):
        key = key if isinstance(key, tuple) else (key,)
        if sum(k is Ellipsis for k in key) > 1:
            raise IndexError("at most one ellipsis is allowed")
        consumed = sum(k is not None and k is not Ellipsis for k in key)
        if consumed > self.ndim:
            raise IndexError("too many indices")
        expanded = []
        for k in key:
            if k is Ellipsis:
                expanded.extend([slice(None)] * (self.ndim - consumed))
            else:
                expanded.append(k)
        if not any(k is Ellipsis for k in key):
            expanded.extend([slice(None)] * (self.ndim - consumed))
        parameters, integers, additions = [], [], []
        axis, result_axis = 0, 0
        for k in expanded:
            if k is None:
                additions.append(result_axis)
                result_axis += 1
                continue
            extent = self.shape[axis]
            if isinstance(k, slice):
                start, stop, step = k.indices(extent)
                # Native empty slices accept normalized in-range empty bounds.
                if len(range(start, stop, step)) == 0:
                    start, stop, step = 0, 0, 1
                parameters.extend((start, stop, step))
                result_axis += 1
            elif isinstance(k, (int, np.integer)) and not isinstance(k, (bool, np.bool_)):
                index = operator.index(k)
                if index < 0:
                    index += extent
                if not 0 <= index < extent:
                    raise IndexError("index out of bounds")
                parameters.extend((index, index + 1, 1))
                integers.append(axis)
            else:
                raise TypeError("only basic indices or a full-shape boolean mask are supported")
            axis += 1
        view = self._view(6, parameters)
        for axis in reversed(integers):
            next_view = view.squeeze(axis)
            view.close()
            view = next_view
        for axis in additions:
            next_view = view._view(5, (axis,))
            view.close()
            view = next_view
        return view, bool(integers) and not view.ndim

    def __getitem__(self, key):
        if isinstance(key, ndarray) or isinstance(key, np.ndarray) and key.dtype == np.bool_:
            mask = asarray(key)
            return ndarray(_ffi.make("mask_select", self._handle, mask._handle))
        view, scalar = self._basic_view(key)
        if scalar:
            try:
                return view.numpy()[()]
            finally:
                view.close()
        return view

    def __setitem__(self, key, values):
        target, _ = self._basic_view(key)
        try:
            source = asarray(values)
            _ffi.call("assign", target._handle, source._handle)
        finally:
            target.close()

    def _reduce(self, op, axis=None, keepdims=False):
        if axis is not None:
            axis = operator.index(axis)
            if self.ndim:
                axis = axis_value(axis, self.ndim)
            elif axis not in (-1, 0):
                raise IndexError("axis out of range for scalar")
        return ndarray(_ffi.make("reduce", op, self._handle, axis is not None,
                                 axis or 0, bool(keepdims)))


def asarray(values, dtype=None, order="K"):
    if isinstance(values, ndarray):
        values._handle
        result = values if dtype is None or np.dtype(dtype) == values.dtype else values.astype(dtype)
        if order.upper() in ("A", "K") or (order.upper() == "C" and result.flags.c_contiguous) or (
                order.upper() == "F" and result.flags.f_contiguous):
            return result
        return result.copy(order)
    array = np.asarray(values, dtype=dtype)
    dtype_number = dtype_id(array.dtype)
    shape = shape_buffer(array.shape)
    flat = np.ascontiguousarray(array.ravel(order="C"))
    resolved = order_id(order)
    if resolved in (2, 3):
        resolved = int(array.flags.f_contiguous and not array.flags.c_contiguous)
    return ndarray(_ffi.make("import", dtype_number, array.ndim, shape.ctypes.data, resolved,
                             flat.ctypes.data, array.size))


def binary(op, lhs, rhs):
    # Python scalar strength is resolved before array-pair native promotion.
    if isinstance(lhs, ndarray) and type(rhs) in (bool, int, float):
        rhs = asarray(rhs, dtype=np.result_type(lhs.dtype, rhs))
    elif isinstance(rhs, ndarray) and type(lhs) in (bool, int, float):
        lhs = asarray(lhs, dtype=np.result_type(rhs.dtype, lhs))
    lhs, rhs = asarray(lhs, order="K"), asarray(rhs, order="K")
    return ndarray(_ffi.make("binary", op, lhs._handle, rhs._handle))


def unary(op, source):
    source = asarray(source, order="K")
    return ndarray(_ffi.make("unary", op, source._handle))


for _name, _op in [("add", 1), ("sub", 2), ("mul", 3), ("truediv", 4),
                   ("eq", 5), ("ne", 6), ("lt", 7), ("le", 8), ("gt", 9), ("ge", 10),
                   ("and", 11), ("or", 12), ("xor", 13)]:
    setattr(ndarray, f"__{_name}__", lambda self, other, op=_op: binary(op, self, other))
    if _op <= 4 or _op >= 11:
        setattr(ndarray, f"__r{_name}__", lambda self, other, op=_op: binary(op, other, self))
for _name, _op in [("neg", 1), ("abs", 2), ("invert", 8)]:
    setattr(ndarray, f"__{_name}__", lambda self, op=_op: unary(op, self))
for _name, _op in enumerate(("sum", "prod", "min", "max", "mean", "all", "any"), 1):
    setattr(ndarray, _op, lambda self, axis=None, keepdims=False, op=_name:
            self._reduce(op, axis, keepdims))
