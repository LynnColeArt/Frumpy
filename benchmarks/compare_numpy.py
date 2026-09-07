"""Compare allocating Frumpy/NumPy API calls; process launch and input setup are untimed."""

import argparse
import datetime
import json
import math
import os
from pathlib import Path
import platform
import statistics
import subprocess
import time

# Apply before importing NumPy; these kernels do not call BLAS, but record thread policy.
for name in ('OMP_NUM_THREADS', 'OPENBLAS_NUM_THREADS', 'MKL_NUM_THREADS'):
    os.environ[name] = '1'

import numpy as np


def cases():
    for count in (1024, 1048576):
        for layout in ('contiguous', 'reverse', 'stride2', 'broadcast'):
            yield 'add_r64', layout, count
        yield 'add_r32', 'contiguous', count
        for layout in ('contiguous', 'stride2'):
            yield 'sum_r64', layout, count
    for count in (1024, 8192):
        yield 'sort_r64', 'contiguous', count


def numpy_case(operation, layout, count):
    step = 2 if layout == 'stride2' else 1
    dtype = np.float32 if operation == 'add_r32' else np.float64
    backing = ((37 * np.arange(1, count * step + 1, dtype=np.int64)) % count).astype(dtype)
    backing /= count
    lhs = backing[::step]
    if layout == 'reverse':
        lhs = lhs[::-1]
    rhs = np.array(2, dtype=dtype) if layout == 'broadcast' else np.full(count, 2, dtype=dtype)
    if operation.startswith('add_'):
        return lambda: np.add(lhs, rhs)
    if operation == 'sum_r64':
        return lambda: np.sum(lhs)
    return lambda: np.sort(lhs, kind='stable')


def summarize(times):
    return {'seconds': times, 'median_seconds': statistics.median(times),
            'min_seconds': min(times), 'max_seconds': max(times)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--driver', action='append', required=True, help='LABEL=/path/to/binary')
    parser.add_argument('--output', type=Path, required=True, help='JSON result file')
    parser.add_argument('--samples', type=int, default=7)
    args = parser.parse_args()
    if args.samples < 3:
        parser.error('use at least three samples')
    if hasattr(os, 'sched_getaffinity'):
        os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    drivers = {}
    for entry in args.driver:
        label, path = entry.split('=', 1)
        drivers[label] = str(Path(path).resolve())
    root = Path(__file__).resolve().parents[1]
    versions = {label: subprocess.check_output([path, '--version'], text=True).strip()
                for label, path in drivers.items()}
    cpu = platform.processor()
    if Path('/proc/cpuinfo').exists():
        cpu = next(line.split(':', 1)[1].strip() for line in Path('/proc/cpuinfo').read_text().splitlines()
                   if line.startswith('model name'))
    report = {'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'platform': platform.platform(), 'cpu': cpu, 'numpy': np.__version__,
              'python': platform.python_version(), 'compilers': versions,
              'affinity': sorted(os.sched_getaffinity(0)) if hasattr(os, 'sched_getaffinity') else None,
              'git_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
              'git_dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=root)),
              'method': 'Single CPU; warmed inputs; allocation/call/release timed; setup/checks untimed; '
                        'median of batch means calibrated per backend to about 20 ms; no process startup in timing; no fast-math.',
              'rows': []}
    for operation, layout, count in cases():
        iterations = 1 if operation == 'sort_r64' else (100 if count == 1024 else 3)
        call = numpy_case(operation, layout, count)
        warm = call()
        checksum = float(np.sum(warm, dtype=np.float64))
        del warm
        def numpy_samples(repetitions, samples):
            times = []
            for _ in range(samples):
                start = time.perf_counter()
                for _ in range(repetitions):
                    result = call()
                    del result
                times.append((time.perf_counter() - start) / repetitions)
            return times

        estimate = statistics.median(numpy_samples(iterations, 3))
        numpy_iterations = min(100000, max(1, math.ceil(0.02 / estimate)))
        times = numpy_samples(numpy_iterations, args.samples)
        row = {'operation': operation, 'layout': layout, 'count': count,
               'iterations': {'numpy': numpy_iterations}, 'checksum': checksum, 'numpy': summarize(times), 'frumpy': {}}
        for label, path in drivers.items():
            def run_driver(repetitions, samples):
                run = subprocess.run([path, operation, layout, str(count), str(repetitions), str(samples)],
                                     check=True, capture_output=True, text=True, timeout=120)
                values = [float(value) for value in run.stdout.split()]
                assert len(values) == samples + 1, run.stdout
                np.testing.assert_allclose(values[0], checksum, rtol=1e-12, atol=1e-12)
                return values

            estimate = statistics.median(run_driver(iterations, 3)[1:])
            repetitions = min(100000, max(1, math.ceil(0.02 / estimate)))
            values = run_driver(repetitions, args.samples)
            row['iterations'][label] = repetitions
            timing = summarize(values[1:])
            timing['ratio_to_numpy'] = timing['median_seconds'] / row['numpy']['median_seconds']
            row['frumpy'][label] = timing
        report['rows'].append(row)
        print(f'{operation} {layout} {count}: ' + ', '.join(
            f'{label} {timing["ratio_to_numpy"]:.1f}x NumPy time' for label, timing in row['frumpy'].items()),
            flush=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    headers = ['Operation / layout', 'Elements', 'NumPy (ms)'] + [f'{label} (ms / NumPy ratio)' for label in drivers]
    lines = ['# Frumpy / NumPy timing', '', report['method'], '',
             f'Host: {cpu}. NumPy {np.__version__}.', '',
             '| ' + ' | '.join(headers) + ' |', '| ' + ' | '.join(['---'] * len(headers)) + ' |']
    for row in report['rows']:
        cells = [f'{row["operation"]} / {row["layout"]}', f'{row["count"]:,}',
                 f'{row["numpy"]["median_seconds"] * 1000:.4f}']
        cells += [f'{timing["median_seconds"] * 1000:.4f} / {timing["ratio_to_numpy"]:.1f}×'
                  for timing in row['frumpy'].values()]
        lines.append('| ' + ' | '.join(cells) + ' |')
    lines += ['', 'A ratio above 1 means Frumpy took longer. These are this host’s warmed, allocating '
              'API calls, not universal speed claims. Raw samples and compiler flags are in the JSON file.']
    args.output.with_suffix('.md').write_text('\n'.join(lines) + '\n')


if __name__ == '__main__':
    main()
