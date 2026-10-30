# Nonzero and argwhere validation — 2026-10-30

The slice adds native, C, and Python coordinate extraction for bool, int32,
int64, float32, and float64. Coordinates are zero-based int64 in C logical
order. NumPy 2.4.6 is the oracle. See [contracts](../COORDINATES.md).

Scalar nonzero fails; scalar argwhere returns (0,0) or (1,0). Empty rank-R
inputs produce R empty nonzero vectors or argwhere shape (0,R). Signed zeros,
NaNs, infinities, irregular layouts, rank 32, independent output lifetimes,
and partial C tuple publication rollback are covered.

## Local results

- GNU 14 full validation: 44 native programs and 8,596 Python tests passed.
- GNU 13 and GNU 14 debug and optimized compiler matrix: all four passed.
- Native ASan/leak checks, including the coordinate program: passed.
- Sanitized differential suite: 2,647 passed.
- Integer overflow suite: 2,159 passed, 488 deselected.
- C ownership ASan caller and C/Python ASan suite: passed; latter 5,921 tests.
  Python-process leak detection is disabled; native leak detection is enabled.
- Focused UBSan/overflow coordinate suite: 303 passed.
- Registry allocation injection: second coordinate handle allocation fails,
  all outputs clear, published handle is invalidated, subsequent retry succeeds.
- Fresh source archive installation outside the repository: 401 package tests
  passed with library/path overrides removed.
- Additional review: 500 seeded randomized NumPy comparisons across five dtypes,
  ranks 0–5, empty dimensions, F owners and reversed views passed.
- `git diff --check`: clean.

The initial Python timing baseline is in
[the performance report](../performance/coordinates-2026-10-30/README.md).
No fresh macOS run was performed. Hosted compiler and sanitizer checks are
required before merging; their authoritative results are attached to the PR.
