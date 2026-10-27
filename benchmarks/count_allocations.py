"""Count glibc allocator requests for warmed calls; run with count_allocations.c preloaded."""
import ctypes as C
import json
import numpy as np
import frumpy as fp
from frumpy import _ffi

probe = C.CDLL(None)
probe.frumpy_measure_calls.restype = C.c_uint64
probe.frumpy_measure_bytes.restype = C.c_uint64
x, y = fp.asarray(np.arange(16.)), fp.asarray(np.ones(16))
lib = _ffi.library()
out = _ffi.H()

def raw():
    assert lib.frumpy_binary(1, x._handle, y._handle, C.byref(out)) == 0
    assert lib.frumpy_release(out.value) == 0

def public():
    (x + y).close()

report = {}
for name, call in [('C ABI add/release', raw), ('Python add/close', public)]:
    for _ in range(100):
        call()
    probe.frumpy_measure_start()
    for _ in range(1000):
        call()
    probe.frumpy_measure_stop()
    report[name] = dict(calls_per_operation=probe.frumpy_measure_calls()/1000,
                       requested_bytes_per_operation=probe.frumpy_measure_bytes()/1000)
print(json.dumps(report, indent=2))
