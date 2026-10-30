# Nonzero coordinates and argwhere

`nonzero` and `argwhere` accept bool, int32, int64, float32 and float64 arrays.
They test values directly in their input dtype and return zero-based int64
coordinates in C logical order. Zero and either floating signed zero are false;
nonzero integers, infinities, NaNs and nonzero subnormals are true. Noncanonical
native bool payloads use nonzero-as-true semantics.

| Input | `nonzero` | `argwhere` |
| --- | --- | --- |
| Rank R > 0, K nonzero values | R axis vectors, each shape `(K,)` | Matrix shape `(K, R)` |
| Empty or all-zero rank R > 0 | R empty vectors | Shape `(0, R)` |
| Zero scalar | Invalid shape / Python `ValueError` | Shape `(0, 0)` |
| Nonzero scalar, including NaN | Invalid shape / Python `ValueError` | Shape `(1, 0)` |

These scalar rules match NumPy 2.4.6. Frumpy's rank limit remains 32. C/F order,
reversals, steps, transposes and zero-stride native descriptors are supported.
Coordinates describe the logical view, not offsets into its backing storage.
Result storage is independent of source storage and remains valid after source
release. Existing bool-only `flatnonzero` and native `nonzero_bool` keep their
flat-index contracts; their dtype scope is unchanged.

## Native Fortran

```fortran
use frumpy, only: ndarray_i64, frumpy_status, nonzero, argwhere, release_nonzero
! source is a descriptor of any registered dtype.
type(ndarray_i64), allocatable :: axes(:)
type(ndarray_i64) :: rows
type(frumpy_status) :: status

call nonzero(source, axes, status)
! Check status before using axes; axes(1) describes zero-based axis 0.
call release_nonzero(axes)
rows = argwhere(source, status)
```

`nonzero` is a subroutine returning a descriptor container, not a function returning
an intrinsically copied array of descriptors. Every axis is a contiguous view into
one independent managed coordinate allocation; axis descriptors keep that storage
alive and cover disjoint ranges. `argwhere` returns an owned C-order matrix.

**Call `release_nonzero(axes)` when done**, including before scope exit. It releases
each element and deallocates the container, and is safe for an unallocated container.
Fortran scalar finalization alone does not manage descriptor-array elements under
this library's ownership contract. Never intrinsically copy these containers.
Retain individual axes with `%share_from`, or use the existing explicit descriptor
sharing helpers. See [storage ownership](STORAGE_LIFETIME.md).

On a reported failure, native `nonzero` preserves any existing output container.
On success it releases old axes and transfers the complete new container. The
source must not be an element of that same output container; use a separately
retained descriptor for that case. `argwhere` failures return an empty descriptor
without storage. Both APIs accept optional status. Explicit allocation failures
have status paths; existing compiler-generated temporary-allocation limitations
remain.

## C ABI v1

Two additive entry points are declared in `include/frumpy.h`:

```c
int32_t frumpy_nonzero(frumpy_handle source, frumpy_handle *out, int32_t capacity);
int32_t frumpy_argwhere(frumpy_handle source, frumpy_handle *out);
```

For `nonzero`, obtain source rank with `frumpy_info`, or supply a 32-handle buffer.
Capacity must be between source rank and 32. Rank-zero sources are rejected.
Success publishes one handle per axis in the first R slots and zeroes unused
slots. Release each returned handle individually; releasing one axis does not
invalidate another. The array containing the handle integers belongs to the caller.

A valid non-null output buffer with capacity 0..32 is cleared before validation;
on any reported error it remains clear. Invalid capacities (<0 or >32) and null
pointers return status 1 without touching memory. If publication fails partway
through a tuple, all earlier handles are released and outputs are cleared.
`argwhere` follows the standard single-output rule: a valid output slot is cleared
on failure. Errors include invalid shape (1), allocation failure (3), result-byte
overflow (4), unsupported native dtype (5), and invalid handle (8).

The ABI version and existing symbols are unchanged. New bindings require a library
that exports the two new symbols; existing compiled C clients stay compatible.

## Python

`fp.nonzero(a)` and `a.nonzero()` return a tuple of Frumpy int64 arrays.
`fp.argwhere(a)` returns one Frumpy int64 array. The tuple's axis arrays share an
independent coordinate backing allocation, not the input. Close each array when
explicit lifetime control is desired; Python finalizers also release handles.
`argwhere` is a coordinate table and does not add advanced-indexing support.

## Validation and cost

`test_coordinates` checks native order, scalar/empty shapes, retained-axis lifetime,
container reuse and failure preservation across five dtypes. The Python differential
suite covers native execution, direct C and public Python, rank limits, nonfinite
truth, irregular layouts, invalid capacities/handles and source release. The
installed-package gate exercises the tuple and matrix APIs. The Linux registry
allocation probe fails the second tuple handle allocation to verify rollback after
one successful publication, then verifies recovery.

The implementation scans twice: once to count and once to emit coordinates. Storage
is O(K * R) int64 values plus O(R) axis descriptors for `nonzero`. It avoids a cast
or flattened input copy. Result byte counts are checked before allocation. This
slice prioritizes semantics and ownership; no optimized scan speed is promised.
