# Stable sorting: before and after — 2026-10-27

Before kernel: v0.1 source `3e1a191` (unchanged through `7584780`). After:
`61a6bba`. Both Python measurements use the same wrapper, including the two
correctness fixes, to isolate the sorting change. The raw source_head field
identifies the benchmark/wrapper checkout; library and driver SHA-256 hashes
identify the separately built kernels. All four measured checkouts were clean.

GNU 14, `-std=f2018 -O3 -fimplicit-none`, no fast-math; AMD Ryzen 5 5600X;
NumPy 2.4.6. Two sequential before/after pairs, each with seven warmed samples,
single-CPU affinity and thread settings fixed at one. No Frumpy build/test
jobs ran during timing. Calls allocate and release their results; input setup
and exports are excluded. The host was not otherwise dedicated to benchmarking.

**Timing variability was substantial, sometimes around 2× between runs.**
Tables show the range of the two run medians. The conservative gain divides
the fastest old median by the slowest new median; it is an observed comparison,
not a statistical confidence bound or a portable speed guarantee.

## Native sort

| Elements | Before (ms) | After (ms) | Conservative gain |
| ---: | ---: | ---: | ---: |
| 32 | 0.0012–0.0023 | 0.0013–0.0023 | 0.5× |
| 1,024 | 0.1712–0.3544 | 0.0200–0.0414 | 4.1× |
| 8,192 | 10.7848–18.8810 | 0.2255–0.3843 | 28.1× |
| 32,768 | 162.8926–291.6804 | 1.0056–1.6383 | 99.4× |

## Python sort and argsort

| Operation / layout | Elements | Before (ms) | After (ms) | Conservative gain |
| --- | ---: | ---: | ---: | ---: |
| sort / permutation | 32 | 0.0157–0.0380 | 0.0192–0.0316 | 0.5× |
| argsort / permutation | 32 | 0.0156–0.0344 | 0.0166–0.0339 | 0.5× |
| sort / permutation | 1,024 | 0.1879–0.3667 | 0.0429–0.0502 | 3.7× |
| argsort / permutation | 1,024 | 0.1913–0.3915 | 0.0420–0.0866 | 2.2× |
| sort / permutation | 8,192 | 9.7265–19.5371 | 0.1934–0.3532 | 27.5× |
| argsort / permutation | 8,192 | 18.3519–18.3630 | 0.1800–0.3966 | 46.3× |
| sort / permutation | 32,768 | 292.7540–323.1796 | 0.7051–0.7681 | 381.1× |
| argsort / permutation | 32,768 | 157.9473–235.7710 | 0.6124–0.6209 | 254.4× |
| sort / sorted | 8,192 | 0.0572–0.0578 | 0.0572–0.0659 | 0.9× |
| argsort / sorted | 8,192 | 0.0669–0.1336 | 0.0575–0.0678 | 1.0× |
| sort / reverse | 8,192 | 24.6496–37.4028 | 0.2460–0.2754 | 89.5× |
| argsort / reverse | 8,192 | 26.4385–36.9464 | 0.2875–0.5317 | 49.7× |
| sort / stride2 | 8,192 | 9.9067–20.1263 | 0.1656–0.3921 | 25.3× |
| argsort / stride2 | 8,192 | 10.1577–18.4938 | 0.1891–0.3638 | 27.9× |

A gain below one indicates the conservative comparison includes a slowdown.
Tiny-input ranges overlap substantially. Already-sorted sort was essentially
unchanged in one pair and about 15% slower in the other; no improvement is
claimed for that case. Larger unsorted inputs improve decisively in both runs.

## Implementation and memory tradeoff

Both sort and argsort use stable bottom-up merges with insertion runs up to
32 elements. Ordered adjacent runs skip merging. Merge buffers are allocated
lazily on the first required merge and reused across all axis slices. Worst-case
work changes from quadratic to O(n log n). Extra merge workspace is 16 bytes
per axis element: 128 KiB at 8,192 elements and 512 KiB at 32,768. The existing
gather buffers and result allocation remain. Small/ordered slices do not allocate
merge buffers unless another slice in the same call requires them.

Regression tests preserve exact argsort stability, signed zeros, distinct NaN
payloads, infinities, C/F/reversed/stepped/transposed layouts, merge boundaries,
empties and input preservation. Both scalar-axis truncation and mutable flag
regressions are fixed. Six compiler configurations pass 35 native programs,
two examples, 2,839 Python tests and the C caller. GNU 14 memory/overflow gates
pass; 168 ABI/package tests also pass under ASan and UBSan. See
[validation evidence](../../validation/sort-2026-10-27.json).

## Reproduce

Build the before and after revisions with the same release flags in separate
directories. Keep the Python wrapper and benchmark script constant, then run
each pair sequentially, replacing LIBRARY and DRIVER with the corresponding
absolute paths:

```sh
PYTHONPATH=python FRUMPY_LIBRARY=LIBRARY .venv/bin/python benchmarks/compare_sort.py \
  --driver DRIVER --label before --samples 7 --output before.json
```

Repeat with the after library/driver and an after label/output. Raw data:
[before 1](before-1.json), [after 1](after-1.json),
[before 2](before-2.json), [after 2](after-2.json).
The raw reports include individual samples, calibration iteration counts,
NumPy controls, compiler options, affinity and binary hashes.
