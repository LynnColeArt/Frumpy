# Frumpy v0.1 release checklist

Status: release candidate ready for review. Scope established on 2026-10-26.
Publishing/tagging is a separate step; no full NumPy compatibility is implied.

v0.1 is a usable CPU array library for Fortran and Python, with an explicit
NumPy-compatible subset. It is not full NumPy or Array API conformance. This
checklist is the release gate; [PROJECT_PLAN.md](../PROJECT_PLAN.md) remains
the long-term roadmap.
An unchecked item is required work, not an implication that nothing exists yet.
No dates or completion percentages are inferred from the number of boxes.

## Release contract

- Dtypes: bool, int32, int64, float32, float64. No complex or object arrays.
- Shapes/strides: scalars, empties, C/F order, negative and zero strides, ordinary
  slices, trailing-dimension broadcasting, explicit copy/view behavior.
- CPU only; LP64 BLAS/LAPACK for the bounded float64 backend operations.
- Recoverable errors, managed storage, documented Fortran container-copy limits.
- NumPy is the oracle for the listed operations, with tested departures. Random
  reproducibility is a separate versioned contract, not NumPy stream identity.

## A. Existing foundation to preserve

- [x] Managed storage for all five descriptors, sharing, release and finalization.
  Evidence: [STORAGE_LIFETIME.md](STORAGE_LIFETIME.md) and the two storage lifetime test programs.
- [x] All ordered dtype pairs for add/subtract/multiply/divide, including the
  boolean subtraction exception. Evidence: [MIXED_ARITHMETIC.md](MIXED_ARITHMETIC.md).
- [x] Float32/float64 negate, abs, sqrt, exp, log, sin, cos and
  sum/prod/mean/min/max (all axes or one axis, keepdims).
  Evidence: [DTYPE_SUPPORT.md](DTYPE_SUPPORT.md) and [FLOAT32_REDUCTIONS.md](FLOAT32_REDUCTIONS.md).
- [x] Float64 constructors, views/slicing, selection, sorting and searching as
  enumerated in [DTYPE_SUPPORT.md](DTYPE_SUPPORT.md) and [SELECTION_SUPPORT.md](SELECTION_SUPPORT.md).
- [x] Finite float64 matmul with broadcast batches and unbatched square solve.
  Evidence: [LINEAR_ALGEBRA.md](LINEAR_ALGEBRA.md).
- [x] Direct compiled NumPy comparisons, GNU/Flang debug/release matrix, GNU
  memory and integer-overflow gates. Evidence: [COMPILER_PORTABILITY.md](COMPILER_PORTABILITY.md).

## B. Numerical toolkit

Implement in this order, keeping each change independently tested:

- [x] B1: `outer_r64`, flattening both inputs in C logical order, scalar/empty
  inputs, arbitrary supported strides and IEEE values, owned rank-two output.
  Evidence: [LINEAR_ALGEBRA.md](LINEAR_ALGEBRA.md), 51 NumPy comparisons and Fortran invariants.
- [x] B2: `dot_r64`, including scalar multiplication and NumPy higher-rank
  contraction rules; do not substitute matmul's batch broadcasting rules.
- [x] B3: float64 vector Euclidean norm and matrix Frobenius norm, documented
  axis/keepdims subset, scaled accumulation and extreme-value tests.
- [x] B4: broadcast batched float64 solve, using NumPy 2.x RHS rank semantics;
  retain finite-input, singularity and LP64 limits.
- [x] B5: explicit seeded generator state with float64 uniform [0,1) and standard
  normal output. Freeze algorithm/state format, reproducibility scope and seed
  mapping; add golden streams, range checks and distribution sanity checks.

Additional dtypes for linear algebra and general factorizations are post-v0.1.

## C. Complete the everyday five-dtype path

- [x] C1: empty/zeros/ones/full, asarray/copy/ascontiguousarray for all five
  dtypes; retain float64 arange/linspace as the v0.1 sequence constructors.
- [x] C2: reshape/ravel/flatten/transpose/swapaxes/squeeze/expand_dims/basic
  slicing for all five dtypes, with the same copy/view contract as float64.
- [x] C3: array `astype` across the five dtypes, explicit casting mode and tested
  conversion semantics; resolve the stricter existing scalar-cast contract
  explicitly rather than silently applying it to NumPy-style array casts.
- [x] C4: equal/not_equal/less/less_equal/greater/greater_equal with broadcasting
  and mixed numeric dtype handling; boolean logical_and/or/xor/not.
- [x] C5: boolean all/any; integer sum/prod/min/max/mean with documented NumPy
  accumulator/result dtypes and overflow behavior. Support all-axis and one-axis
  reductions with keepdims, matching the float subset.
- [x] C6: float64 boolean mask extraction and assignment through basic slices;
  define broadcasting, source/destination aliasing and failure behavior in tests.
  Retain existing float64 take/where/concat/stack/sort/search contracts.

Multi-axis tuples, reduction out/where/initial options, arbitrary advanced index
arrays and full non-float64 selection/sorting are deferred. Python scalar
promotion must be specified at the Python boundary; array-pair promotion alone
is not sufficient evidence for it.

## D. C ABI and Python package

Depends on the storage contract; design can start before B/C are complete.

- [x] D1: versioned C header with opaque array handles, create/retain/release,
  dtype/shape/stride queries and explicit status/error handling. No exposed
  compiler-specific Fortran layouts. Test ownership from a C caller.
- [x] D2: owned buffer import/export and operation dispatch for the v0.1 surface.
  Copying imports are acceptable and must be explicit; zero-copy interchange is
  deferred. Test invalid handles/arguments within the documented API contract.
- [x] D3: installable Python package with ndarray, constructors, arithmetic,
  views/indexing, reductions, selection and numerical calls from B/C; map status
  to exceptions and define Python scalar/coercion behavior.
- [x] D4: test Python lifetime, aliasing, exception cleanup and round trips with
  NumPy; a Python reference must keep its view's backing alive.
- [x] D5: reproducible source build/install on Linux x86_64, documented compiler
  and BLAS/LAPACK prerequisites, clean-environment installation smoke test.
  Binary wheels and additional platforms are later release work.

## E. Release acceptance and performance handoff

- [x] E1: publish an operation-by-dtype coverage table linked to public APIs and
  tests. Audit every v0.1 export against it; no unsupported operation silently
  changes dtype or falls back to NumPy.
- [x] E2: pass the full compiler matrix and applicable sanitizer gates on the
  release candidate; verify fpm with development libraries installed, as well
  as Make. Automate the supported Linux build and differential checks in CI.
- [x] E3: end-to-end Fortran and installed-Python examples covering creation,
  views, broadcast mixed arithmetic, reduction, selection, matmul and solve;
  compare results and ownership behavior with the declared NumPy contract.
- [x] E4: release notes enumerate compatibility departures, build requirements,
  numerical tolerances, backend limits and remaining work. Resolve blockers,
  then prepare the v0.1 release candidate; publishing/tagging is a separate step.
- [x] E5: capture reproducible performance baselines through both Fortran and
  Python entry points, including allocations, sizes/layouts and BLAS threading.
  This freezes the starting point for the optimization phase, not a speed target.

Definition of done for each implementation item: oracle behavior recorded,
regression test fails before the change, implementation passes relevant tests,
metadata/lifetime/error paths checked, public contract documented. Mark a box
only when all its requirements are met. Record partial work under the item.

## Execution order

B1 → B2 → B3 → B4 → B5, then C1 → C2 → C3 → C4 → C5 → C6,
then complete D1–D5 and E1–E5. Inspect ABI needs during C work so interface design
does not become an afterthought. Reorder only for a concrete dependency or
correctness finding and record the reason here. Preserve existing tests throughout.

## Progress ledger

- 2026-10-26: established the bounded release contract and audited existing
  foundation against the current source/docs. Completed B1 (`outer_r64`); next
  is B2 (`dot_r64`). All six GNU 13/14 and Flang 19 debug/release configurations
  pass 27 Fortran programs and 2,017 Python tests. Memory and overflow gates
  pass on GNU 13 and 14.

See [post-v0.1 plan](POST_V0_1_PLAN.md) for performance and broader coverage.

- 2026-10-26: completed B2–B5: native dot, scaled vector/Frobenius norms,
  broadcast batched solve, and explicit xoshiro256** uniform/normal generation.
  GNU 14 ordinary validation: 28 Fortran programs and 2,195 Python tests.
  GNU 14 memory gate: 2,167 compiled comparisons; overflow gate: 1,683 cases.
  Full release compiler/platform acceptance remains open under E2. Next: C1.

- 2026-10-26: completed C1–C2 with concrete constructors and typed views for
  all five dtypes, plus a shared metadata-only view planner. Fixed empty-slice
  offset arithmetic and extreme slice-step length overflow. GNU 14 ordinary:
  30 Fortran programs, 2,331 Python tests; memory: 2,303 compiled comparisons;
  overflow: 1,819 cases. See CONSTRUCTORS_AND_VIEWS.md for bounded deviations.
  Next: C3 array casting, then comparisons/logical operations.

- 2026-10-26: completed C3–C6: transactional array astype, mixed comparisons,
  boolean logic, integer/boolean reductions, full-shape mask extraction and
  staged assignment through float64 views. GNU 14 ordinary: 34 Fortran programs,
  2,671 Python tests; memory: 2,643 compiled comparisons; overflow: 2,159 cases.
  ARRAY_OPERATIONS.md records float-to-integer and accumulation-order departures.
  Next: D1–D5 C ABI and installable Python integration.

- 2026-10-26: completed D1–D5: ABI-v1 opaque handles and native operation
  dispatch, serialized ctypes package, Linux source distribution and clean-venv
  installation. 49 direct ABI tests and 38 package tests pass on GNU 14; the
  combined 87 pass with ASan instrumentation (Python leak detection disabled),
  and the standalone C ownership program passes ASan with leak detection.
  The source archive builds/installs in a separate environment and all 38 public
  package tests pass against that installed library. Full compiler acceptance
  and release audit remain under E1–E5.

- 2026-10-26: release audit completed the operation/API/dtype map and found
  missing native byte-count guards and float64 constructor validation. Added
  failing edge regressions, then guarded all multi-byte owner allocations,
  nonfinite/range-overflow arange, and malformed copy sources. Added equivalent
  Fortran/installed-Python workflow examples. fpm test passes with isolated
  BLAS/LAPACK development archives. Moved the standalone C caller outside fpm's
  test source tree and reused per-profile PIC core objects in Make. Full final
  compiler/sanitizer evidence and baseline capture are still in progress.

- 2026-10-26: completed release acceptance at source snapshot `3e1a191`.
  All six GNU 13/14 and Flang 19 debug/release configurations pass 35 native
  programs, two examples, 2,758 Python tests and the C caller. Both GNU memory
  gates pass 2,643 differential cases; overflow gates pass 2,159; C/Python address
  checks pass 87, with standalone C leak detection. fpm and clean source install
  pass. CI is configured; hosted execution is not claimed. Release notes and
  operation coverage are published in this tree. Native and Python baselines
  capture clean-source, allocating calls, layouts, result bytes, backend/thread
  settings and seven timing samples. See `validation/v0.1.json`,
  `performance/v0.1-native.json` and `performance/v0.1-python.json`.
  Candidate is ready for review; no merge, tag or package publication performed.

- 2026-10-27: review follow-up fixed scalar-axis int32 truncation and mutable
  Python contiguity flags. First performance change replaces quadratic sort/
  argsort with stable merges, small insertion runs and lazy reusable buffers.
  At `61a6bba`, all six compiler configurations pass 35 native programs, two
  examples, 2,839 Python tests and the C caller. GNU 14 memory/overflow gates
  and 168 ABI/package ASan/UBSan tests pass. The original v0.1 baseline is retained;
  `performance/sort-2026-10-27/README.md` records repeated comparisons and timing
  variability. No merge, release tag or package publication performed.

- 2026-10-27: contiguous arithmetic/reduction follow-up at `1d83bc3` preserves
  reduction order, offsets, strides and storage checks. Six compiler configurations
  pass 35 native programs, two examples, 2,939 Python tests and the C caller.
  GNU 14 memory/overflow gates, 268 ABI/package ASan/UBSan tests and fpm pass.
  `performance/contiguous-2026-10-27/README.md` records repeated before/after
  measurements, strong contiguous gains and the observed stride-2 slowdown.

- 2026-10-27: uniform signed-stride arithmetic and small-call metadata follow-up
  at `f8882d5`. Six compiler configurations pass 35 native programs, two examples,
  2,999 Python tests and the C caller; GNU 14 sanitizer gates and fpm pass.
  `performance/strides-2026-10-27/README.md` records stride-2/reverse improvements,
  small-call measurements and explicit glibc allocation counts.

- 2026-10-27: remaining optimization queue completed at `f1b9e05`: nonuniform
  float rows, indexed handles, initialized FFI dispatch and rank-two matrix
  packing. All six compiler configurations pass 3,078 Python tests, 35 native
  programs, two examples and the C caller; one-thread OpenBLAS also passes.
  GNU 14 sanitizer gates, 407 ABI/package ASan/UBSan cases, registry allocation
  recovery and fpm pass. See `validation/queue-2026-10-27.json` and
  `performance/queue-2026-10-27/README.md` for evidence and deferred boundaries.
  Candidate is ready for review; no merge, tag or package publication performed.

- 2026-10-27: focused regression/dispatch follow-up at `315a44e`. Stepped matmul
  and solve regressions were not consistently reproduced; native code unchanged.
  Python array-pair dispatch skips redundant coercion. All six existing compiler
  configurations and one-thread OpenBLAS pass 3,081 Python tests; ABI/package
  ASan and UBSan each pass 410. See `performance/recheck-2026-10-27/README.md`
  and `validation/recheck-2026-10-27.json` for scope, raw timings and limitations.

- 2026-10-27: additive functionality at `1793767`: same-dtype float32 matmul and
  solve across native, C ABI and Python. Six compiler configurations pass 36
  native programs, two examples, the C caller and 3,423 Python tests; one-thread
  OpenBLAS also passes. Native memory/overflow gates, 752 combined ABI/package/
  float32 ASan and UBSan cases, fpm and 362 isolated-install package tests pass.
  See `validation/float32-linalg-2026-10-27.json` and
  `performance/float32-linalg-2026-10-27/README.md`. Single-precision solve accuracy
  differences from NumPy's widened path are explicit; mixed-dtype linalg remains
  outside this slice. No merge, release tag or package publication performed.

- 2026-10-27: float32 dot/outer implemented at `37cc4fe`, with sanitizer target
  wiring corrected at `85566f8`. Fixed pairwise float32 dot accumulation has
  explicit cancellation, IEEE and signed-zero limits. Six compiler configurations
  and one-thread OpenBLAS pass 37 native programs, two examples, the C caller
  and 3,861 Python tests. GNU 14 memory/overflow gates, 1,190 combined sanitizer
  tests under each sanitizer, fpm and 364 installed-package tests pass.
  See `validation/float32-products-2026-10-27.json` and
  `performance/float32-products-2026-10-27/README.md`. Mixed-dtype products and
  float32 norms remain separate. No merge, release tag or publication performed.

- 2026-10-27: floating-result promotion for dot, outer and matmul at `02aa4df`.
  All 16 ordered floating-result pairs work through native, C and Python; casts
  precede computation. Integral-only products and mixed solve remain unsupported.
  Six compiler profiles pass 4,262 tests plus the final package smoke separately;
  one-thread OpenBLAS passes all 4,263. The 38 native programs, C caller, fpm,
  memory/overflow gates, 1,592 combined tests under each of ASan/UBSan and 365
  isolated-install tests pass. See `validation/product-promotion-2026-10-27.json`
  and `performance/product-promotion-2026-10-27/README.md` for conversion-cost
  benchmarks and limitations. No merge, release tag or publication performed.
