"""Compare allocating arithmetic/reductions using frozen before/after native builds."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess

from compare_sort import timed  # Sets single-thread policy before NumPy is imported.
import numpy as np
import frumpy as fp
from compare_numpy import cases, numpy_case


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--driver', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--label', required=True)
    parser.add_argument('--samples', type=int, default=7)
    args = parser.parse_args()
    if args.samples < 3:
        parser.error('at least three samples required')
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    library = Path(os.environ['FRUMPY_LIBRARY'])
    report = dict(label=args.label, platform=platform.platform(), numpy=np.__version__,
                  source_head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
                  source_dirty=bool(subprocess.check_output(['git', 'status', '--porcelain'])),
                  library_sha256=hashlib.sha256(library.read_bytes()).hexdigest(),
                  driver_sha256=hashlib.sha256(args.driver.read_bytes()).hexdigest(),
                  compiler=subprocess.check_output([str(args.driver), '--version'], text=True).strip(),
                  affinity=sorted(os.sched_getaffinity(0)), threads=1,
                  method='Warmed allocating calls including release; setup/export excluded. '
                         'No fast-math. Same Python wrapper and harness for both libraries. '
                         'All sample times retained; metadata allocations included but not counted.',
                  native=[], python=[])
    for operation, layout, size in cases():
        if operation == 'sort_r64':
            continue
        oracle = numpy_case(operation, layout, size)
        expected = float(np.sum(oracle(), dtype=np.float64))
        def run(iterations, samples):
            values = [float(x) for x in subprocess.check_output(
                [str(args.driver), operation, layout, str(size), str(iterations), str(samples)],
                text=True).split()]
            np.testing.assert_allclose(values[0], expected, rtol=2e-12)
            return values[1:]
        estimate = statistics.median(run(1, 3))
        iterations = max(1, min(10000, int(.03 / max(estimate, 1e-9))))
        samples = run(iterations, args.samples)
        report['native'].append(dict(operation=operation, layout=layout, size=size,
                                     iterations=iterations, seconds=samples,
                                     median_seconds=statistics.median(samples),
                                     numpy=timed(oracle, args.samples)))
    for dtype in (np.float32, np.float64):
        for size in (1024, 1048576):
            for layout in ('contiguous', 'broadcast', 'stride2', 'axis'):
                data = (np.arange(size * (2 if layout == 'stride2' else 1)) % 127 + 1).astype(dtype)
                data /= 128
                owner = fp.asarray(data)
                a, fa = data, owner
                if layout == 'stride2':
                    a, fa = data[::2], owner[::2]
                elif layout == 'axis':
                    a, fa = data.reshape(-1, 128), owner.reshape(-1, 128)
                b = np.array(2, dtype=dtype) if layout == 'broadcast' else np.full(a.shape, 2, dtype=dtype)
                fb = fp.asarray(b)
                operations = ('sum', 'mean') if layout == 'axis' else ('add', 'subtract', 'multiply', 'divide', 'sum', 'mean')
                for operation in operations:
                    if operation in ('sum', 'mean'):
                        if layout == 'broadcast':
                            continue
                        axis = -1 if layout == 'axis' else None
                        native = lambda: getattr(fa, operation)(axis=axis)
                        oracle = lambda: getattr(a, operation)(axis=axis)
                    else:
                        native = lambda: getattr(fp, operation)(fa, fb)
                        oracle = lambda: getattr(np, operation)(a, b)
                    with native() as result:
                        np.testing.assert_allclose(result.numpy(), oracle(), rtol=2e-6, atol=2e-6)
                        payload = result.size * result.dtype.itemsize
                    def call():
                        native().close()
                    report['python'].append(dict(operation=operation, dtype=np.dtype(dtype).name,
                        size=size, layout=layout, result_payload_bytes=payload,
                        frumpy=timed(call, args.samples), numpy=timed(oracle, args.samples)))
                fa.close()
                fb.close()
                owner.close()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
