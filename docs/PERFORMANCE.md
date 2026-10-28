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

The subsequent contiguous arithmetic/reduction comparison is recorded below.


## Contiguous arithmetic and reductions — 2026-10-27

Validated C-contiguous/constant-broadcast float32 and float64 arithmetic now
uses shared linear loops through both native and Python entry points. Float64
reductions read contiguous ranges linearly without changing sequential order;
float32 sum/mean keep their pairwise tree while simplifying leaf addressing.
No new payload/scratch buffers or fast-math are used.

The [repeated before/after comparison](performance/contiguous-2026-10-27/README.md)
records conservative gains at 1,048,576 elements: native float64 addition 11.8×,
Python float64 addition 18.2×, Python float32 addition 31.4×, and Python float64
sum 5.6×. Small sums are noisy/roughly flat. Stride-2 addition was slower: a
focused alternating check found about 3% native and 11% Python slowdown, with
larger penalties in the main runs. Full samples and these limitations are retained.

Next: investigate strided dispatch/code generation and quantify small-call
metadata/allocation costs before choosing reuse or caching APIs.


## Uniform strides and small-call overhead — 2026-10-27

The [follow-up comparison](performance/strides-2026-10-27/README.md) resolves the
stride-2 regression for uniformly strided floating arithmetic. At 1,048,576
elements, float64 addition improves conservatively 11× natively and 16× through
Python relative to the previous contiguous optimization; reversed inputs improve
15× and 25× respectively. The contiguous gains remain intact at large sizes.

Local ctypes metadata buffers and simpler conversion reduce a 16-element Python
float64 add from roughly 17 to 13 µs. Lazy index allocation removes one glibc
allocation request (30 to 29 per C-ABI small add). Full raw timings, layer
measurements, allocator counts, profiling evidence and noisy/slower cases are
retained in the report. Next: inspect remaining descriptor/registry allocations
and repeated metadata/FFI work; general nonuniform traversal remains separate.


## Remaining measured queue — 2026-10-27

The [consolidated queue report](performance/queue-2026-10-27/README.md) closes
nonuniform floating arithmetic, handle/FFI overhead and matched BLAS packing
work. It retains repeated wall/CPU measurements, many-live-handle scaling,
allocation counts, a rejected backend experiment and explicit deferred cases.
Both reference LP64 BLAS and one-thread OpenBLAS pass correctness validation.
The bounded initial optimization queue is complete; broader dtype coverage,
distribution and any further API/threading changes follow the post-v0.1 plan.

## Focused regression recheck and tiny dispatch — 2026-10-27

The [focused follow-up](performance/recheck-2026-10-27/README.md) did not
reproduce a consistent stepped-matmul or solve regression in six alternating
process pairs. Backend timing probes also show overlapping backend and remaining
costs. Native kernels remain unchanged. A small Python array-pair dispatch
change skips redundant conversion; paired sample ratios improve modestly, while
whole-session medians remain noisy. Full measurements, unchanged allocation
counts, a discarded metadata-buffer experiment and validation are retained.


## Float32 matmul and solve — 2026-10-27

[The implementation and benchmark report](performance/float32-linalg-2026-10-27/README.md)
compares float32 and float64 through native Fortran, C ABI, Python and matched
LP64 backends. On one-thread OpenBLAS, 512-square C matmul takes 2.73–3.09 ms
for float32 versus 5.03–5.21 ms for float64; solve takes 4.83–5.96 versus
11.52–11.67 ms. These are precision tradeoffs, not equal-accuracy speedups.
Payload/workspace real storage halves; tiny timings remain noisy. NumPy's
float32 solve widens internally, while Frumpy uses SGESV, as documented.


## Float32 dot and outer — 2026-10-27

[The products report](performance/float32-products-2026-10-27/README.md) covers
native, C ABI and Python execution, a bounded pairwise float32 accumulation
policy, and cancellation examples where NumPy is both more and less accurate.
Payload size halves, but contiguous dot is broadly comparable to float64 and
NumPy remains substantially faster on large vector/matrix dot cases. Generic
outer traversal also leaves a performance gap. Full timings and limitations
are retained; this is added functionality, not a universal speed improvement.

## Mixed-dtype products — 2026-10-27

[The promotion report](performance/product-promotion-2026-10-27/README.md) compares
implicit casts with reusable precasts, plus isolated conversion costs, across
native Fortran, C and Python. For int32/float32 inputs, Python's 65,536-element
dot takes 685–687 µs versus 58–59 µs after precasting with the reference backend;
OpenBLAS 128×128 matmul takes 322–332 µs versus 103–110 µs. Outer conversion
is a smaller share of its quadratic output work. Repeated stable inputs benefit
from reusable casts; contiguous `astype` is a focused future optimization target.
Raw timing ranges, backend distinctions, memory costs and noise remain explicit.

## Contiguous casts — 2026-10-27

[The matched before/after report](performance/contiguous-casting-2026-10-27/README.md)
covers direct loops for C-contiguous casts to float32/float64. Python's mixed
int32/float32 dot at 65,536 elements falls from 656–710 µs to 168–170 µs;
OpenBLAS 128×128 matmul falls from 332–343 µs to 153–178 µs. Native and C
measurements also improve. Outer gains are smaller and noisier; allocation
payload is unchanged. Slower stepped/tiny cases were rechecked and retained:
an isolated stepped bool/float32 dot still measured 6–10% slower through Python.
This is not a universal speedup or a claim that every fallback path is unchanged
in performance. Full controls, raw samples and limitations are linked above.

## Float32 Euclidean/Frobenius norms — 2026-10-27

[The float32 norms report](performance/float32-norms-2026-10-27/README.md) records
native/C/Python timings and the chosen float32-result, scaled-float64-accumulator
policy. Storage halves without a full-size widening buffer. Runtime is broadly
similar to float64, often slightly slower; Python's contiguous 65,536-element
norm takes 480–485 µs versus NumPy float32's 20 µs. The latter uses a different
numerical policy and can overflow/underflow on inputs handled by Frumpy.
This is completed dtype coverage with explicit robustness/throughput tradeoffs,
not a speed optimization. Raw timings and precision diagnostics are retained.

## Focused float32 norm optimization — 2026-10-27

[The matched norm optimization report](performance/norm-optimization-2026-10-27/README.md)
compares scaled accumulation with pairwise sums of squares widened before
multiplication, plus constant-stride traversal. Python's contiguous 65,536-element
norm falls from 490–504 µs to 50–56 µs; 128×128 Frobenius falls from 154–161 µs
to 22–23 µs. Native/C measurements improve substantially too. The range argument
preserves the overflow/underflow robustness goals without scaling for float32;
float64 norms remain scaled. Existing accuracy diagnostics are unchanged, with
176 additional high-accuracy/layout tests. Irregular layouts improve much less;
NumPy retains a smaller throughput lead. No full-size scratch buffer is added.

## Five-dtype argmin/argmax — 2026-10-27

[The index-reduction baseline](performance/arg-reductions-2026-10-27/README.md)
covers bool, int32, int64, float32 and float64 across native/C/Python. First ties,
first NaNs and exact int64 comparisons are preserved without input temporaries.
Float32 contiguous argmin at 65,536 elements takes about 162 µs native,
168–172 µs C and 179–180 µs Python, versus NumPy's 4.5–5.0 µs.
Stepped/reversed inputs have similar Frumpy costs; irregular flattening and
bool searches expose further opportunities. No before/after comparison exists
for this new feature. Noisy cases are retained and separately rechecked.
A future focused pass should begin with concrete typed scan loops and bool
early termination, preserving the index-selection contracts.

## Focused argmin/argmax optimization — 2026-10-28

[The matched scan report](performance/arg-optimization-2026-10-28/README.md)
covers typed scans, bool early exits and incremental irregular traversal.
Python float32 argmin at 65,536 contiguous elements falls from 191–215 µs to
61–65 µs; 128×128 F-order flattening falls from 166–234 µs to 46–52 µs.
Contiguous bool argmin with a first-position match falls from 150–168 µs to
12 µs; absent-match scans improve from 149–171 µs to 65–71 µs. Native/C
results also improve without a full-input temporary or contract changes.
Small calls remain mixed: tiny int64 argmin is 2–5% slower through Python in
isolated paired rechecks. The noisy float64 F-order axis regression does not
reproduce. Raw samples, all distributions and slower cases remain in the report.
This completes the bounded scan pass; broader wrapper/SIMD work can wait while
functionality resumes.

## Stable sorting across five dtypes — 2026-10-28

[The sorting dtype report](performance/sort-dtypes-2026-10-28/README.md) records
bool/int32/int64/float32 additions and float64 controls across native/C/Python.
The new shared index merge path preserves exact integer ordering and floating
NaN/signed-zero stability, but float32 random-pattern sort at 8,192 elements
takes 813–871 µs through Python versus 215–222 µs for the existing float64 kernel
and 120–134 µs for NumPy float32. Sort holds an 8N-byte index temporary; argsort
uses its output plus bounded per-axis workspaces. Sorted/duplicate/layout cases
and raw allocation-payload formulas are retained in the report.
The float64 core object is unchanged. Removing duplicate validation reduces
avoidable overhead, but tiny float64 argsort still adds about 0.5–1.1 µs through
Python in paired rechecks. A noisy bool argsort outlier did not reproduce.
This is completed functionality with documented performance costs, not a
universal speed improvement.

## Same-dtype searchsorted — 2026-10-28

[The five-dtype search report](performance/search-dtypes-2026-10-28/README.md)
covers native/C/Python left and right insertion, exact int64 keys, scalar and
batched queries, and signed/F-order layouts. With 8,192 source elements and
4,096 contiguous left queries, Python takes 137–147 µs for bool, 255–264 µs
for int32, 256–257 µs for int64, 279–291 µs for float32 and 206–207 µs for
float64. NumPy takes about 29–45 µs. The four additions use shared binary-search
kernels without full-input temporary buffers; output payload is 8 bytes per query.
Float64 retains its existing kernel/direct C path, with paired control results
recorded. This adds functionality rather than claiming a universal speedup.
Mixed-dtype queries and the optional sorter argument remain excluded.
