# Frumpy 0.1 release candidate

Frumpy 0.1 establishes a usable CPU array subset for Fortran and Python, with
an explicit C ABI. It is not a drop-in NumPy replacement or a claim of full
Array API conformance. Publishing and tagging are separate from candidate
preparation.

## Included

- Managed bool/int32/int64/float32/float64 storage, shared backing, scalar and
  empty arrays, C/F order, signed/zero-stride views and trailing broadcasting.
- Constructors, copies, array casts, comparisons, boolean logic, all-pair mixed
  arithmetic, float unary kernels, integer/float reductions and boolean all/any.
- Float64 mask extraction and staged basic-view assignment, take/where/joins,
  stable sorting, argsort, ordered search and bool flat nonzero.
- Float64 outer/dot, scaled Euclidean/Frobenius norms, finite matmul and broadcast
  batched solve, plus explicitly seeded uniform/normal generation.
- ABI-v1 opaque process-local handles, copied import/export, status returns and
  native dispatch; Python ndarray package with deterministic release and
  parent-independent views; Linux source builds.

The [coverage table](V0_1_COVERAGE.md) maps operations, dtypes and regression
checks. The [release checklist](V0_1_CHECKLIST.md) records acceptance, and
[compiler evidence](COMPILER_PORTABILITY.md) records the configurations actually
validated.

## Compatibility and numerical limits

The supported dtypes exclude complex, object, strings, datetime and structured
values. Selection and numerical backend operations remain float64, with bool
conditions/masks and int64 indices. Unsupported combinations fail explicitly.
Python scalar promotion is weak for Python bool/int/float and strong for NumPy
scalars; see [PYTHON.md](PYTHON.md).

Reshape requires C-contiguous storage. Copy A/K follows the bounded order policy;
ascontiguousarray always copies and preserves scalar rank. Native slice bounds
must be normalized; Python clips them. Transpose reverses axes. Reductions
support all axes or one axis and keepdims, not arbitrary axis tuples, out,
where or initial. Float64 native reductions reject negative/explicit scalar
axes; boundary normalization supports negative nonscalar axes. NumPy interchange
always copies. General advanced indexing and boolean assignment are absent.

Integer payload arithmetic and sum/prod are explicitly modular. Array casts use
NumPy-style dtype policy but reject nonfinite/out-of-range float-to-integer values
instead of platform-dependent invalid conversion results. Strict scalar casting
remains a separate native API. Integer means use sequential C-order accumulation;
a cancellation-heavy case differs from NumPy's traversal. Empty means return NaN
without NumPy warnings. Float32 reductions use the documented pairwise policy;
other reductions and contractions have their documented rounding-order limits.
Float32 unary tests use a four-ULP finite bound; ordinary float64 comparisons use
operation-specific tolerances, with exact checks where appropriate. See
[ARRAY_OPERATIONS.md](ARRAY_OPERATIONS.md), [FLOAT32_REDUCTIONS.md](FLOAT32_REDUCTIONS.md)
and [DTYPE_SUPPORT.md](DTYPE_SUPPORT.md) for the tests and departures.

Norms use scaled accumulation, intentionally avoiding overflow/underflow from
naive squaring. Matmul/solve require finite float64 input and an LP64 BLAS/LAPACK
backend; integer backend limits, singular systems, byte overflow and unsupported
ranks return status. Solve uses NumPy 2.x RHS semantics: only rank-one RHS is a
vector. Random output uses versioned xoshiro256**/SplitMix64 state and Box-Muller
normals, not NumPy stream identity. Uniform/state replay is exact; normal
cross-library reproducibility is tolerance-based. See [LINEAR_ALGEBRA.md](LINEAR_ALGEBRA.md)
and [RANDOM.md](RANDOM.md).

## Ownership and build limits

C callers serialize every call. The Python package holds a lock around native
entry; reference counts are not atomic. Handles cannot move between processes
or library instances. External C buffers must be valid for their declared sizes.
Fortran borrowed storage still requires caller lifetime management. Intrinsic
copying of descriptor containers is unsupported; use explicit scalar sharing.
Compiler-generated temporary allocation failures remain outside full recoverable
status coverage. See [C_ABI.md](C_ABI.md) and [STORAGE_LIFETIME.md](STORAGE_LIFETIME.md).

The source package requires Linux x86_64, Python 3.10+, NumPy 2.x, Make, a
Fortran 2018 compiler, and LP64 BLAS/LAPACK development libraries. The tested
Python runtime is 3.12; additional Python versions are not independently
certified by this candidate. Local wheels depend on host compiler/backend
runtimes; portable binary wheels, other operating systems and architectures
remain future work. The compiler matrix uses GNU 13/14 and Flang 19 with IEEE
semantics, never fast-math. CI configuration mirrors the local gates; adding it
does not by itself establish a hosted CI run result.

## What follows

The [post-v0.1 plan](POST_V0_1_PLAN.md) begins with measured performance work on
the frozen native/Python baseline. Rank dispatch, allocation, traversal and
backend packing costs by workload before optimizing; retain the differential
and ownership gates. Then expand dtype/numerical coverage and distribution in
separate bounded releases. FFT, IO and broader numerical ecosystem work follow
explicit backend and compatibility decisions. GPU/autograd/ML-framework work
remains outside scope.
