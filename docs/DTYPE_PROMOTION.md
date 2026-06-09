# Frumpy Dtype Promotion

Frumpy promotion answers one question: given two dtype IDs, what dtype should a
result use? Promotion does not allocate arrays, convert data, or imply that a
non-`r64` descriptor or kernel exists yet.

The authoritative Fortran API is `frumpy_promotion`. Explicit conversion policy
and scalar casting live in `frumpy_casting` and are documented in
`docs/CASTING_POLICY.md`.

## API

| Routine | Purpose |
| --- | --- |
| `promote_dtypes(lhs_dtype_id, rhs_dtype_id, status)` | Return the promoted result dtype ID for a pair of registered dtype IDs. |
| `promote_scalar_dtype(array_dtype_id, scalar_dtype_id, status)` | Use the same dtype-pair policy for scalar-like inputs. |
| `is_supported_promotion(lhs_dtype_id, rhs_dtype_id)` | Return whether a pair is present in the promotion table. |

Unsupported pairs return `FRUMPY_DTYPE_UNSUPPORTED` and set `status` to
`FRUMPY_STATUS_UNSUPPORTED_DTYPE`.

## Supported Promotion Table

This table was checked against NumPy `2.4.6` using `np.promote_types`.

| Left | Right | Result |
| --- | --- | --- |
| `bool` | `bool` | `bool` |
| `bool` | `i32` | `i32` |
| `bool` | `i64` | `i64` |
| `bool` | `r32` | `r32` |
| `bool` | `r64` | `r64` |
| `i32` | `i32` | `i32` |
| `i32` | `i64` | `i64` |
| `i32` | `r32` | `r64` |
| `i32` | `r64` | `r64` |
| `i64` | `i64` | `i64` |
| `i64` | `r32` | `r64` |
| `i64` | `r64` | `r64` |
| `r32` | `r32` | `r32` |
| `r32` | `r64` | `r64` |
| `r64` | `r64` | `r64` |

The table is symmetric. `i32 + r32` and `r32 + i32` both promote to `r64`,
matching NumPy's dtype-pair result.

## Operational Boundary

Promotion support is not the same as cast support or array operation support. As
of this mission, only `r64` has concrete Frumpy array descriptors and kernels.
The other dtype IDs are visible so casting, promotion, and future descriptors can
share stable metadata without inventing separate maps.

## Unsupported Pairs

Unknown dtype IDs, object dtype, string dtype, datetime dtype, and complex dtypes
are outside this promotion table. Until later missions assign registered Frumpy
IDs and policy for them, callers should treat those pairs as unsupported.

Complex dtype support needs a written plan before implementation because NumPy's
integer, real, and complex promotion interactions are subtle enough to deserve
explicit fixtures.

## Intentional Differences

No intentional differences from NumPy `2.4.6` are documented for the supported
promotion table above.
