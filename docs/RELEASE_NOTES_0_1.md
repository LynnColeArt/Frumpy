# Frumpy v0.1.0

Frumpy 0.1 establishes a usable CPU array subset for Fortran and Python, with
an explicit C ABI. It is not a drop-in NumPy replacement or a claim of full
Array API conformance. This MIT-licensed release ships a Linux source package;
portable binary wheels are not included.

## Included

- Managed bool/int32/int64/float32/float64 storage, shared backing, scalar and
  empty arrays, C/F order, signed/zero-stride views and trailing broadcasting.
- Constructors, copies, array casts, comparisons, boolean logic, all-pair mixed
  arithmetic, float unary kernels, integer/float reductions and boolean all/any.
- Float64 mask extraction, staged basic-view assignment, take/where/joins, and
  bool flat nonzero. Stable sort/argsort, same-dtype searchsorted, and argmin/argmax
  cover all five dtypes, including exact int64 comparisons and irregular layouts.
- Float32 and float64 dot/outer, Euclidean/Frobenius norms, finite matmul and
  broadcast batched solve. Dot/outer/matmul also support mixed pairs whose
  promoted result is floating point. Explicitly seeded float64 uniform/normal
  generation has a versioned state contract.
- ABI-v1 opaque process-local handles, copied import/export, status returns and
  native dispatch; Python ndarray package with deterministic release and
  parent-independent views; Linux source builds.

The [coverage table](V0_1_COVERAGE.md) maps operations, dtypes and regression
checks. The [release checklist](V0_1_CHECKLIST.md) records acceptance, and
[compiler evidence](COMPILER_PORTABILITY.md) records the configurations actually
validated.

## Compatibility and numerical limits

The supported dtypes exclude complex, object, strings, datetime and structured
values. Take/where/joins and masked extraction/assignment remain float64, with
bool conditions/masks. Integral-only products and mixed-dtype solve are unsupported.
Searchsorted requires matching source/query dtypes and a sorted rank-one source;
there is no sorter argument. Argmin/argmax, argsort and searchsorted return int64
indices. Unsupported combinations fail explicitly.
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

Float64 norms use scaled accumulation. Float32 norms use pairwise float64
squares and accumulation, then round once to float32, avoiding intermediate
overflow/underflow from naive float32 squaring. Float32 dot uses pairwise
float32 accumulation; cancellation can differ from NumPy. Float32 solve uses
single-precision LAPACK and can be less accurate than NumPy's widened solve path
on ill-conditioned systems. Matmul/solve require finite floating inputs and an
LP64 BLAS/LAPACK backend; integer backend limits, singular systems, byte overflow and unsupported
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
certified for the Linux package. Local wheels depend on host compiler/backend
runtimes; portable binary wheels, other operating systems and architectures
remain future work. The compiler matrix uses GNU 13/14 and Flang 19 with IEEE
semantics, never fast-math.

## Validation and macOS status

[Hosted Linux CI passed on merged main](https://github.com/LynnColeArt/Frumpy/actions/runs/40814365917),
covering GNU 13/14 and Flang 19 debug/release builds, GNU sanitizer and installation
jobs, fpm, and OpenBLAS. Fresh local GNU 14 validation passed 41 native programs,
two examples, 7,349 Python tests and the C ABI caller.

The [independent Mac retest](https://github.com/LynnColeArt/Frumpy/issues/1#issuecomment-6482716949)
passed those checkout tests in debug and optimized builds on macOS 26.5.1 arm64
with GNU Fortran 14.4.0 and Apple's legacy LP64 Accelerate/vecLib libraries.
The Darwin library install name now permits C clients to load outside the
checkout. Portable norm and signed-zero test expectations were corrected.
GNU Fortran 16.1.0 has unresolved managed-descriptor failures on that Mac; use
GNU 14 for the documented experimental checkout build. Mac sanitizer and fpm
coverage remain unverified. The installer deliberately remains Linux-only;
Mac checkout success is not a Mac package-support claim.

## Installation

Install the attached `frumpy-0.1.0.tar.gz` in an isolated Linux environment after
installing GNU Fortran, Make and compatible LP64 BLAS/LAPACK development libraries:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install ./frumpy-0.1.0.tar.gz
```

The locally built library depends on host compiler and BLAS/LAPACK runtimes.
`FC`, `FFLAGS`, and `LINALG_LIBS` can select the documented build settings.
Do not use fast-math. The archive includes the MIT license and package metadata.

## Performance and next steps

This release includes measured improvements to stable sorting, contiguous
arithmetic and reductions, strided traversal, handle lookup, Python dispatch,
mixed-product casting, float32 norms and typed arg-reduction scans. Results
vary with size, layout, backend and allocation cost; this is not a blanket
speed advantage over NumPy. See the [performance reports](PERFORMANCE.md) for
matched before/after measurements and remaining slower cases.

Further work includes broader dtype/indexing/numerical coverage, compiler
portability and distribution. FFT and IO require separate design decisions.
GPU/autograd/ML-framework work remains outside scope.
