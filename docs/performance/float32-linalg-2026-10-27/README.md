# Float32 matmul and solve — 2026-10-27

Implemented at `1793767`. Native `matmul_r32` and `solve_r32`, C ABI operations
`FRUMPY_MATMUL`/`FRUMPY_SOLVE` with two R32 handles, and Python `matmul`, `@`,
`linalg.solve` now preserve float32. Mixed-dtype promotion, float32 dot/outer and
norms remain separate work. Existing float64 behavior and C ABI v1 are retained.

## Behavior and precision

The concrete float32 core uses SGEMM/SGESV and follows the established float64
shape, broadcasting, packing, status and lifetime rules. Results own C-order
storage; sources remain unchanged. C/F rank-two matmul retains its direct-input
paths; irregular/vector/batched operations use the existing packing design.
Solve reuses workspace across batches and preserves singularity checks for an
empty RHS. All byte-overflow guards account for four-byte float32 storage.

Both inputs must be the same floating dtype. Nonfinite values in blocks actually
read remain unsupported. Explicit casts are required for mixed-dtype pairs.
The [numerical contract](../../LINEAR_ALGEBRA.md) documents that SGESV performs
single-precision elimination; the installed NumPy 2.4.6 solve instead computes
in double precision and casts its float32 output. This can affect rounding,
forward accuracy and singularity classification for ill-conditioned systems.
Well-conditioned tests use rtol=atol=2e-5, with additional scaled residual checks.
An ill-conditioned Hilbert case checks residual rather than promising forward
agreement. No condition estimator, refinement or universal error bound is added.

## Validation

[Machine-readable evidence](../../validation/float32-linalg-2026-10-27.json)
records 36 native test programs, two examples and the standalone C caller passing
on GNU 13/14 and Flang 19 in debug and release configurations. The final Python
suite passes **3,423 tests** in each configuration and with one-thread LP64
OpenBLAS under GNU 14 release. The 340 dedicated float32 tests span native,
raw C ABI and Python entry points, shape/batch rules, C/F and signed/zero/offset
strides, dtype rejection, empty/singular/late-failing batches and numerical residuals.
Native tests additionally cover malformed descriptors, LP64 and byte guards,
independent ownership, input preservation, lifetime and status omission.

GNU 14 native memory and integer-overflow gates pass their 2,643 and 2,159
existing differential cases. New native float32 lifetime/overflow tests pass
ASan with leak detection and UBSan/overflow checks. The combined ABI/package/
float32 suite passes **752 tests** under each sanitizer, including an instrumented
native differential driver. Python ASan leak detection is disabled; standalone
C/native leak detection remains enabled. Backend libraries are not sanitizer-built.
fpm passes all 36 native programs. A clean source install into an isolated venv
passes 362 package tests, including float32 matmul/solve. Hosted CI execution is
not claimed; existing validation jobs now include the new coverage.

## Benchmark method

This is new functionality, so there is no float32 “before” implementation.
The comparisons below show the precision/performance tradeoff against float64
in the same source snapshot, not an equivalent-accuracy optimization speedup.

GNU 14 uses `-std=f2018 -O3 -fimplicit-none`, with no fast-math. Tests/builds were
stopped before timing. Reference LP64 BLAS/LAPACK 3.12.0 and OpenBLAS 0.3.26 LP64
pthread are measured separately, using one thread and CPU affinity 0. Each
Python/C/raw case has seven warmed batches, with both wall and process CPU
samples retained. Two runs reverse both backend order and float32/float64 order.
Calls allocate and close/free their result; input setup and export are untimed.

The direct C ABI column omits Python result wrapping but includes native
validation, allocation and release. Raw BLAS uses the same loaded libraries:
CBLAS allocates its output with pre-created C inputs; raw solve makes destructive
F-order input copies. It omits Frumpy metadata and finite-input checks, and raw
C-input GEMM is not an exact replica of every Frumpy layout. NumPy uses its own
wheel backend (recorded in the JSON); its float32 solve is also a different
internal precision. Neither is presented as a perfectly matched end-to-end rival.

Native Fortran measurements use five CPU-time batches per case, C-order dense
inputs `A = n*I + 0.01`, and an all-ones matrix RHS. Setup and a correctness check
are outside timing. These inputs differ from the Python/C/raw benchmark, so
absolute times must not be subtracted across those tables. Native float32 runs
before float64 within each size; its repeated data is descriptive, not an order-
controlled speedup estimate.

## Python interface results

Ranges span the two per-run wall-time medians, in milliseconds. Small calls and
some controls fluctuate; these ranges are observations, not confidence intervals.

### Reference backend

| Workload | Float32 ms | Float64 ms |
| --- | ---: | ---: |
| matmul 16² C | 0.0140–0.0147 | 0.0139–0.0144 |
| matmul 16² F | 0.0129–0.0150 | 0.0156–0.0160 |
| matmul 16² stepped | 0.0129–0.0139 | 0.0160–0.0285 |
| solve 16² C | 0.0174–0.0193 | 0.0233–0.0262 |
| matmul 128² C | 0.7440–0.7724 | 1.3064–1.6579 |
| matmul 128² F | 0.7015–0.7588 | 1.1938–1.4718 |
| matmul 128² stepped | 0.7032–0.7064 | 1.2082–1.4943 |
| solve 128² C | 1.4000–1.7142 | 1.6019–1.9362 |
| matmul 512² C | 40.0799–40.4233 | 71.0466–87.4768 |
| matmul 512² F | 41.5343–49.8903 | 69.8991–86.1802 |
| matmul 512² stepped | 39.3069–39.9539 | 71.8394–79.7722 |
| solve 512² C | 82.4473–95.7171 | 102.0622–106.5958 |

### Openblas backend

| Workload | Float32 ms | Float64 ms |
| --- | ---: | ---: |
| matmul 16² C | 0.0127–0.0130 | 0.0123–0.0466 |
| matmul 16² F | 0.0124–0.0161 | 0.0156–0.0180 |
| matmul 16² stepped | 0.0130–0.0172 | 0.0145–0.0160 |
| solve 16² C | 0.0144–0.0163 | 0.0206–0.0240 |
| matmul 128² C | 0.0720–0.0819 | 0.1348–0.1452 |
| matmul 128² F | 0.0859–0.1124 | 0.1469–0.1487 |
| matmul 128² stepped | 0.1197–0.1705 | 0.1620–0.1911 |
| solve 128² C | 0.2005–0.2052 | 0.3206–0.3410 |
| matmul 512² C | 2.7292–3.0946 | 5.0271–5.2060 |
| matmul 512² F | 3.1707–3.6100 | 5.9827–6.2852 |
| matmul 512² stepped | 4.4488–5.1945 | 8.9596–9.7353 |
| solve 512² C | 4.8317–5.9596 | 11.5210–11.6655 |

For 512-square C matmul on OpenBLAS, the fastest float64 run divided by the
slowest float32 run is about **1.62×**; for solve it is **1.93×**. These conservative
observed ratios accompany reduced precision. Small calls offer no universal gain:
OpenBLAS's 16-square float64 C matmul varies from 0.0123 to 0.0466 ms, and the
reference 16-square float32 C case is slightly slower than float64 in these runs.
The remaining stepped packing and native-allocation work was not changed.

## C ABI and matched backend, 512-square cases

| Backend / case / dtype | C ABI ms | Raw backend ms |
| --- | ---: | ---: |
| reference / matmul / float32 | 37.479–39.412 | 42.079–42.103 |
| reference / matmul / float64 | 69.817–77.097 | 70.129–81.828 |
| reference / solve / float32 | 85.742–94.574 | 80.391–92.756 |
| reference / solve / float64 | 105.390–105.588 | 112.324–121.051 |
| openblas / matmul / float32 | 2.712–3.057 | 2.521–2.630 |
| openblas / matmul / float64 | 4.989–5.256 | 4.848–4.933 |
| openblas / solve / float32 | 4.755–6.127 | 4.769–9.447 |
| openblas / solve / float64 | 11.486–12.494 | 10.700–10.784 |

## Native Fortran, 512-square cases

| Backend / case | Float32 ms | Float64 ms |
| --- | ---: | ---: |
| reference / matmul | 37.553–40.469 | 62.774–66.269 |
| reference / solve | 91.254–93.284 | 96.766–107.343 |
| openblas / matmul | 2.680–3.065 | 4.774–5.851 |
| openblas / solve | 6.136–6.801 | 15.012–15.441 |

## Memory and next boundary

Float32 payloads and real work arrays use half the float64 bytes; metadata and
pivot arrays do not shrink. A 512×512 output is 1 MiB rather than 2 MiB. C-order
rank-two matmul needs no extra matrix workspace; both-F-order matmul needs one
output workspace. Solve still needs separate coefficient and RHS workspaces.
This is a storage-width reduction, not a reduction in allocation count or an RSS
measurement.

This slice is ready for review. Next functionality can add float32 dot/outer,
then explicitly designed mixed-dtype promotion; norms remain separately scoped.
The earlier packing/allocation backlog remains deferred unless workload profiles
justify another optimization pass.

## Reproduction

Build the selected source with GNU 14 release flags and LP64 link libraries.
Run `benchmarks/compare_float32_linalg.py --blas PATH --lapack PATH --output FILE`
with `PYTHONPATH=python`, `FRUMPY_LIBRARY` and matching `LD_LIBRARY_PATH`.
Repeat with `--reverse`, and reverse backend order. Raw JSON contains hashes,
source commit, flags, linkage, affinity, thread settings and NumPy configuration.

Compile `benchmarks/benchmark_linalg_precision.f90` using the same release module
and core object directories and BLAS/LAPACK link flags; run it with one backend
thread and CPU affinity 0. Its text columns are precision bits, operation code
(3=matmul, 4=solve), matrix size, and CPU seconds per allocating call. Keep the
native input difference and fixed precision order in mind when interpreting it.
