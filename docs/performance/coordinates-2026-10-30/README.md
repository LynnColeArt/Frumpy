# Coordinate extraction baseline — 2026-10-30

This is an initial public Python API baseline, not a before/after optimization
claim. `python.json` records 60 cases across all five dtypes, C/F/stepped layouts,
16 and 65,536 elements, and both coordinate operations. Inputs are preimported;
Frumpy results are explicitly closed inside each timed call. Seven sample
medians use 100 iterations for small arrays and five for large arrays, pinned to
CPU 0. NumPy is 2.4.6; the library hash is recorded in the data.

| Elements | Operation | Frumpy microseconds | Frumpy / NumPy time |
| --- | --- | --- | --- |
| 16 | nonzero | 13.1–22.0 | 25.9–45.4× |
| 16 | argwhere | 9.1–10.3 | 3.9–5.1× |
| 65,536 | nonzero | 700–1,231 | 3.8–29.9× |
| 65,536 | argwhere | 686–1,206 | 3.5–20.4× |

These results establish a correctness-first baseline with substantial remaining
NumPy gaps. The current kernel scans twice and uses generic logical traversal;
nonzero additionally wraps one handle per axis. These are candidate costs, not
profiled causal conclusions. Native and C correctness are validated separately;
this dataset does not measure their call overhead independently.

Reproduce with an optimized shared library:

```sh
PYTHONPATH=python FRUMPY_LIBRARY=/absolute/path/libfrumpy.so \
  .venv/bin/python benchmarks/compare_coordinates.py --output /tmp/coordinates.json
```
