"""Focused allocating-call recheck; optional probe_linalg.c backend phase timing."""
import argparse
import ctypes as C
import hashlib
import json
import os
from pathlib import Path
import time

for variable in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ[variable] = "1"

import numpy as np
import frumpy as fp


def timed(call, backend_counter=None, probe=None):
    for _ in range(3):
        call()
    samples, backend = [], []
    for _ in range(9):
        if probe is not None:
            probe.frumpy_probe_reset()
        start = time.process_time()
        for _ in range(15):
            call()
        samples.append((time.process_time() - start) / 15)
        if backend_counter is not None:
            backend.append(backend_counter() / 15)
    return dict(cpu_seconds=samples, backend_cpu_seconds=backend)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("label")
    args = parser.parse_args()
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    probe = C.CDLL(os.environ["FRUMPY_PROBE"]) if "FRUMPY_PROBE" in os.environ else None
    if probe is not None:
        for name in ("frumpy_probe_gemm", "frumpy_probe_gesv"):
            getattr(probe, name).restype = C.c_double
            getattr(probe, name).argtypes = []
        probe.frumpy_probe_reset.restype = None
        probe.frumpy_probe_reset.argtypes = []
    rows = []
    for operation, n in [("matmul", 512), ("solve", 128), ("matmul", 16)]:
        a = (np.arange(n*n).reshape(n, n) % 17).astype(float) / 17
        b = np.ones((n, n))
        if operation == "solve":
            a += np.eye(n)*n
        owner = None
        if operation == "matmul" and n == 512:
            backing = np.zeros((n, n*2))
            backing[:, ::2] = a
            owner = fp.asarray(backing)
            fa = owner[:, ::2]
        else:
            fa = fp.asarray(a)
        fb = fp.asarray(b)
        if operation == "matmul":
            def call():
                (fa @ fb).close()
            result, expected = fa @ fb, a @ b
            counter = probe.frumpy_probe_gemm if probe is not None else None
        else:
            def call():
                fp.linalg.solve(fa, fb).close()
            result, expected = fp.linalg.solve(fa, fb), np.linalg.solve(a, b)
            counter = probe.frumpy_probe_gesv if probe is not None else None
        with result:
            np.testing.assert_allclose(result.numpy(), expected, rtol=2e-12, atol=2e-12)
        rows.append(dict(operation=operation, size=n, **timed(call, counter, probe)))
        fa.close()
        fb.close()
        if owner is not None:
            owner.close()
    library = Path(os.environ["FRUMPY_LIBRARY"])
    print(json.dumps(dict(label=args.label, library=str(library),
                          library_sha256=hashlib.sha256(library.read_bytes()).hexdigest(),
                          affinity=sorted(os.sched_getaffinity(0)), threads=1, rows=rows)))


if __name__ == "__main__":
    main()
