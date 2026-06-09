# Frumpy Dtype Support

This document is the current dtype support map for Frumpy after the dtype
metadata, promotion, casting, and descriptor foundation mission.

Frumpy is still early. A dtype can be registered for metadata and policy without
having full array operations. Treat the tables below as the user-facing support
boundary, not as a roadmap wish list.

## Support Levels

| Level | Meaning |
| --- | --- |
| Full current array support | The dtype has concrete descriptors, storage, constructors or kernels, and regression tests for the listed behavior. |
| Foundation support | The dtype has stable IDs, metadata, policy, or descriptors, but not full array operations. |
| Unsupported | The dtype is intentionally absent from the registered core surface and callers must treat it as unsupported. |

## Current Dtype Matrix

| Dtype | ID | Bytes | Level | Current behavior |
| --- | --- | ---: | --- | --- |
| `bool` | `FRUMPY_DTYPE_BOOL` | 1 | Foundation support | Registered metadata, NumPy-checked promotion policy, dtype-level casting policy, selected scalar casts, and concrete descriptor/storage metadata. No bool array kernels yet. |
| `i32` | `FRUMPY_DTYPE_I32` | 4 | Foundation support | Registered metadata, NumPy-checked promotion policy, dtype-level casting policy, selected scalar casts, and concrete descriptor/storage metadata. No i32 array kernels yet. |
| `i64` | `FRUMPY_DTYPE_I64` | 8 | Foundation support | Registered metadata, NumPy-checked promotion policy, dtype-level casting policy, selected scalar casts, and concrete descriptor/storage metadata. No i64 array kernels yet. |
| `r32` | `FRUMPY_DTYPE_R32` | 4 | Foundation support | Registered metadata, NumPy-checked promotion policy, dtype-level casting policy, selected scalar casts, and concrete descriptor/storage metadata. No r32 array kernels yet. |
| `r64` | `FRUMPY_DTYPE_R64` | 8 | Full current array support | Concrete descriptor/storage metadata, constructors, broadcasting, elementwise kernels, reductions, views, promotion policy, and casting policy. |

The `frumpy_dtypes` support state remains conservative: only `r64` reports
`FRUMPY_DTYPE_SUPPORT_SUPPORTED`. Non-`r64` dtypes are registered and useful for
policy and descriptors, but still report planned support because Frumpy cannot
yet run non-`r64` ndarray kernels.

## Implemented r64 Array Behavior

The current `r64` path includes:

| Area | Public surface |
| --- | --- |
| Descriptor | `ndarray_r64`, `owned_descriptor_r64`, `metadata_descriptor_r64`, `view_descriptor_r64` |
| Constructors and copies | `empty_r64`, `zeros_r64`, `ones_r64`, `full_r64`, `arange_r64`, `linspace_r64`, `asarray_r64`, `copy_r64`, `ascontiguousarray_r64` |
| Broadcasting | `broadcast_plan_r64`, `broadcast_plan` |
| Elementwise kernels | `add_r64`, `subtract_r64`, `multiply_r64`, `divide_r64`, `negate_r64`, `abs_r64`, `sqrt_r64`, `sin_r64`, `cos_r64`, `exp_r64`, `log_r64` |
| Reductions | `sum_r64`, `prod_r64`, `mean_r64`, `min_r64`, `max_r64` |
| Views and slicing | `reshape_r64`, `ravel_r64`, `flatten_r64`, `transpose_r64`, `swapaxes_r64`, `squeeze_r64`, `expand_dims_r64`, `slice_r64` |

This is not full NumPy. Linear algebra, random generation, indexing beyond the
current slice helpers, sorting, searching, FFTs, Python bindings, and C ABI work
remain outside the current implementation.

## Non-r64 Descriptor Foundation

The current non-`r64` descriptor modules are:

| Dtype | Descriptor module | Storage payload |
| --- | --- | --- |
| `bool` | `frumpy_ndarray_bool` | One-byte `integer(int8)` values using `0` and `1` |
| `i32` | `frumpy_ndarray_i32` | `integer(int32)` |
| `i64` | `frumpy_ndarray_i64` | `integer(int64)` |
| `r32` | `frumpy_ndarray_r32` | `real(real32)` |

Each descriptor preserves the same metadata invariants as `ndarray_r64`:

- Rank.
- Shape.
- Strides.
- One-based offset.
- Ownership.
- C-contiguity.
- Fortran-contiguity.
- Copy-vs-view storage sharing.

The non-`r64` descriptor APIs are descriptor foundations only. They do not add
NumPy constructors, elementwise kernels, reductions, view helpers, or mixed-dtype
array execution for those dtypes.

## Promotion

`frumpy_promotion` implements a table-driven dtype promotion policy for the
registered dtype subset:

- `bool`
- `i32`
- `i64`
- `r32`
- `r64`

The supported table was checked against NumPy `2.4.6` with `np.promote_types`.
See `docs/DTYPE_PROMOTION.md` for the pair table and API details.

Promotion does not allocate arrays, convert data, or imply a dtype has array
kernels. It only answers the result dtype question.

## Casting

`frumpy_casting` implements dtype-level cast policy for the registered dtype
subset and selected scalar conversion kernels.

The dtype-level policy was checked against NumPy `2.4.6` with `np.can_cast` for
the modes:

- `no`
- `equiv`
- `safe`
- `same_kind`
- `unsafe`

Frumpy scalar casts are intentionally stricter than NumPy's dtype-level unsafe
casts. They report recoverable status failures instead of silently truncating,
overflowing, or losing precision. See `docs/CASTING_POLICY.md` for the exact
status behavior.

## Unsupported Dtypes

These dtypes are currently unsupported in Frumpy core:

| Dtype family | Current policy |
| --- | --- |
| Object dtype | Intentionally unsupported. Object arrays require Python object identity, reference management, and dynamic dispatch that do not belong in the current Fortran ndarray core. |
| String dtype | Unsupported until a later mission defines encoding, storage, comparison, and NumPy compatibility rules. |
| Datetime and timedelta dtypes | Unsupported until calendar units, casting, arithmetic, and metadata semantics are specified against NumPy. |
| Complex dtypes | Unsupported for now. Candidate IDs, storage, promotion, and casting rules are documented in `docs/COMPLEX_DTYPE_PLAN.md` before implementation. |
| Structured, record, and void dtypes | Unsupported. They require field metadata and memory-layout policy that is outside the current core. |

Unsupported dtype behavior must be visible through `frumpy_status`; library code
should not terminate the process or silently fall back to another dtype.

## Explicit Non-Scope

This dtype support surface does not add Torch compatibility, autograd, Diffusers
support, GPU runtime design, model loading, tokenizers, SciPy replacement work,
or Python packaging. Frumpy remains scoped to NumPy-compatible ndarray behavior.
