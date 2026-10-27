"""Measure handle lookup as the number of live arrays grows; creation/cleanup are untimed."""
import argparse
import ctypes as C
import hashlib
import json
import os
from pathlib import Path
from compare_sort import timed
import numpy as np
import frumpy as fp
from frumpy import _ffi

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
report = dict(library_sha256=hashlib.sha256(Path(os.environ['FRUMPY_LIBRARY']).read_bytes()).hexdigest(),
              affinity=sorted(os.sched_getaffinity(0)), threads=1, rows=[])
for count in (0, 64, 1024, 8192):
    x, y = fp.asarray(np.arange(16.)), fp.asarray(np.ones(16))
    fillers = [fp.zeros(()) for _ in range(count)]
    with x+y as result: np.testing.assert_array_equal(result.numpy(), np.arange(16.)+1)
    lib, out = _ffi.library(), _ffi.H()
    def raw():
        assert lib.frumpy_binary(1, x._handle, y._handle, C.byref(out)) == 0
        assert lib.frumpy_release(out.value) == 0
    def public(): (x+y).close()
    def retain():
        assert lib.frumpy_retain(x._handle) == 0
        assert lib.frumpy_release(x._handle) == 0
    report['rows'].append(dict(other_live_arrays=count, raw=timed(raw,7),
                              public=timed(public,7), retain_release=timed(retain,7)))
    for filler in reversed(fillers): filler.close()
    y.close(); x.close()
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report,indent=2)+'\n')
