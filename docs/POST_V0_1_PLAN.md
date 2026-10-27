# After v0.1: performance and broader NumPy coverage

This plan starts when the [v0.1 checklist](V0_1_CHECKLIST.md) passes. It preserves the long-term
[PROJECT_PLAN.md](../PROJECT_PLAN.md) scope without allowing that scope to move the v0.1 finish line.
The order below is a dependency sequence, not a calendar estimate.

## 1. Optimize the supported release surface

Use the frozen Fortran/Python baseline to rank costs by workload, size, dtype,
layout and allocation count. Compare equivalent NumPy behavior, compiler flags
and BLAS thread counts; separate Python dispatch, allocation, copying and kernel
time. Include small latency-bound arrays and large bandwidth-bound arrays.

Investigate in measured order:

1. Repeated allocation and descriptor/dispatch overhead.
2. Contiguous elementwise/reduction loops, stride traversal, vectorization.
3. Avoidable matrix packing and backend copies for compatible layouts.
4. BLAS implementation/thread configuration and, only where justified, OpenMP.

Each optimization needs a before/after benchmark, unchanged differential and
lifetime results, and evidence on strided as well as contiguous cases. Keep a
correct fallback. Define regression thresholds from observed run-to-run noise;
do not promise a universal speedup or choose SIMD/thread strategies beforehand.
Exit: measured bottlenecks addressed or explicitly deferred with evidence, and
repeatable performance checks for the supported release surface.

## 2. Expand numeric and array coverage

Use the v0.1 coverage table to select small releases, not blanket parity claims:

- Float32 linear algebra, then dtype-promotion-aware matmul/dot/outer.
- Complex64/complex128 descriptors, storage, casting, promotion, arithmetic and
  conjugation, followed by complex reductions and linear algebra.
- Remaining constructors, integer unary operations, multi-axis reductions,
  argmin/argmax and richer reduction options.
- Selection/sorting/searching across dtypes, advanced integer indexing, boolean
  assignment and full nonzero tuples. Specify repeated-index assignment first.
- Broader norms and selected factorizations (QR, Cholesky, SVD/eigen), with
  singular/ill-conditioned cases and backend variability documented.

Exit for each slice: named API/dtype/shape contract, NumPy differential tests,
error/lifetime coverage and a benchmark added where runtime costs change.

## 3. Distribution and interoperability

Build on the C ABI and Linux source package: binary wheels, additional operating
systems/architectures and compilers, backend ABI validation, and explicit
zero-copy NumPy/buffer interchange. Decide ABI compatibility and deprecation
policy before distributing shared libraries broadly. Test ownership across
language boundaries and installation on each claimed platform.

Exit: installable artifacts and smoke/differential tests on every claimed target;
no inferred portability from a successful Linux build.

## 4. Broader numerical ecosystem surface

- Expand random distributions and state interoperability only under a specified
  reproducibility/versioning policy.
- Decide FFT backend, dtype/normalization/axis contracts and dependencies before
  implementing a bounded FFT surface.
- Decide array serialization and text/binary IO formats, byte-order handling and
  round-trip/error contracts before implementation.
- Reassess string, datetime/timedelta and structured dtypes as separate designs.
  Object arrays remain outside the native numeric core unless scope is explicitly
  changed; none of these dtypes is silently promised by the NumPy-compatible name.

## How we keep the rest finite

At each release, choose a written API subset from this backlog, list exclusions,
and gate it with the coverage matrix, differential tests, lifetime checks and
performance regression evidence. Newly discovered features go into the next
release unless they are needed for the current contract's correctness.

Full NumPy parity has no completion date in this plan. Torch, autograd, GPU
runtimes and SciPy replacement remain outside Frumpy's present scope.
