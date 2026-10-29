# Masking public-API baseline

This is an initial functionality baseline, not an optimization or speedup claim.
`python.json` records same-dtype extraction, masked scalar assignment and basic
scalar assignment across all five dtypes, at 16 and 65,536 elements, with contiguous
and stride-two views. Masks select half the elements. Inputs are imported before
timing; Frumpy extraction includes releasing the result. Each number is the median
of seven samples of five calls after a warm-up call. NumPy uses matching stepped
views. Python dispatch, allocation and native work are all included.

Local Linux x86-64, Python 3.12.3, NumPy 2.4.6, GNU Fortran 13 optimized
(`-std=f2018 -O3 -fimplicit-none`). BLAS does not participate in these operations.
Other validation processes were active; these measurements establish scale and
are not controlled regression thresholds.

At 65,536 elements across dtypes and layouts:

| Operation | Frumpy microseconds | NumPy microseconds |
| --- | ---: | ---: |
| Extraction | 814–1,226 | 152–234 |
| Masked scalar assignment | 944–1,130 | 117–229 |
| Basic scalar assignment | 824–910 | 1–30 |

General logical traversal and staged writes prioritize correctness. NumPy's
scalar fills are much faster; this is a candidate for a later measured fast path.
Frumpy's unconditional overlap snapshots are a stronger guarantee than NumPy's
boolean assignment on aliased inputs. This baseline uses non-overlapping inputs
on both sides and does not measure overlap-specific behavior.

Reproduce against an optimized shared library:

```sh
PYTHONPATH=python FRUMPY_LIBRARY=/absolute/path/libfrumpy.so \
  .venv/bin/python benchmarks/compare_masking.py > masking.json
```
