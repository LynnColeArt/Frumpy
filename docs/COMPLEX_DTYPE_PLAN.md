# Complex Dtype Plan

Complex dtype support is intentionally not implemented yet.

Frumpy should not add complex arrays as an ad hoc special case. Complex numbers
touch dtype IDs, byte sizes, storage layout, promotion, casting, scalar kernels,
array kernels, and eventual interop boundaries. This plan defines the work that
must happen before complex support becomes user-visible.

## Candidate Dtypes

| Candidate | Expected byte size | Candidate Fortran storage | Notes |
| --- | ---: | --- | --- |
| `c64` | 8 | `complex(real32)` | NumPy `complex64`, represented as two 32-bit real components. |
| `c128` | 16 | `complex(real64)` | NumPy `complex128`, represented as two 64-bit real components. |

These IDs are not registered in `frumpy_dtypes` yet. A future mission should add
them only with tests for metadata, promotion, casting, descriptors, and NumPy
differential fixtures.

Before any ABI or Python binding work relies on complex storage, verify the
compiler layout assumptions explicitly. Fortran complex storage is the natural
implementation candidate, but Frumpy should not assume C/Python ABI layout
without a dedicated interop decision.

## Required Promotion Work

A complex implementation mission must add NumPy differential fixtures for:

- `np.promote_types` across `bool`, `i32`, `i64`, `r32`, `r64`, `c64`, and
  `c128`.
- `np.result_type` for scalar-like array and scalar combinations.
- Symmetry of dtype-pair promotion.
- Unknown or unsupported dtype status behavior.

Do not guess the final table from intuition. NumPy integer, real, and complex
promotion has enough edge cases that the fixtures should be written first and
the Fortran table should follow them.

The likely policy shape is:

- `c64` with `c64` promotes to `c64`.
- `c128` with any complex dtype promotes to `c128`.
- Real-plus-complex promotion preserves enough real precision to avoid hidden
  loss.
- Integer-plus-complex promotion must be checked against NumPy before coding.

The last two bullets are intentionally not a final table. They are constraints
for the future NumPy-oracle tests.

## Required Casting Work

Complex casting needs both dtype-level policy and value-level conversion rules.

The dtype-level matrix should be checked against NumPy `np.can_cast` for:

- `no`
- `equiv`
- `safe`
- `same_kind`
- `unsafe`

The scalar conversion policy should stay Frumpy-strict:

- Real-to-complex widening may be allowed when the real value is exactly
  representable in the target real component.
- Complex-to-real conversion must reject nonzero imaginary components unless a
  future loss-accepting API explicitly opts in.
- `c128` to `c64` must reject values that would overflow or lose precision under
  the checked scalar conversion API.
- Non-finite real or imaginary components need explicit status behavior.

Failures should return `frumpy_status`; core library code should not use
`error stop`.

## Descriptor Work

Complex descriptors should follow the concrete descriptor pattern already used
for `r64`, `r32`, `i32`, `i64`, and `bool`:

- Private-by-default module.
- Explicit dtype ID.
- Rank, shape, strides, offset, ownership, and contiguity metadata.
- Owned, metadata-only, and view descriptor constructors.
- Tests for scalar, empty, C-order, Fortran-order, metadata-only, view sharing,
  invalid shapes, rank mismatch, invalid offset, and unsupported order.

Do not introduce a generic dtype descriptor machine before the concrete complex
modules prove what should actually be shared.

## Kernel Work

Complex array kernels should not land until promotion and casting policy is
centralized and tested.

The first useful kernel subset should probably be small:

- Copy and constructor helpers.
- Addition, subtraction, multiplication, and division.
- Unary conjugate or absolute value only after NumPy behavior is pinned.
- Reductions only after empty-array and identity behavior is documented.

Every complex kernel must preserve shape, stride, offset, ownership, and
contiguity expectations.

## Non-Goals For First Complex Mission

The first complex dtype mission should not include:

- Object dtype.
- Python packaging.
- C ABI guarantees.
- BLAS/LAPACK complex linear algebra.
- FFTs.
- GPU runtime design.
- Autograd or Torch compatibility.

Those can come later if Frumpy's NumPy-compatible core earns them.
