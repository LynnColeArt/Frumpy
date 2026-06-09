# Frumpy Dtype Metadata

Frumpy keeps dtype identity and support state in `frumpy_dtypes`. This module is
the authoritative registry for dtype IDs, names, byte sizes, support state, and
the status message callers should surface when a dtype is known but not usable
yet.

## Support States

| State | Meaning |
| --- | --- |
| `FRUMPY_DTYPE_SUPPORT_SUPPORTED` | The dtype has working descriptors and kernels in the current tree. |
| `FRUMPY_DTYPE_SUPPORT_PLANNED` | The dtype has stable metadata, but operations must return `FRUMPY_STATUS_UNSUPPORTED_DTYPE`. |
| `FRUMPY_DTYPE_SUPPORT_UNSUPPORTED` | The dtype is not registered and has no operational support. |

## Registered Dtypes

| ID constant | Name | Byte size | Support state | Operational status |
| --- | --- | ---: | --- | --- |
| `FRUMPY_DTYPE_BOOL` | `bool` | 1 | Planned | Metadata and descriptor foundation only. No casting, promotion, or kernels yet. |
| `FRUMPY_DTYPE_I32` | `i32` | 4 | Planned | Metadata and descriptor foundation only. No casting, promotion, or kernels yet. |
| `FRUMPY_DTYPE_I64` | `i64` | 8 | Planned | Metadata and descriptor foundation only. No casting, promotion, or kernels yet. |
| `FRUMPY_DTYPE_R32` | `r32` | 4 | Planned | Metadata and descriptor foundation only. No casting, promotion, or kernels yet. |
| `FRUMPY_DTYPE_R64` | `r64` | 8 | Supported | Backed by the current concrete `r64` array descriptor and kernels. |

`r64` is the only dtype with arithmetic kernels at this point. Planned dtypes
are intentionally visible now so promotion, casting, and descriptor work can
share one source of truth instead of creating competing dtype maps. Promotion
policy is documented separately in `docs/DTYPE_PROMOTION.md`; casting policy is
documented separately in `docs/CASTING_POLICY.md`.

The `bool` descriptor stores payload values as `0`/`1` bytes rather than
default Fortran `logical` values. NumPy bool is a one-byte dtype, while default
Fortran `logical` storage is compiler-dependent and may be wider.

## Status Policy

`dtype_info(dtype_id, status)` returns table metadata for registered planned
dtypes, but sets `status` to `FRUMPY_STATUS_UNSUPPORTED_DTYPE`. The returned
message is dtype-specific, for example:

```text
dtype i32 is planned but not supported yet
```

Unknown dtype IDs return the default unsupported metadata:

```text
name = unsupported
byte_size = 0
support_state = FRUMPY_DTYPE_SUPPORT_UNSUPPORTED
status_message = unknown dtype id
```

## Explicit Non-Scope

NumPy object dtype, string dtype, datetime dtype, and complex dtypes do not have
registered Frumpy IDs yet. They should be treated as unsupported until a later
mission assigns metadata and operational policy for them.

Object dtype is intentionally non-scope for the current Frumpy core. The complex
dtype plan is to document candidate IDs, byte sizes, promotion rules, and casting
rules before adding descriptors or kernels, so complex support does not arrive as
an ad hoc special case.
