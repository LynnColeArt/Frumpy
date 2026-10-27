# Frumpy v0.1 release checklist

Status: in progress. Release scope established on 2026-10-26.

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
- [ ] B2: `dot_r64`, including scalar multiplication and NumPy higher-rank
  contraction rules; do not substitute matmul's batch broadcasting rules.
- [ ] B3: float64 vector Euclidean norm and matrix Frobenius norm, documented
  axis/keepdims subset, scaled accumulation and extreme-value tests.
- [ ] B4: broadcast batched float64 solve, using NumPy 2.x RHS rank semantics;
  retain finite-input, singularity and LP64 limits.
- [ ] B5: explicit seeded generator state with float64 uniform [0,1) and standard
  normal output. Freeze algorithm/state format, reproducibility scope and seed
  mapping; add golden streams, range checks and distribution sanity checks.

Additional dtypes for linear algebra and general factorizations are post-v0.1.

## C. Complete the everyday five-dtype path

- [ ] C1: empty/zeros/ones/full, asarray/copy/ascontiguousarray for all five
  dtypes; retain float64 arange/linspace as the v0.1 sequence constructors.
- [ ] C2: reshape/ravel/flatten/transpose/swapaxes/squeeze/expand_dims/basic
  slicing for all five dtypes, with the same copy/view contract as float64.
- [ ] C3: array `astype` across the five dtypes, explicit casting mode and tested
  conversion semantics; resolve the stricter existing scalar-cast contract
  explicitly rather than silently applying it to NumPy-style array casts.
- [ ] C4: equal/not_equal/less/less_equal/greater/greater_equal with broadcasting
  and mixed numeric dtype handling; boolean logical_and/or/xor/not.
- [ ] C5: boolean all/any; integer sum/prod/min/max/mean with documented NumPy
  accumulator/result dtypes and overflow behavior. Support all-axis and one-axis
  reductions with keepdims, matching the float subset.
- [ ] C6: float64 boolean mask extraction and assignment through basic slices;
  define broadcasting, source/destination aliasing and failure behavior in tests.
  Retain existing float64 take/where/concat/stack/sort/search contracts.

Multi-axis tuples, reduction out/where/initial options, arbitrary advanced index
arrays and full non-float64 selection/sorting are deferred. Python scalar
promotion must be specified at the Python boundary; array-pair promotion alone
is not sufficient evidence for it.

## D. C ABI and Python package

Depends on the storage contract; design can start before B/C are complete.

- [ ] D1: versioned C header with opaque array handles, create/retain/release,
  dtype/shape/stride queries and explicit status/error handling. No exposed
  compiler-specific Fortran layouts. Test ownership from a C caller.
- [ ] D2: owned buffer import/export and operation dispatch for the v0.1 surface.
  Copying imports are acceptable and must be explicit; zero-copy interchange is
  deferred. Test invalid handles/arguments within the documented API contract.
- [ ] D3: installable Python package with ndarray, constructors, arithmetic,
  views/indexing, reductions, selection and numerical calls from B/C; map status
  to exceptions and define Python scalar/coercion behavior.
- [ ] D4: test Python lifetime, aliasing, exception cleanup and round trips with
  NumPy; a Python reference must keep its view's backing alive.
- [ ] D5: reproducible source build/install on Linux x86_64, documented compiler
  and BLAS/LAPACK prerequisites, clean-environment installation smoke test.
  Binary wheels and additional platforms are later release work.

## E. Release acceptance and performance handoff

- [ ] E1: publish an operation-by-dtype coverage table linked to public APIs and
  tests. Audit every v0.1 export against it; no unsupported operation silently
  changes dtype or falls back to NumPy.
- [ ] E2: pass the full compiler matrix and applicable sanitizer gates on the
  release candidate; verify fpm with development libraries installed, as well
  as Make. Automate the supported Linux build and differential checks in CI.
- [ ] E3: end-to-end Fortran and installed-Python examples covering creation,
  views, broadcast mixed arithmetic, reduction, selection, matmul and solve;
  compare results and ownership behavior with the declared NumPy contract.
- [ ] E4: release notes enumerate compatibility departures, build requirements,
  numerical tolerances, backend limits and remaining work. Resolve blockers,
  then prepare the v0.1 release candidate; publishing/tagging is a separate step.
- [ ] E5: capture reproducible performance baselines through both Fortran and
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
