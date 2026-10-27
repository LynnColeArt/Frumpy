# Float64 linear algebra

`outer_r64(lhs, rhs, status)`, `matmul_r64(lhs, rhs, status)` and
`solve_r64(lhs, rhs, status)` accept
`ndarray_r64` descriptors and return independent, managed, C-order float64
results. `status` is optional. Inputs retain their values and metadata.

```fortran
product = matmul_r64(a, b, status)
solution = solve_r64(a, rhs, status)
```

## Outer product

`outer_r64` follows NumPy `outer`: flatten both operands in C logical order,
then return shape `[lhs.size(), rhs.size()]`. Scalars have one element; an empty
operand produces an empty rank-two result. C/F layouts, transposes, stepped,
negative and zero strides are read directly. Inputs are not flattened into
work buffers; only the independent result payload is allocated.

This native float64 multiplication kernel accepts NaNs and infinities, follows
IEEE arithmetic (including signed zeros), and has no BLAS int32 dimension limit.
Element and byte counts are checked for int64 overflow before output allocation.
An empty result returns without traversing either operand. Floating-point traps
and fast-math are outside the tested contract; there is no NumPy warning channel.
The 51 `test_numpy_outer_r64` / `test_numpy_outer_extremes` cases check values,
shapes, layouts, nonfinite values, overflow/underflow and signed zeros against
NumPy. Fortran invariants additionally check lifetime and malformed inputs,
plus element/byte overflow and huge empty shapes without huge allocations.

## Dot product

`dot_r64(lhs, rhs, status)` accepts float64 descriptors and returns an independent
C-order result. A scalar operand multiplies the other input elementwise. Otherwise
it contracts the last left dimension against the only right dimension for a vector,
or the second-last right dimension for a higher-rank array. The result shape is
`lhs.shape[:-1] + rhs.shape[:-2] + rhs.shape[-1:]` for a matrix-or-higher RHS,
and `lhs.shape[:-1]` for a vector RHS. Leading dimensions concatenate; they do
not broadcast as in matmul. Empty contractions produce positive zeros.

The native loop reads signed/zero strides without input copies, uses sequential
float64 multiply/add accumulation, and accepts IEEE nonfinite values. It has no
BLAS int32 core-dimension limit. Output rank is bounded by FRUMPY_MAX_RANK and
result element/byte counts are checked before allocation. Numerical comparisons
use rtol=atol=2e-13; accumulation order may differ from NumPy, and signed zeros in
contracted results are not guaranteed bitwise identical. Scalar multiplication
preserves the ordinary IEEE multiply result. Failures return no storage.

## Euclidean and Frobenius norms

`vector_norm_r64(source, axis0, keepdims, status)` reduces one axis, or flattens
all axes when axis0 is absent. A scalar without axis0 returns its absolute value;
a scalar with an explicit axis is invalid. `matrix_norm_r64(source, axes0,
keepdims, status)` computes Frobenius norms over two distinct axes, defaulting
to the final two dimensions. Rank must be at least two. Negative axes and
keepdims are supported. Other norm orders are outside this release's contract.

These native float64 kernels traverse metadata without input copies. Output is
independent and C-order. Empty reductions are zero, NaN dominates infinity, and
infinity dominates finite magnitudes. A scaled sum of squares avoids premature
overflow/underflow. This deliberately improves on NumPy's direct squaring for
extreme finite values: [3e300,4e300] gives 5e300, and [3e-300,4e-300] gives 5e-300.
Tests compare ordinary cases to NumPy and extreme cases to widened NumPy
arithmetic. The ordinary regression tolerance is rtol=2e-15, atol=1e-15 (zero
absolute tolerance for extreme values), not a universal accuracy bound. Invalid
or repeated axes return INVALID_AXIS; malformed source metadata is rejected
before payload access. Failed calls return no storage.

## Matrix multiplication

`matmul_r64` implements NumPy's vector and matrix shape rules:

- A vector times a vector produces a rank-zero descriptor.
- A matrix times a vector, or a vector times a matrix, produces a vector.
- Higher-rank inputs use their last two dimensions as matrix dimensions;
  leading dimensions broadcast using the existing metadata planner.
- Rank-zero operands and unequal contracted dimensions are invalid shapes.
- Empty outputs are supported. A zero-length contracted dimension produces zeros,
  including a zero-length vector dot product, whose scalar result is zero.

The kernel traverses C/F-order arrays, transposes, reversed/stepped views, and
zero strides through their metadata. When both rank-two inputs are C-contiguous,
`DGEMM` computes the transposed product directly into the C-order result, without
packing inputs or allocating an output work buffer. When both are F-contiguous,
inputs are also read directly, but an output work buffer is copied into C order.
Actual shape/strides determine eligibility; offsets and singleton dimensions are
honored, and finite-input checks remain in place.

Mixed layouts, vectors, irregular views and batches use reusable column-major
input and output work arrays. Packing does not alter the input descriptors.
The normal (NN) backend call is retained for these paths: an experiment using
transposed DGEMM calls to remove the output buffer substantially regressed
reference BLAS. Numerical results remain governed by the backend tolerance
contract, rather than a bitwise accumulation-order promise.

## Linear solve

`solve_r64` solves `A X = B`, with square final two dimensions of A. Only a
rank-one B denotes a vector; every higher-rank B denotes matrices in its final
two dimensions, matching NumPy 2.x. Leading A/B dimensions broadcast. Output
has the broadcast batch shape followed by `[n]` for vector B or `[n,nrhs]` for
matrix B. Incompatible core or batch dimensions return INVALID_SHAPE.
Empty batches return without factorization. Signed/zero batch and core strides
are supported, and one set of workspace buffers is reused across batches.
If any batch is singular or nonfinite, the whole result is discarded and sources
remain unchanged, even if earlier batches succeeded.

LAPACK `DGESV` factors A with pivoting and overwrites its coefficient and RHS
work arrays. Frumpy therefore packs both inputs into separate work arrays and
copies the solution into owned C-order storage. A zero-order system returns an
empty result. When A has positive order and B has zero columns, factorization
still runs: singularity is reported even though X is empty, matching NumPy 2.4.6.
A dummy zero-filled workspace column forces factorization even on backends that
return early for zero RHS columns; the public output still has zero columns.
A detected singular matrix returns `FRUMPY_STATUS_SINGULAR_MATRIX` (code 7).
Singularity follows the backend's zero-pivot test; no condition estimator is run.

The backend interfaces follow Netlib's documented
[DGEMM](https://netlib.org/lapack/explore-html/dd/d09/group__gemm_ga1e899f8453bcbfde78e91a86a2dab984.html)
and [DGESV](https://netlib.org/lapack/explore-html/d8/da6/group__gesv_ga831ce6a40e7fd16295752d18aed2d541.html)
contracts. They are isolated in `frumpy_linalg_backend`.

## Supported numerical and ABI contract

Matmul and solve currently require finite values in every input block they read.
NumPy permits non-finite operands and may return NaN/infinity; Frumpy explicitly
reports `FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR` for those inputs. This bounded
contract avoids depending on backend-specific NaN handling and pivot selection.
Vacuously empty operations do not read input values. The intentional restriction
is covered by `test_linalg_nonfinite_explicitly_unsupported`.

Finite inputs can still overflow or underflow during computation; intermediate
or result values are not guaranteed finite. Floating-point traps and fast-math
are outside the tested contract. BLAS accumulation order and LAPACK/backend
choices can change rounding. The finite comparison corpus uses `rtol=2e-13` and
`atol=2e-13`; this is a regression tolerance, not a global error bound or a
bitwise guarantee. Signed-zero output bits are not specified for these kernels.

The matmul/solve backend interface requires conventional LP64 Fortran BLAS/LAPACK: signed int32
dimensions and pivots, real64 double precision, and compatible Fortran symbol
and character calling conventions. ILP64 backends are unsupported. Core dimensions
are limited to int32 range, even for empty operations. Work-array and result
byte counts are checked for int64 overflow before allocation; array shapes,
offsets and strides remain int64. Larger virtual arrays that NumPy can represent
may therefore receive `FRUMPY_STATUS_OVERFLOW` here.

## Build and validation

Install a compatible BLAS/LAPACK development package, then build normally. Make
links with `LINALG_LIBS ?= -llapack -lblas`; fpm declares the same libraries.
Override the Make variable when selecting a compatible vendor backend:

```sh
make validate LINALG_LIBS='-llapack -lblas'
```

On the tested Linux host, only versioned runtime library links were installed.
The validation matrix used the system reference BLAS/LAPACK 3.12.0 with:

```sh
make validate LINALG_LIBS='-l:liblapack.so.3 -l:libblas.so.3'
```

The `-l:` spelling is a GNU/Linux linker option, not a portable default. Compiler
matrix logs record the selected link flags. Alternative backends and platforms
need their own ABI and numerical checks; no automatic backend selection is added.

The 126 compiled NumPy comparisons cover vector/matrix/batch promotion,
broadcasting, layouts, empty dimensions, finite numerical results and residuals,
pivoting, singular matrices, and shape errors. Tests also make the unsupported
non-finite contracts explicit. `test/test_linalg_r64.f90` checks
input preservation, independent owned results, lifetime, status omission,
malformed metadata, and backend/workspace/output overflow guards without huge
allocations. Both GNU memory and integer-overflow gates include these checks.
The backend shared libraries themselves are not rebuilt with sanitizers.

## Failure statuses

Failed functions return descriptors without storage, including when status is
omitted. Explicit allocations have status paths, subject to the existing
[compiler allocation limits](STORAGE_LIFETIME.md).

| Failure | Status |
| --- | --- |
| Missing source storage or non-finite matmul/solve values | `FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR` |
| Invalid rank/shape/strides/offset, unreachable storage, or incompatible dimensions | `FRUMPY_STATUS_INVALID_SHAPE` |
| Forged input dtype metadata | `FRUMPY_STATUS_UNSUPPORTED_DTYPE` |
| LP64 dimension or byte-count overflow | `FRUMPY_STATUS_OVERFLOW` |
| Explicit allocation failure | `FRUMPY_STATUS_ALLOCATION_FAILED` |
| Singular coefficient matrix | `FRUMPY_STATUS_SINGULAR_MATRIX` |

Mixed-dtype linear algebra, other factorizations and Python/C bindings remain
outside this numerical slice. [Random generation](RANDOM.md) has a separate contract.


OpenBLAS 0.3.26 LP64 pthread was additionally validated on this Linux host with
GNU 14 release and one thread. The full differential suite includes singular
empty-RHS solves. CI now includes a separate LP64 OpenBLAS job. Backend choice
remains a build/runtime configuration; this does not change Frumpy's defaults.
