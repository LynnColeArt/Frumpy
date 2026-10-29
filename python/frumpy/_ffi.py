"""ABI v1 loading and serialized calls. No numerical computation occurs here."""
import ctypes as C
import os
from pathlib import Path
import threading
import weakref

I, H, P, D = C.c_int32, C.c_int64, C.c_void_p, C.c_double
_lock = threading.RLock()
_library = None
_SIGNATURES = {
    "abi_version": [], "retain": [H], "release": [H],
    "create": [I, I, P, I, P], "import": [I, I, P, I, P, H, P],
    "export": [H, P, H], "info": [H, P, P, P, P, I, P, P],
    "full": [I, I, P, I, P, P], "view": [I, H, P, I, P],
    "binary": [I, H, H, P], "unary": [I, H, P], "cast": [H, I, I, P],
    "reduce": [I, H, I, I, I, P], "linalg": [I, H, H, P], "norm": [I, H, P, I, I, P],
    "arange": [D, D, D, P], "linspace": [D, D, H, I, P],
    "where": [H, H, H, P], "mask_select": [H, H, P], "assign": [H, H],
    "take": [H, P, H, I, P], "join": [I, P, I, I, P], "sort": [I, H, I, P],
    "searchsorted": [H, H, I, P], "flatnonzero": [H, P],
    "rng_create": [H, P], "rng_fill": [H, I, I, P, P],
    "rng_get_state": [H, P, I], "rng_set_state": [H, P, I],
}
_ERRORS = {
    1: (ValueError, "invalid shape, buffer, or argument"),
    2: (IndexError, "invalid axis"), 3: (MemoryError, "native allocation failed"),
    4: (OverflowError, "native size or value overflow"),
    5: (TypeError, "unsupported dtype"),
    6: (NotImplementedError, "operation is outside the supported Frumpy subset"),
    7: (ValueError, "singular matrix"), 8: (ReferenceError, "invalid or released handle"),
}


def library():
    global _library
    if _library is not None:
        return _library
    with _lock:
        if _library is None:
            path = os.environ.get("FRUMPY_LIBRARY", str(Path(__file__).with_name("libfrumpy.so")))
            lib = C.CDLL(path)
            for name, args in _SIGNATURES.items():
                function = getattr(lib, "frumpy_" + name)
                function.argtypes, function.restype = args, I
            if lib.frumpy_abi_version() != 1:
                raise ImportError("Frumpy requires C ABI version 1")
            _library = lib
        return _library


def call(name, *args):
    with _lock:
        status = getattr(library(), "frumpy_" + name)(*args)
        if status:
            exception, message = _ERRORS.get(status, (RuntimeError, "unknown native status"))
            raise exception(f"{name}: {message} (status {status})")


def make(name, *args):
    out = H()
    call(name, *args, C.byref(out))
    return out.value


def _release(handle):
    call("release", handle)


class OwnedHandle:
    def __init__(self, handle):
        self._id = handle
        self._finalizer = weakref.finalize(self, _release, handle)

    @property
    def _handle(self):
        if not self._finalizer.alive:
            raise ReferenceError("Frumpy handle is closed")
        return self._id

    def close(self):
        self._finalizer()

    def __enter__(self):
        self._handle
        return self

    def __exit__(self, *exc):
        self.close()
