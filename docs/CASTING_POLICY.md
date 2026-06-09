# Frumpy Casting Policy

Frumpy casting answers two separate questions:

1. Is a dtype-to-dtype cast allowed by the selected casting policy?
2. Can this concrete value be converted without overflow or hidden loss?

`frumpy_promotion` decides result dtypes. `frumpy_casting` performs explicit
conversion checks and scalar casts. Keeping those responsibilities separate
prevents math kernels from quietly deciding conversion policy.

## API

| Routine | Purpose |
| --- | --- |
| `can_cast_dtype(source_dtype_id, target_dtype_id, casting)` | Return whether a registered dtype pair is allowed by the selected policy. |
| `require_cast_dtype(source_dtype_id, target_dtype_id, casting, status)` | Return the same boolean and set a recoverable status on rejection. |
| `copy_r64_value(value, status)` | Copy an `r64` scalar without conversion. |
| `cast_bool_to_i32(value, status)` | Convert logical values to `0` or `1`. |
| `cast_i32_to_i64(value, status)` | Widen `i32` to `i64`. |
| `cast_i32_to_r64(value, status)` | Widen `i32` to `r64`. |
| `cast_i64_to_r64(value, status)` | Convert `i64` to `r64` only when the integer is exactly representable. |
| `cast_r32_to_r64(value, status)` | Widen `r32` to `r64`. |
| `cast_i64_to_i32(value, casting, status)` | Narrow integer values only when the policy allows it and the value fits. |
| `cast_r64_to_i32(value, casting, status)` | Convert finite integral `r64` values only when the policy allows it and the value fits. |
| `cast_r64_to_r32(value, casting, status)` | Narrow real values only when the policy allows it and the value is exactly representable. |

The public casting policy constants are:

| Constant | NumPy casting mode |
| --- | --- |
| `FRUMPY_CASTING_NO` | `no` |
| `FRUMPY_CASTING_EQUIV` | `equiv` |
| `FRUMPY_CASTING_SAFE` | `safe` |
| `FRUMPY_CASTING_SAME_KIND` | `same_kind` |
| `FRUMPY_CASTING_UNSAFE` | `unsafe` |

When `casting` is omitted, Frumpy uses `FRUMPY_CASTING_SAFE`.

## Dtype Policy

This matrix was checked against NumPy `2.4.6` using `np.can_cast`.

| Casting | Source | Allowed targets |
| --- | --- | --- |
| `no` | `bool` | `bool` |
| `no` | `i32` | `i32` |
| `no` | `i64` | `i64` |
| `no` | `r32` | `r32` |
| `no` | `r64` | `r64` |
| `equiv` | `bool` | `bool` |
| `equiv` | `i32` | `i32` |
| `equiv` | `i64` | `i64` |
| `equiv` | `r32` | `r32` |
| `equiv` | `r64` | `r64` |
| `safe` | `bool` | `bool`, `i32`, `i64`, `r32`, `r64` |
| `safe` | `i32` | `i32`, `i64`, `r64` |
| `safe` | `i64` | `i64`, `r64` |
| `safe` | `r32` | `r32`, `r64` |
| `safe` | `r64` | `r64` |
| `same_kind` | `bool` | `bool`, `i32`, `i64`, `r32`, `r64` |
| `same_kind` | `i32` | `i32`, `i64`, `r32`, `r64` |
| `same_kind` | `i64` | `i32`, `i64`, `r32`, `r64` |
| `same_kind` | `r32` | `r32`, `r64` |
| `same_kind` | `r64` | `r32`, `r64` |
| `unsafe` | any registered dtype | any registered dtype |

Unknown dtype IDs are never allowed, including under `FRUMPY_CASTING_UNSAFE`.

## Status Policy

`require_cast_dtype` sets:

| Condition | Status |
| --- | --- |
| Cast allowed | `FRUMPY_STATUS_OK` |
| Unknown source or target dtype | `FRUMPY_STATUS_UNSUPPORTED_DTYPE` |
| Registered pair rejected by policy | `FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR` |

Scalar cast routines set:

| Condition | Status |
| --- | --- |
| Value converted exactly or widened | `FRUMPY_STATUS_OK` |
| Value outside target range | `FRUMPY_STATUS_OVERFLOW` |
| Integer-to-real precision loss | `FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR` |
| Non-finite real-to-integer or real narrowing input | `FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR` |
| Fractional real-to-integer input | `FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR` |
| Precision-losing `r64` to `r32` input | `FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR` |
| Pair rejected by dtype policy | `FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR` |

Narrowing kernels return the target type's zero value when status reports a
failure. Callers must inspect `frumpy_status` before using the returned value.

## NumPy Boundary

`can_cast_dtype` intentionally follows NumPy's dtype-level `can_cast` behavior
for the registered dtype subset.

The scalar kernels are stricter than NumPy's dtype-level policy for value-level
conversion. NumPy can truncate or lose precision under `casting="unsafe"`, and
some dtype-level safe casts can still lose scalar precision for particular
values. Frumpy does not silently overflow, truncate fractional values, round
large `i64` values into `r64`, or lose `r64` to `r32` precision in these scalar
kernels. A future API may add an explicit loss-accepting operation, but it must
still make that choice visible to callers.

## Current Scope

This package does not add concrete non-`r64` array descriptors or storage. It
adds the casting policy and scalar conversion building blocks that later
descriptor work can call.
