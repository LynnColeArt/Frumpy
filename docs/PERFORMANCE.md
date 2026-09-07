# Frumpy versus NumPy: initial speed baseline

The current kernels prioritize explicit ndarray semantics. They are not yet
competitive with NumPy on the measured workloads. The checked-in measurements
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

## What to optimize next

The float64 binary and reduction paths still walk general stride/index logic
for every element, even for contiguous inputs. A validated contiguous loop is
the first candidate to measure. Stable insertion sort is quadratic; its growth
at 8,192 elements warrants replacing it with an efficient stable algorithm.
Compiler choice also affects the float32 fallback substantially, so improvements
need both GNU and LLVM validation and measurement. These are conclusions from
the code and baseline, not proof that one specific change will close the gap.
