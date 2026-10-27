"""Warmed native/Python arithmetic and small-call ABI layers; no setup/export in timings."""
import argparse
import ctypes as C
import hashlib
import json
import os
from pathlib import Path
import statistics
import subprocess
from compare_sort import timed
import numpy as np
import frumpy as fp
from frumpy import _ffi


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--driver', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--label', required=True)
    args = parser.parse_args()
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    report = dict(label=args.label, affinity=sorted(os.sched_getaffinity(0)), threads=1,
                  compiler=subprocess.check_output([str(args.driver), '--version'], text=True).strip(),
                  library_sha256=hashlib.sha256(Path(os.environ['FRUMPY_LIBRARY']).read_bytes()).hexdigest(),
                  wrapper_sha256=hashlib.sha256(Path(fp.__file__).with_name('_array.py').read_bytes()).hexdigest(),
                  method='Seven warmed samples; one CPU/thread; allocating calls and release timed. '
                         'Native baseline plus C ABI and Python measurements are distinct entry points.',
                  native=[], python=[], layers=[])
    for n in (16, 1024, 1048576):
        for layout in ('contiguous', 'stride2', 'reverse', 'broadcast'):
            def run(iterations, samples):
                values = [float(v) for v in subprocess.check_output([str(args.driver), 'add_r64',
                    layout, str(n), str(iterations), str(samples)], text=True).split()]
                return values[1:]
            iterations = max(1, min(10000, int(.03/max(statistics.median(run(1, 3)), 1e-9))))
            samples = run(iterations, 7)
            report['native'].append(dict(size=n, layout=layout, seconds=samples,
                                         median_seconds=statistics.median(samples), iterations=iterations))
            for dtype in (np.float32, np.float64):
                data = (np.arange(n * (2 if layout == 'stride2' else 1)) % 127 + 1).astype(dtype)
                owner = fp.asarray(data)
                a, fa = data, owner
                if layout == 'stride2':
                    a, fa = data[::2], owner[::2]
                elif layout == 'reverse':
                    a, fa = data[::-1], owner[::-1]
                b = np.array(2, dtype=dtype) if layout == 'broadcast' else np.full(n, 2, dtype=dtype)
                fb = fp.asarray(b)
                with fa + fb as actual:
                    np.testing.assert_array_equal(actual.numpy(), a+b)
                def call(): (fa+fb).close()
                report['python'].append(dict(size=n, layout=layout, dtype=np.dtype(dtype).name,
                    frumpy=timed(call, 7), numpy=timed(lambda: a+b, 7)))
                fa.close(); fb.close(); owner.close()
    x, y = fp.asarray(np.arange(16.)), fp.asarray(np.ones(16))
    lib, out = _ffi.library(), _ffi.H()
    def abi():
        assert lib.frumpy_binary(1, x._handle, y._handle, C.byref(out)) == 0
        assert lib.frumpy_release(out.value) == 0
    def wrapper():
        handle = _ffi.make('binary', 1, x._handle, y._handle)
        _ffi.call('release', handle)
    def public(): (x+y).close()
    for name, call in [('raw C ABI via ctypes', abi), ('checked FFI without ndarray metadata', wrapper),
                       ('public Python ndarray', public)]:
        report['layers'].append(dict(name=name, **timed(call, 7)))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2)+'\n')


if __name__ == '__main__':
    main()
