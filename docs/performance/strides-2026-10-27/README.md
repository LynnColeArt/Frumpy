# Uniform strides and small-call costs — 2026-10-27

Before: `b86c6d4`, using its existing GNU 14 release library (core `1d83bc3`)
and frozen Python package. After: `f8882d5`, including native and Python changes.
Library and wrapper SHA-256 hashes are recorded in every raw report. Native
measurements isolate the core; public Python results include both changes.

GNU 14 `-std=f2018 -O3 -fimplicit-none`, AMD Ryzen 5 5600X, NumPy 2.4.6;
no fast-math, one CPU and one thread. Two pairs of seven warmed samples:
before→after, then after→before. No Frumpy builds/tests ran during measurement.
Input creation and exports are excluded; result allocation and release are timed.
The host was not otherwise dedicated to benchmarks. Tables show ranges of run
medians, and fastest-before / slowest-after as a conservative observed ratio,
not a statistical bound or portable speed promise.

## Changes

1. Detect a constant signed element step across C-logical traversal from actual
   broadcast shape/strides. The existing floating arithmetic loops now also handle
   uniform positive steps and reversed arrays, including compatible multidimensional
   views and scalar broadcasts. Singleton strides are ignored. Arithmetic on
   nonuniform views, row broadcasts and cross-dtype operands keeps its fallback.
   Detection guards signed stride multiplication, including minimum-int input.
   Input bounds are still validated before the linear kernel reads storage.
2. Allocate the general index vector only when traversal needs it. Same-dtype
   float32/float64 linear operations avoid this allocation. Promoted integer
   division still needs the general path and its index vector.
3. Python result metadata uses local ctypes buffers instead of temporary NumPy
   arrays and their ctypes adapters. Shape values are already Python integers;
   strides use the resolved dtype item size. Ownership, finalizers, immutable
   flags, locking and native metadata queries are unchanged. No caches, reused
   mutable buffers, packing copies or new numerical algorithms are introduced.

## Native allocating float64 addition

| Case | Before (µs) | After (µs) | Conservative gain |
| --- | ---: | ---: | ---: |
| 16 / float64 / contiguous | 1.08–1.10 | 1.16–1.17 | 0.92× |
| 16 / float64 / stride2 | 1.40–1.74 | 1.07–1.28 | 1.09× |
| 16 / float64 / reverse | 1.29–1.98 | 1.10–1.21 | 1.07× |
| 16 / float64 / broadcast | 1.15–1.77 | 1.04–1.07 | 1.07× |
| 1,024 / float64 / contiguous | 2.03–2.14 | 1.50–1.61 | 1.26× |
| 1,024 / float64 / stride2 | 12.81–14.89 | 1.58–1.67 | 7.67× |
| 1,024 / float64 / reverse | 13.22–15.76 | 1.52–1.58 | 8.37× |
| 1,024 / float64 / broadcast | 2.09–2.74 | 1.40–1.51 | 1.38× |
| 1,048,576 / float64 / contiguous | 665.95–780.37 | 579.01–626.01 | 1.06× |
| 1,048,576 / float64 / stride2 | 10402.27–10660.74 | 940.08–950.37 | 10.95× |
| 1,048,576 / float64 / reverse | 10504.93–10685.41 | 650.70–682.60 | 15.39× |
| 1,048,576 / float64 / broadcast | 434.06–475.73 | 364.55–418.72 | 1.04× |

## Public Python allocating addition

| Case | Before (µs) | After (µs) | Conservative gain |
| --- | ---: | ---: | ---: |
| 16 / float32 / contiguous | 18.17–18.41 | 11.99–12.10 | 1.50× |
| 16 / float64 / contiguous | 16.65–16.93 | 12.52–12.87 | 1.29× |
| 16 / float32 / stride2 | 18.09–25.39 | 11.58–13.08 | 1.38× |
| 16 / float64 / stride2 | 19.91–25.33 | 11.29–12.86 | 1.55× |
| 16 / float32 / reverse | 18.55–25.26 | 10.99–12.09 | 1.53× |
| 16 / float64 / reverse | 19.08–28.54 | 11.55–12.09 | 1.58× |
| 16 / float32 / broadcast | 25.13–28.12 | 11.45–11.83 | 2.12× |
| 16 / float64 / broadcast | 19.89–31.80 | 10.93–11.72 | 1.70× |
| 1,024 / float32 / contiguous | 22.94–27.59 | 12.00–12.06 | 1.90× |
| 1,024 / float64 / contiguous | 21.44–32.66 | 11.45–13.46 | 1.59× |
| 1,024 / float32 / stride2 | 59.31–59.72 | 11.97–12.32 | 4.82× |
| 1,024 / float64 / stride2 | 48.11–64.54 | 11.67–13.61 | 3.53× |
| 1,024 / float32 / reverse | 40.82–59.35 | 11.46–12.70 | 3.21× |
| 1,024 / float64 / reverse | 40.19–59.75 | 11.90–12.85 | 3.13× |
| 1,024 / float32 / broadcast | 21.04–31.84 | 11.10–12.87 | 1.63× |
| 1,024 / float64 / broadcast | 20.33–32.10 | 11.24–12.51 | 1.63× |
| 1,048,576 / float32 / contiguous | 392.66–393.99 | 343.39–368.55 | 1.07× |
| 1,048,576 / float64 / contiguous | 847.78–910.05 | 565.97–598.28 | 1.42× |
| 1,048,576 / float32 / stride2 | 15670.50–17909.85 | 352.53–369.18 | 42.45× |
| 1,048,576 / float64 / stride2 | 15311.99–15376.23 | 900.11–960.96 | 15.93× |
| 1,048,576 / float32 / reverse | 17298.25–18183.38 | 331.26–335.07 | 51.63× |
| 1,048,576 / float64 / reverse | 16303.17–17758.17 | 568.91–653.33 | 24.95× |
| 1,048,576 / float32 / broadcast | 376.21–408.28 | 325.30–370.16 | 1.02× |
| 1,048,576 / float64 / broadcast | 435.05–654.00 | 439.05–533.97 | 0.81× |

At 1,048,576 elements, stride-2 addition is conservatively 11× faster natively,
16× faster for Python float64, and 42× for Python float32. Reversed float64
addition is 15× faster natively and 25× through Python. The prior stride-2
slowdown is resolved for these uniformly strided cases.

Large contiguous cases retained their gains. No universal improvement is claimed:
16-element native contiguous addition was about 8% slower (roughly 0.08 µs), and
large Python float64 scalar-broadcast ranges overlap, with a conservative ratio
below one. General nonuniform fallback performance is not resolved by this change.

## Small-call layers and allocation evidence

The following are independent 16-element float64 addition measurements, not
additive accounting. Raw C ABI still includes ctypes crossing and native result
allocation/release. Checked FFI adds Python status/locking machinery; public
ndarray calls also construct result metadata and finalizers.

| Case | Before (µs) | After (µs) | Conservative gain |
| --- | ---: | ---: | ---: |
| raw C ABI via ctypes | 2.80–2.91 | 2.54–2.64 | 1.06× |
| checked FFI without ndarray metadata | 3.99–4.79 | 4.04–5.45 | 0.73× |
| public Python ndarray | 16.26–17.60 | 11.46–12.65 | 1.29× |

The public 16-element contiguous add improved from 16.65–16.93 µs to
12.52–12.87 µs (about 23–26% less time in these runs). The separate layer
measurement confirms an approximately 1.29× conservative improvement. Checked
FFI timings are noisy, so the layer differences should not be treated as exact
component costs.

A separate cProfile run over 20,000 public calls points to result construction:
its cumulative instrumented time fell from 0.402 s to 0.222 s. Profiling overhead
changes timing; these numbers diagnose work, not production latency. Profiles:
[before](profile-before.txt), [after](profile-after.txt).

A Linux/glibc interposer counted malloc/calloc/realloc requests during 1,000
warmed operations after 100 warmups:

| Call | Requests before → after | Requested bytes before → after |
| --- | ---: | ---: |
| C ABI add/release | 30 → 29 | 697 → 689 |
| Python add/close | 32 → 31 | 713 → 705 |

These count allocator requests, not live memory, peak RSS, all Python objects,
or allocations served inside Python/NumPy caches. Bytes include realloc request
sizes; they are not cumulative retained memory. The eight-byte reduction is the
rank-one index vector. Replacing metadata arrays chiefly removes conversion and
adapter work, rather than a large measured glibc allocation count. The interposer
is a single-threaded, glibc-only diagnostic helper and is not linked into Frumpy.
Raw counts: [before](allocations-before.json), [after](allocations-after.json).

Remaining small-call work is mainly metadata/FFI/finalizer overhead, with 29
native allocation requests still present. Investigate which descriptor/registry
allocations can be eliminated and whether metadata retrieval can be combined
with result creation before introducing result reuse or caching APIs. The
unchanged general nonuniform traversal is another separate optimization target.

## Validation

All six GNU 13/14 and Flang 19 debug/release configurations pass 35 native
programs, two examples, 2,999 Python tests and the C caller. Sixty added Python
cases cover both floating dtypes, all four arithmetic operations, positive and
negative steps, multidimensional layouts, fallback broadcasts/transposes, and
metadata through rank 32 across all five dtypes. Native tests cover uniform-step
selection and signed overflow rejection. Existing differential promotion,
allocation-failure, ownership and numerical-order tests remain passing.
GNU 14 memory/overflow gates pass; 328 ABI/package tests pass under ASan and
UBSan, and the native step-overflow cases also pass UBSan. fpm passes all 35
native programs. See [validation evidence](../../validation/strides-2026-10-27.json).

## Reproduce

Build both revisions separately with the same release flags. Point PYTHONPATH
at each revision's Python directory, and use the current benchmark harness:

```sh
PYTHONPATH=WRAPPER/python FRUMPY_LIBRARY=LIBRARY .venv/bin/python benchmarks/compare_strides.py \
  --driver DRIVER --label before-1 --output before-1.json
```

Run before→after, then after→before with corresponding labels and output paths.
Raw reports: [before 1](before-1.json), [after 1](after-1.json),
[before 2](before-2.json), [after 2](after-2.json).

Allocation probe (Linux/glibc, outside timed benchmarks):

```sh
cc -shared -fPIC -O2 benchmarks/count_allocations.c -o /tmp/count-allocations.so
PYTHONPATH=WRAPPER/python FRUMPY_LIBRARY=LIBRARY LD_PRELOAD=/tmp/count-allocations.so \
  .venv/bin/python benchmarks/count_allocations.py
```

Run `benchmarks/profile_small.py` with the same wrapper/library environment for
the separate profile. Profile line numbers may differ from the saved diagnostic
script, but the 20,000-call workload is identical.
