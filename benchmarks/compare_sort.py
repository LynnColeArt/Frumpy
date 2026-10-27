"""Controlled native/Python stable-sort benchmark; repeat with before/after libraries."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import time

for name in ('OMP_NUM_THREADS', 'OPENBLAS_NUM_THREADS', 'MKL_NUM_THREADS'):
    os.environ[name] = '1'

import numpy as np
import frumpy as fp


def timed(call, samples):
    call()
    start = time.perf_counter()
    call()
    iterations = max(1, min(1000, int(.03 / max(time.perf_counter() - start, 1e-9))))
    times = []
    for _ in range(samples):
        start = time.perf_counter()
        for _ in range(iterations):
            call()
        times.append((time.perf_counter() - start) / iterations)
    return {'iterations': iterations, 'seconds': times, 'median_seconds': statistics.median(times)}


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
    report = {'label': args.label, 'platform': platform.platform(), 'numpy': np.__version__,
              'source_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
              'source_dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'])),
              'library_sha256': hashlib.sha256(library.read_bytes()).hexdigest(),
              'driver_sha256': hashlib.sha256(args.driver.read_bytes()).hexdigest(),
              'compiler': subprocess.check_output([str(args.driver), '--version'], text=True).strip(),
              'affinity': sorted(os.sched_getaffinity(0)), 'threads': 1,
              'method': 'Warmed allocating calls, including release; setup/export excluded; '
                        'seven samples, single CPU. Python wrapper held constant across kernel comparison.',
              'native': [], 'python': []}
    for size in (32, 1024, 8192, 32768):
        def run(iterations, samples):
            result = subprocess.check_output([str(args.driver), 'sort_r64', 'contiguous',
                                               str(size), str(iterations), str(samples)], text=True)
            values = [float(x) for x in result.split()]
            np.testing.assert_allclose(values[0], (size - 1) / 2, rtol=1e-12)
            return values[1:]
        estimate = statistics.median(run(1, 3))
        iterations = max(1, min(10000, int(.03 / max(estimate, 1e-9))))
        samples = run(iterations, args.samples)
        report['native'].append({'size': size, 'iterations': iterations, 'seconds': samples,
                                 'median_seconds': statistics.median(samples)})
    for size, layout in [(32,'permutation'),(1024,'permutation'),(8192,'permutation'),
                         (32768,'permutation'),(8192,'sorted'),(8192,'reverse'),(8192,'stride2')]:
        step = 2 if layout == 'stride2' else 1
        data = ((37 * np.arange(1, size * step + 1)) % (size * step)).astype(np.float64)
        data /= size * step
        if layout in ('sorted', 'reverse'):
            data = np.sort(data)
        source = fp.asarray(data)
        if layout == 'stride2':
            source, data = source[::2], data[::2]
        elif layout == 'reverse':
            source, data = source[::-1], data[::-1]
        for operation in ('sort', 'argsort'):
            native, oracle = getattr(fp, operation), getattr(np, operation)
            with native(source) as actual:
                np.testing.assert_array_equal(actual.numpy(), oracle(data, kind='stable'))
            def call():
                native(source).close()
            native_time = timed(call, args.samples)
            numpy_time = timed(lambda: oracle(data, kind='stable'), args.samples)
            report['python'].append({'operation': operation, 'size': size, 'layout': layout,
                                      'frumpy': native_time, 'numpy': numpy_time})
        source.close()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
