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
| Partial array support | A bounded set of concrete operations is supported; other dtype operations remain absent. |
| Foundation support | The dtype has stable IDs, metadata, policy, or descriptors, but not full array operations. |
| Unsupported | The dtype is intentionally absent from the registered core surface and callers must treat it as unsupported. |

## Current Dtype Matrix

| Dtype | ID | Bytes | Level | Current behavior |
| --- | --- | ---: | --- | --- |
| `bool` | `FRUMPY_DTYPE_BOOL` | 1 | Foundation support | Registered metadata, NumPy-checked promotion policy, dtype-level casting policy, selected scalar casts, and concrete descriptor/storage metadata. Boolean conditions for float64 where and flat nonzero indices; no general bool arithmetic/reduction kernels yet. |
| `i32` | `FRUMPY_DTYPE_I32` | 4 | Foundation support | Registered metadata, NumPy-checked promotion policy, dtype-level casting policy, selected scalar casts, and concrete descriptor/storage metadata. No i32 array kernels yet. |
| `i64` | `FRUMPY_DTYPE_I64` | 8 | Foundation support | Registered metadata, NumPy-checked promotion policy, dtype-level casting policy, selected scalar casts, and concrete descriptor/storage metadata. Index outputs for argsort, searchsorted, and flat nonzero; no general i64 value kernels yet. |
| `r32` | `FRUMPY_DTYPE_R32` | 4 | Partial array support | Registered metadata, NumPy-checked promotion policy, dtype-level casting policy, selected scalar casts, and concrete descriptor/storage metadata. Float32 add, subtract, multiply, and divide with broadcasting and signed strides. |
| `r64` | `FRUMPY_DTYPE_R64` | 8 | Full current array support | Concrete descriptor/storage metadata, constructors, broadcasting, elementwise kernels, reductions, views, promotion policy, and casting policy. |

The `frumpy_dtypes` support state remains conservative: only `r64` reports
`FRUMPY_DTYPE_SUPPORT_SUPPORTED`. Non-`r64` dtypes are registered and useful for
policy, descriptors, and the bounded operations listed above. They still report
planned broad support; this legacy flag is not per-operation capability discovery.

## Implemented r64 Array Behavior

The current `r64` path includes:

| Area | Public surface |
| --- | --- |
| Descriptor | `ndarray_r64`, `owned_descriptor_r64`, `metadata_descriptor_r64`, `view_descriptor_r64` |
| Constructors and copies | `empty_r64`, `zeros_r64`, `ones_r64`, `full_r64`, `arange_r64`, `linspace_r64`, `asarray_r64`, `copy_r64`, `ascontiguousarray_r64` |
| Broadcasting | `broadcast_plan_r64`, `broadcast_plan` |
| Elementwise kernels | `add_r64`, `subtract_r64`, `multiply_r64`, `divide_r64`, `negate_r64`, `abs_r64`, `sqrt_r64`, `sin_r64`, `cos_r64`, `exp_r64`, `log_r64` |
| Reductions | `sum_r64`, `prod_r64`, `mean_r64`, `min_r64`, `max_r64` |
| Selection and ordering | `where_r64`, `take_r64`, `concatenate_r64`, `stack_r64`, `sort_r64`, `argsort_r64`, `searchsorted_r64`, `nonzero_bool` (flat indices) |
| Views and slicing | `reshape_r64`, `ravel_r64`, `flatten_r64`, `transpose_r64`, `swapaxes_r64`, `squeeze_r64`, `expand_dims_r64`, `slice_r64` |

This is not full NumPy. See [selection support](SELECTION_SUPPORT.md) for the
bounded indexing/ordering contract. Advanced indexing, linear algebra, random
generation, FFTs, Python bindings, and C ABI work remain outside the current
implementation.

All five registered descriptors use managed backing storage. Views and explicit
sharing retain that storage; release and finalization drop references. This does
not add missing dtype kernels. See [storage lifetime](STORAGE_LIFETIME.md) for
the required explicit-sharing APIs and restrictions on Fortran container copies.

## Float32 Binary Arithmetic

`add_r32`, `subtract_r32`, `multiply_r32`, and `divide_r32` accept two
`ndarray_r32` operands and return an independent C-order float32 array. Create
inputs with `owned_descriptor_r32` and access their float32 payload through
`data`. `view_descriptor_r32` supplies explicit shape/stride views.

The kernels use the same metadata broadcast planner as float64. They support
rank-zero operands, trailing-dimension broadcasting, empty arrays, C/F-order
inputs, transpose/reverse views, stepped slices, and zero strides. Both inputs
remain float32; there is no implicit mixed-dtype conversion or new promotion
policy. NaNs, infinities, signed zero, overflow and division by zero follow the
host IEEE floating-point arithmetic. No NumPy-style warning channel is provided;
explicitly enabling compiler floating-point traps can change that behavior.

Inputs with missing storage return `FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR`.
Malformed metadata, inaccessible offsets/strides and incompatible shapes return
`FRUMPY_STATUS_INVALID_SHAPE`. Explicit allocation errors have status paths,
subject to the compiler temporary-allocation limits in the lifetime contract.

There are no float32 unary kernels, reductions, selection routines, convenience
constructors, or mixed-dtype execution yet. The 48 compiled NumPy cases in
`test_frumpy_differential.py` check all four operations, including exact float32
results and signed zeros. `test/test_elementwise_r32.f90` checks ownership,
result lifetime, and malformed input status paths.

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

These descriptor APIs do not themselves add NumPy convenience constructors,
reductions, view helpers, or mixed-dtype execution. Float32 binary arithmetic is
the separate bounded kernel surface described above. The selection subset consumes
boolean conditions and produces int64 indices without adding general dtype
execution.

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
