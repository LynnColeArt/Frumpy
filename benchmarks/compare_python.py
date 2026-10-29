"""Measure allocating public Python calls; imports/export/setup are untimed."""
import argparse
import datetime
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import time

for name in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ[name] = "1"

import numpy as np
import frumpy as fp


def cases():
    for size in (1024, 1048576):
        for layout in ("contiguous", "reverse", "stride2", "broadcast"):
            yield "add", layout, size
        for layout in ("contiguous", "stride2"):
            yield "sum", layout, size
    for size in (1024, 8192):
        yield "sort", "contiguous", size
    yield "matmul", "contiguous", 128
    yield "solve", "contiguous", 64


def operands(operation, layout, size):
    if operation in ("matmul", "solve"):
        a = np.arange(size * size, dtype=np.float64).reshape(size, size) % 17 / 17
        if operation == "solve":
            a += np.eye(size) * size
        b = np.ones((size, size), dtype=np.float64)
        return a, b, fp.asarray(a), fp.asarray(b)
    step = 2 if layout == "stride2" else 1
    backing = ((37 * np.arange(1, size * step + 1, dtype=np.int64)) % size).astype(np.float64)
    backing /= size
    native = fp.asarray(backing)
    a = backing[::step]
    fa = native[::step]
    if layout == "reverse":
        a, fa = a[::-1], fa[::-1]
    b = np.array(2.) if layout == "broadcast" else np.full(size, 2.)
    return a, b, fa, fp.asarray(b)


def measure(call, native, samples):
    def once():
        result = call()
        if native:
            result.close()
    once()
    started = time.perf_counter()
    once()
    elapsed = time.perf_counter() - started
    iterations = max(1, min(1000, int(.04 / max(elapsed, 1e-9))))
    timings = []
    for _ in range(samples):
        started = time.perf_counter()
        for _ in range(iterations):
            once()
        timings.append((time.perf_counter() - started) / iterations)
    return {"iterations": iterations, "seconds": timings,
            "median_seconds": statistics.median(timings), "min_seconds": min(timings),
            "max_seconds": max(timings)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--samples", type=int, default=7)
    args = parser.parse_args()
    if args.samples < 3:
        parser.error("at least three samples are required")
    if hasattr(os, "sched_getaffinity"):
        os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    report = {
        "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "platform": platform.platform(), "python": platform.python_version(),
        "numpy": np.__version__, "frumpy": fp.__version__,
        "git_head": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
        "git_dirty": bool(subprocess.check_output(["git", "status", "--porcelain"])),
        "library": os.environ.get("FRUMPY_LIBRARY", "installed package"),
        "numpy_build": np.show_config(mode="dicts"),
        "cpu": next(line.split(":", 1)[1].strip() for line in
                    Path("/proc/cpuinfo").read_text().splitlines() if line.startswith("model name")),
        "threads": {name: os.environ[name] for name in
                    ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS")},
        "affinity": sorted(os.sched_getaffinity(0)),
        "method": "One CPU, warmed calls; native dispatch, result/metadata allocation and release timed; "
                  "input imports, setup, exports and correctness checks excluded; no out/reuse API.",
        "allocation_scope": "Each iteration creates and releases one owned result payload. Native "
                            "descriptor/scratch and Python metadata allocations are included in time, "
                            "not individually counted. Matmul/solve also allocate packing/work buffers.",
        "results": [],
    }
    for operation, layout, size in cases():
        a, b, fa, fb = operands(operation, layout, size)
        if operation == "add":
            native, oracle = lambda: fa + fb, lambda: a + b
        elif operation == "sum":
            native, oracle = lambda: fa.sum(), lambda: a.sum()
        elif operation == "sort":
            native, oracle = lambda: fp.sort(fa), lambda: np.sort(a, kind="stable")
        elif operation == "matmul":
            native, oracle = lambda: fa @ fb, lambda: a @ b
        else:
            native, oracle = lambda: fp.linalg.solve(fa, fb), lambda: np.linalg.solve(a, b)
        with native() as check:
            np.testing.assert_allclose(check.numpy(), oracle(), rtol=2e-12, atol=2e-12)
            output_bytes = check.size * check.dtype.itemsize
        native_time, numpy_time = measure(native, True, args.samples), measure(oracle, False, args.samples)
        report["results"].append({"operation": operation, "layout": layout, "size": size,
                                  "dtype": str(a.dtype), "shape": a.shape, "strides_bytes": a.strides,
                                  "result_payload_bytes_per_call": output_bytes,
                                  "frumpy": native_time, "numpy": numpy_time,
                                  "ratio": native_time["median_seconds"] / numpy_time["median_seconds"]})
        fa.close()
        fb.close()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
