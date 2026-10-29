"""Count glibc allocator requests for warmed calls; run with count_allocations.c preloaded."""
import argparse
import ctypes as C
import json
import numpy as np
import frumpy as fp
from frumpy import _ffi

probe = C.CDLL(None)
probe.frumpy_measure_calls.restype = C.c_uint64
probe.frumpy_measure_bytes.restype = C.c_uint64
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--operation', choices=['add', 'matmul', 'solve'], default='add')
parser.add_argument('--layout', choices=['C', 'F'], default='C')
args = parser.parse_args()
if args.operation == 'add':
    x, y = fp.asarray(np.arange(16.)), fp.asarray(np.ones(16))
else:
    a = np.arange(256.).reshape(16, 16)/256 + np.eye(16)*16
    x = fp.asarray(np.array(a, order=args.layout), order='K')
    y = fp.asarray(np.ones((16, 16), order=args.layout), order='K')
lib = _ffi.library()
out = _ffi.H()

def raw():
    if args.operation == 'add':
        status = lib.frumpy_binary(1, x._handle, y._handle, C.byref(out))
    else:
        status = lib.frumpy_linalg(3 if args.operation == 'matmul' else 4,
                                  x._handle, y._handle, C.byref(out))
    assert status == 0
    assert lib.frumpy_release(out.value) == 0

def public():
    if args.operation == 'add':
        (x + y).close()
    elif args.operation == 'matmul':
        (x @ y).close()
    else:
        fp.linalg.solve(x, y).close()

report = {}
for name, call in [(f'C ABI {args.operation}/release', raw), (f'Python {args.operation}/close', public)]:
    for _ in range(100):
        call()
    probe.frumpy_measure_start()
    for _ in range(1000):
        call()
    probe.frumpy_measure_stop()
    report[name] = dict(calls_per_operation=probe.frumpy_measure_calls()/1000,
                       requested_bytes_per_operation=probe.frumpy_measure_bytes()/1000)
print(json.dumps(report, indent=2))
