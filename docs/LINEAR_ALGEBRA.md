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
zero strides through their metadata. Each batch is packed into column-major
work arrays for BLAS `DGEMM`; the same work arrays are reused across batches.
Packing is part of this arithmetic API and does not alter the input descriptors.
The completed batch is copied into the result's C-order payload. This first
adapter also packs contiguous inputs; no zero-copy backend fast path is claimed.

## Linear solve

`solve_r64` solves `A X = B`, with a square rank-two A and either a rank-one or
rank-two B. The first dimension of B must match A. X has the same shape as B.
Batched solves are explicitly unsupported in this slice.

LAPACK `DGESV` factors A with pivoting and overwrites its coefficient and RHS
work arrays. Frumpy therefore packs both inputs into separate work arrays and
copies the solution into owned C-order storage. A zero-order system returns an
empty result. When A has positive order and B has zero columns, factorization
still runs: singularity is reported even though X is empty, matching NumPy 2.4.6.
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
batched-solve/non-finite contracts explicit. `test/test_linalg_r64.f90` checks
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
| Missing source storage, non-finite matmul/solve values, or batched solve | `FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR` |
| Invalid rank/shape/strides/offset, unreachable storage, or incompatible dimensions | `FRUMPY_STATUS_INVALID_SHAPE` |
| Forged input dtype metadata | `FRUMPY_STATUS_UNSUPPORTED_DTYPE` |
| LP64 dimension or byte-count overflow | `FRUMPY_STATUS_OVERFLOW` |
| Explicit allocation failure | `FRUMPY_STATUS_ALLOCATION_FAILED` |
| Singular coefficient matrix | `FRUMPY_STATUS_SINGULAR_MATRIX` |

This slice does not add mixed-dtype linear algebra, standalone `dot`,
other factorizations, norms, random generation, or Python/C bindings.
