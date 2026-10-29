# After v0.1: performance and broader NumPy coverage

This plan starts when the [v0.1 checklist](V0_1_CHECKLIST.md) passes. It preserves the long-term
[PROJECT_PLAN.md](../PROJECT_PLAN.md) scope without allowing that scope to move the v0.1 finish line.
The order below is a dependency sequence, not a calendar estimate.

## 1. Optimize the supported release surface

Use the frozen Fortran/Python baseline to rank costs by workload, size, dtype,
layout and allocation count. Compare equivalent NumPy behavior, compiler flags
and BLAS thread counts; separate Python dispatch, allocation, copying and kernel
time. Include small latency-bound arrays and large bandwidth-bound arrays.

The frozen [v0.1 baseline](PERFORMANCE.md#v01-frozen-baseline--2026-10-26)
sets the first experiment queue:

1. Completed 2026-10-27: stable merge sorting with small insertion runs and lazy
   workspace; NaN/signed-zero ordering and argsort stability preserved. See the
   [before/after evidence](performance/sort-2026-10-27/README.md). Keep these
   workloads as regression cases, including small and already-sorted inputs.
2. Completed 2026-10-27: same-dtype floating contiguous arithmetic and selected
   contiguous reductions, preserving accumulation order. See the
   [before/after evidence](performance/contiguous-2026-10-27/README.md).
   Follow-up completed: uniform signed-step arithmetic resolves the stride-2
   regression for those layouts; general nonuniform traversal remains separate.
   See [the follow-up evidence](performance/strides-2026-10-27/README.md).
3. Completed 2026-10-27: handle indexing and initialized-FFI dispatch, with
   repeated measurements from zero to 8,192 other live arrays, growth failure
   recovery, and explicit small-call/memory tradeoffs.
4. Completed 2026-10-27: nonuniform floating row traversal and matched reference
   BLAS/OpenBLAS packing experiments. C/F rank-two inputs avoid packing; portable
   NN kernels remain after rejecting a reference-backend regression. See the
   [queue report](performance/queue-2026-10-27/README.md) for measurements,
   validation and explicitly deferred work. Backend defaults remain unchanged.

Each optimization needs a before/after benchmark, unchanged differential and
lifetime results, and evidence on strided as well as contiguous cases. Keep a
correct fallback. Define regression thresholds from observed run-to-run noise;
do not promise a universal speedup or choose SIMD/thread strategies beforehand.
Exit: measured bottlenecks addressed or explicitly deferred with evidence, and
repeatable performance checks for the supported release surface.

## 2. Expand numeric and array coverage

Use the v0.1 coverage table to select small releases, not blanket parity claims:

- Completed 2026-10-27: float32 matmul/solve across native, C and Python, with
  single-precision backend semantics, six-compiler validation and matched-backend
  benchmarks. See [the report](performance/float32-linalg-2026-10-27/README.md).
  Float32 dot/outer are also completed with pairwise float32 dot accumulation;
  [their report](performance/float32-products-2026-10-27/README.md) records the
  accuracy and performance tradeoffs. Floating-result dtype promotion for matmul/dot/outer is now implemented; float32 Euclidean/Frobenius norms are also implemented with pairwise float64 sums of widened squares and float32 results.
- Complex64/complex128 descriptors, storage, casting, promotion, arithmetic and
  conjugation, followed by complex reductions and linear algebra.
- Remaining constructors, integer unary operations, multi-axis reductions,
  richer reduction options. Argmin/argmax are now implemented across all five
  dtypes and native/C/Python interfaces; see [the contract](ARG_REDUCTIONS.md).
- Stable sort/argsort across the five existing dtypes are completed; see
  [the sorting contract](STABLE_SORT_DTYPES.md). Same-dtype searchsorted is also
  complete across all five dtypes; see [searching](SEARCHSORTED_DTYPES.md).
  Same-dtype where/take/concatenate/stack and full-shape boolean extraction,
  basic-view assignment and boolean-mask assignment now cover all five dtypes.
  Remaining work includes advanced integer indexing, prefix masks, assignment
  casting and full nonzero tuples. Specify repeated-index assignment first.
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
