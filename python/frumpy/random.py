"""Explicit xoshiro256** streams; reproducible Frumpy state, not NumPy streams."""
import operator
import numpy as np
from . import _ffi
from ._array import ndarray, shape_buffer


class Generator(_ffi.OwnedHandle):
    def __init__(self, seed=0):
        seed = operator.index(seed)
        if not -(2**63) <= seed < 2**63:
            raise OverflowError("seed must fit signed int64")
        super().__init__(_ffi.make("rng_create", seed))

    @property
    def state(self):
        words = np.empty(7, dtype=np.int64)
        _ffi.call("rng_get_state", self._handle, words.ctypes.data, words.size)
        return tuple(int(x) for x in words)

    @state.setter
    def state(self, words):
        words = np.asarray(words, dtype=np.int64)
        if words.shape != (7,):
            raise ValueError("generator state requires seven int64 words")
        words = np.ascontiguousarray(words)
        _ffi.call("rng_set_state", self._handle, words.ctypes.data, words.size)

    def _fill(self, normal, size):
        shape = shape_buffer(() if size is None else size)
        result = ndarray(_ffi.make("rng_fill", self._handle, normal, shape.size, shape.ctypes.data))
        if size is None:
            try:
                return result.item()
            finally:
                result.close()
        return result

    def random(self, size=None):
        return self._fill(0, size)

    def standard_normal(self, size=None):
        return self._fill(1, size)


def default_rng(seed=0):
    return Generator(seed)
