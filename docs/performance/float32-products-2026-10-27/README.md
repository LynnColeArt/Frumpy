# Float32 dot and outer — 2026-10-27

Implemented in `37cc4fe`, with build-target correction `85566f8` and accuracy
harness `84bdda1`. Native `dot_r32`/`outer_r32`, C ABI operations DOT/OUTER with
two R32 handles, and Python `dot`/`outer` now preserve float32. C ABI v1 and
existing float64 behavior remain unchanged. Mixed-dtype promotion and float32
norms remain separate work.

## Accumulation decision

Dot contracts the last left axis against the only right axis for vectors, or
the second-last right axis otherwise. Other axes concatenate, as in NumPy dot;
they do not broadcast as in matmul. Scalar dot multiplies the other operand.
Outer flattens both inputs in C logical order and multiplies each pair.

Float32 contractions use a fixed pairwise tree: split lengths greater than 32
at floor(k/2), compute both halves, and add their sums. Leaves of at most 32
terms accumulate in increasing logical index order from positive zero. All
arithmetic is real32, without explicit widening or BLAS dispatch. No product
buffer is allocated; recursion has logarithmic stack depth. The existing
float64 sequential policy is unchanged.

This balances bounded rounding growth, ordinary float32 semantics and a simple
implementation. It is not compensated summation and does not promise to beat
NumPy's BLAS accuracy or throughput. Future BLAS acceleration would need to
revisit this reduction-order contract explicitly. Ordinary finite comparisons
use rtol=atol=2e-5; long cases additionally compare against float64 arithmetic
with a term-magnitude-scaled bound. Those bounds are tested on finite normal-
range inputs, not asserted for arbitrary overflow, underflow or ill-conditioning.

Outer and scalar dot preserve ordinary multiply signed-zero behavior. NumPy dot
can normalize zero signs via BLAS; tests deliberately use NumPy multiply for
scalar-dot zero signs. Empty contractions return positive zero. Contracted-dot
zero signs and NaN payloads are unspecified. IEEE nonfinite inputs are supported,
with reduction-order-dependent behavior; these are not the finite-only matmul/
solve kernels. See the [full contract](../../LINEAR_ALGEBRA.md).

## Cancellation evidence

For `a = [2**24, 1, ..., 1, -2**24]` and an all-ones RHS, the exact answer is
the number of small terms. Both inputs are float32 and exactly representable.
The diagnostic compares actual Frumpy output, this NumPy build, and a deliberately
sequential float32 sum. Results are workload-specific.

| Small terms / exact sum | Frumpy | NumPy | Sequential float32 |
| ---: | ---: | ---: | ---: |
| 64 | 48 | 63 | 0 |
| 4096 | 4064 | 3969 | 0 |
| 65536 | 65504 | 63489 | 0 |

At 64 small terms Frumpy loses 16, a 25% relative error despite its bounded
absolute error relative to the large terms. At 65,536 it loses 32, while this
NumPy configuration loses 2,047. These examples rule out a universal accuracy
claim. Use float64 inputs when this float32 cancellation behavior is unacceptable;
there is no automatic precision escalation.

## Validation

[Machine-readable evidence](../../validation/float32-products-2026-10-27.json)
records 37 native programs, two examples, the standalone C caller and **3,861
Python tests** passing on GNU 13/14 and Flang 19, debug and release. GNU 14
release also passes with one-thread LP64 OpenBLAS. The 438 dedicated float32
product tests cover native, raw C ABI and Python execution, shapes/ranks, scalar
and empty behavior, ownership, input preservation, signed/zero/offset strides,
IEEE values, long contractions, cancellation and explicit dtype rejection.

GNU 14 memory and overflow differential gates pass 2,643 and 2,159 existing
cases; the new native product lifetime/overflow tests are included. Combined
ABI/package/float32 ASan and UBSan each pass **1,190 tests**, with the native
oracle driver instrumented. Native leak checks remain enabled; Python ASan leak
detection is off. Backend shared libraries are not sanitizer-built. A target-
list wiring error in the first overflow invocation was fixed, and the complete
overflow and C-memory targets then passed; the evidence identifies the rerun.
fpm passes 37 native programs. An isolated source installation passes **364
package tests**, including both new products. Hosted CI execution is not claimed.

## Benchmark method

New float32 functionality is compared with existing float64 functionality and
NumPy; there is no old float32 implementation to label “before.” Differences
include precision and reduction order. GNU 14 uses `-std=f2018 -O3 -fimplicit-none`
without fast-math. All our build/test jobs were stopped before measurement.
Runs pin to CPU 0 and set backend threads to one. Two repetitions reverse dtype
and linked-backend order. Each Python/C/NumPy case records seven warmed timing
batches, wall and CPU times, allocating and closing results inside timing.
Setup, correctness checks and export are outside timing.

The C ABI is timed through ctypes without Python result wrapping. NumPy uses
its own wheel BLAS (recorded in the raw JSON). Frumpy's new kernels never call
BLAS; reference/OpenBLAS linkage runs are controls, not different product
algorithms. The library still requires BLAS for its other numerical operations.
Timing differences between these linkage controls should not be attributed to
backend acceleration of Frumpy dot/outer.

The native Fortran executable uses constant dyadic input vectors and seven CPU-
time batches, with allocation/release included. Python/C cases use varying
values and cover additional layouts and matrix/higher-rank dot. Native timings
are descriptive and must not be subtracted from Python timings as a dispatch
cost estimate. Full raw samples include all tested sizes/layouts, hashes and
source/compiler/backend metadata.

## Selected Python timings

Ranges below span the two run medians in milliseconds. They are observations,
not confidence intervals. NumPy's reduction order and optimized kernels differ.

### Reference linkage

| Case | Frumpy float32 ms | Frumpy float64 ms | NumPy float32 ms |
| --- | ---: | ---: | ---: |
| dot 16 C | 0.0108–0.0153 | 0.0094–0.0096 | 0.0005–0.0005 |
| dot 1048576 C | 0.7460–1.0622 | 0.7171–0.7603 | 0.0747–0.0760 |
| dot 1048576 reverse | 0.7412–0.8256 | 0.7348–0.7709 | 0.3309–0.3461 |
| dot 1048576 step | 0.7688–0.9027 | 0.8697–0.9339 | 0.3554–0.4201 |
| dot 128x128 C | 2.2026–2.2927 | 2.1295–2.2144 | 0.0364–0.0392 |
| outer 1024 C | 3.7878–5.8048 | 4.0052–4.1714 | 0.2652–0.2847 |

### Openblas linkage

| Case | Frumpy float32 ms | Frumpy float64 ms | NumPy float32 ms |
| --- | ---: | ---: | ---: |
| dot 16 C | 0.0097–0.0109 | 0.0095–0.0102 | 0.0005–0.0008 |
| dot 1048576 C | 0.7508–0.8216 | 0.7266–0.7790 | 0.0668–0.0729 |
| dot 1048576 reverse | 0.7471–0.7871 | 0.7748–0.7928 | 0.3229–0.3306 |
| dot 1048576 step | 0.7715–0.8063 | 0.9455–0.9752 | 0.3535–0.3731 |
| dot 128x128 C | 2.1887–2.3838 | 2.0761–2.1623 | 0.0370–0.0381 |
| outer 1024 C | 3.5863–4.3328 | 4.2022–4.3187 | 0.2484–0.3426 |

The contiguous million-element float32 dot takes roughly 0.75–1.06 ms across
these runs, broadly comparable to float64 and well behind NumPy's 0.067–0.076 ms.
The 128-square float32 dot takes roughly 2.19–2.38 ms versus NumPy's 0.036–0.039 ms.
This is a functionality addition, not NumPy performance parity. Outer remains
limited by generic logical indexing; its smaller float32 payload does not
establish a consistent runtime improvement. Small-call timings are noisy.
For ordinary finite rank-two matrix multiplication, `matmul` has the separately
validated BLAS path; dot remains distinct for its scalar/higher-rank/IEEE contract.

## Selected C ABI timings, reference linkage

| Case | Float32 ms | Float64 ms |
| --- | ---: | ---: |
| dot 16 C | 0.0025–0.0027 | 0.0023–0.0042 |
| dot 1048576 C | 0.7510–0.7789 | 0.6964–0.7450 |
| dot 1048576 reverse | 0.7531–0.8462 | 0.7112–0.7341 |
| dot 1048576 step | 0.7327–0.8512 | 0.8849–0.8861 |
| dot 128x128 C | 2.1938–2.1979 | 2.0977–2.2608 |
| outer 1024 C | 3.9363–6.6719 | 3.8201–3.9190 |

## Native Fortran, reference linkage

| Case | Float32 ms | Float64 ms |
| --- | ---: | ---: |
| dot 16 | 0.0007–0.0008 | 0.0007–0.0008 |
| dot 1048576 | 0.7244–0.7586 | 0.7152–0.7310 |
| outer 1024 | 3.4432–5.0656 | 3.5554–4.6254 |

## Memory and next boundary

A 1024×1024 outer result is 4 MiB in float32 versus 8 MiB in float64. Dot returns
four-byte elements, but descriptor/metadata costs do not halve. Neither new
kernel materializes flattened inputs or a product workspace. This is a payload
comparison, not an RSS or allocation-count measurement.

This slice is ready for review. Mixed-dtype dot/outer/matmul promotion is the next
functionality decision; float32 norms remain separate. Performance work would
need to address native traversal and arithmetic, especially matrix dot and
outer, rather than only Python overhead. Acceleration that changes dot's
reduction order requires an explicit numerical-contract decision.

## Reproduction

Run `benchmarks/compare_float32_products.py --output FILE` with `PYTHONPATH`,
`FRUMPY_LIBRARY` and matching `LD_LIBRARY_PATH`. Repeat with `--reverse` and
reverse linked-backend order. Compile `benchmarks/benchmark_products_precision.f90`
against the same release module/core object directories and LP64 libraries;
run with one thread and CPU affinity 0. Text columns are precision bits, operation
(1=outer, 2=dot), vector length, and CPU seconds per allocating call.
`benchmarks/check_float32_dot_accuracy.py` reproduces the cancellation table.
