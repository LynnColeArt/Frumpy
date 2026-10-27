# Frumpy versus NumPy: initial speed baseline

The initial kernels prioritized explicit ndarray semantics and showed large
gaps against NumPy on the measured workloads. The checked-in measurements
below establish a baseline for optimization, using actual compiled Frumpy
calls and actual NumPy calls with the same input values.

## Reproduce

Build release executables in separate directories. Validate the release build
before measuring it:

```sh
make validate build/gcc13-release/bin/benchmark_driver FC=gfortran-13 \
  BUILD_DIR=build/gcc13-release FFLAGS='-std=f2018 -O3 -fimplicit-none'
make validate build/gcc14-release/bin/benchmark_driver FC=gfortran-14 \
  BUILD_DIR=build/gcc14-release FFLAGS='-std=f2018 -O3 -fimplicit-none'
make validate build/flang19-release/bin/benchmark_driver FC=flang-new-19 \
  BUILD_DIR=build/flang19-release FFLAGS='-O3 -Werror'
.venv/bin/python benchmarks/compare_numpy.py \
  --driver GNU13=build/gcc13-release/bin/benchmark_driver \
  --driver GNU14=build/gcc14-release/bin/benchmark_driver \
  --driver Flang19=build/flang19-release/bin/benchmark_driver \
  --output build/benchmark/results.json
```

One `--driver` is sufficient for a local comparison. The script also creates a
Markdown table beside the JSON file. It uses the existing repo-local NumPy
test environment; no additional Python dependency is needed.

## Method

- Single CPU affinity on the tested Linux host; thread environment variables
  fixed at one. No competing Frumpy build jobs during the recorded run.
- Deterministic identical values and layouts; contiguous, reversed, stride-two,
  and scalar broadcasting for float64 addition; contiguous float32 addition;
  contiguous/stride-two float64 sums; stable sorting of a permutation.
- Seven warmed batches, calibrated separately per backend to approximately
  20 ms. Report the median per-call batch time. Raw sample times, iteration
  counts, min/max, CPU, compiler flags, NumPy/Python versions, and source state
  are retained in JSON. Host scheduling and turbo boost still cause variation.
- Timing includes API calls, result allocation, and result release. It excludes
  input construction, process startup, text I/O, and correctness checks. Both
  sides allocate fresh results; neither uses a preallocated `out` array.
- The Fortran driver validates every warm-up output before timing. The Python
  runner also compares output checksums, and the compiler matrix independently
  checks NumPy compatibility. Timing is measured inside each process, not by
  timing the Fortran subprocess from Python.
- GNU builds use portable default CPU targeting with `-O3`, without
  `-march=native`, fast-math, sanitizer overhead, or runtime bounds checks.
  NumPy uses its installed wheel's runtime CPU dispatch. This compares the
  recorded library configurations, not the speed of the two languages.

## Recorded results — 2026-09-07

Measured source: `13af24e`, with a clean working tree. Host: AMD Ryzen 5 5600X; NumPy 2.4.6.

Representative medians for the default GNU Fortran 13 build:

| Operation | Elements | Frumpy (ms) | NumPy (ms) | Frumpy / NumPy time |
| --- | ---: | ---: | ---: | ---: |
| add_r64 | 1,048,576 | 9.501 | 0.481 | 19.7× |
| add_r32 | 1,048,576 | 3.323 | 0.116 | 28.6× |
| sum_r64 | 1,048,576 | 4.647 | 0.164 | 28.3× |
| sort_r64 | 8,192 | 9.896 | 0.039 | 254.2× |

See the [full three-compiler/layout table](performance/2026-09-07.md) and
[raw timing samples and environment](performance/2026-09-07.json). A ratio
above 1 means Frumpy took longer. These measurements do not support a
claim that Fortran is inherently slower: the general loops and sorting
algorithm differ from NumPy’s optimized implementations.

The compiler comparison also matters: the float32 fallback took about
3.3 ms under GNU and 22.8 ms under Flang on the million-element case.
This is a useful compiler-sensitive performance regression case to retain.

## What to optimize next

The float64 binary and reduction paths still walk general stride/index logic
for every element, even for contiguous inputs. A validated contiguous loop is
the first candidate to measure. Stable insertion sort is quadratic; its growth
at 8,192 elements warrants replacing it with an efficient stable algorithm.
Compiler choice also affects the float32 fallback substantially, so improvements
need both GNU and LLVM validation and measurement. These are conclusions from
the code and baseline, not proof that one specific change will close the gap.


## v0.1 frozen baseline — 2026-10-26

Measured clean source: `3e1a191`, after all six compiler configurations passed.
The new [native table](performance/v0.1-native.md) and
[Python table](performance/v0.1-python.md) retain their
[native raw samples](performance/v0.1-native.json) and
[Python raw samples](performance/v0.1-python.json). Both use GNU 14 `-O3`, single
CPU affinity, seven warmed samples and thread environment variables fixed at
one. Inputs/exports are outside timing; result allocation and release are inside.
Result payload bytes are recorded. Descriptor, scratch and Python metadata
allocation costs are included in time but individual heap calls are not counted.

The Python baseline adds 128×128 matmul and 64×64 solve. Frumpy links reference
LP64 BLAS/LAPACK 3.12.0; NumPy uses its wheel's OpenBLAS 0.3.31.188.0. These
backend differences are material, so matrix timing is not isolated wrapper cost.
Likewise, Python arithmetic uses the mixed dispatcher while the native addition
baseline uses concrete typed kernels; their timing difference cannot all be
attributed to Python overhead.

Representative Python medians: 1,024-element add 39.16 µs versus NumPy 0.74 µs;
one-million-element add 16.47 ms versus 0.404 ms; 8,192-element stable sort
11.17 ms versus 0.046 ms. These are measured starting points, not speed targets.
The next investigations are efficient stable sorting, contiguous/mixed traversal,
small-call allocation/dispatch, and backend/packing policy, with before/after
checks on signed strides and ownership. See [the post-v0.1 plan](POST_V0_1_PLAN.md).

To reproduce the Python entry point after the validated release build:

```sh
PYTHONPATH=python FRUMPY_LIBRARY="$PWD/build/gcc14-release/libfrumpy.so" \
  .venv/bin/python benchmarks/compare_python.py --samples 7 \
  --output build/benchmark/python.json
```

Stop other build/benchmark jobs before collecting comparison samples. Preserve
the raw source/configuration metadata and compare multiple runs before setting
performance regression thresholds.


## Stable sorting improvement — 2026-10-27

Stable sort/argsort now use merge sort with small insertion runs and lazy,
reusable workspace. The [controlled before/after report](performance/sort-2026-10-27/README.md)
records two seven-sample measurement pairs and the memory tradeoff. Native
8,192-element sorting improved from 10.8–18.9 ms to 0.225–0.384 ms; the
conservative observed gain is 28×. Larger unsorted inputs show greater gains.
Tiny and already-sorted results are noisy/roughly flat, so no universal speedup
is claimed. The frozen v0.1 baseline remains unchanged for historical comparison.

Next: profile and optimize contiguous arithmetic/reduction traversal, comparing
concrete native and mixed-dispatch paths separately.
