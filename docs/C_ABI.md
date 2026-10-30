# C ABI version 1

`include/frumpy.h` is the complete public C declaration surface. Build with
`make shared`; link against `build/libfrumpy.so`. `make c-test` runs a real C
caller. The ABI exposes fixed-width integers, doubles and opaque positive int64
handles, never a Fortran descriptor or compiler-specific memory layout.

## Ownership and threading

Every successful creation or result call returns one owned handle reference.
`frumpy_retain` adds a reference; `frumpy_release` removes one. Release every
reference, including views and generators. Zero is not a valid handle. IDs are
process-local, never reused, and cannot be serialized between processes.
Released, unknown, zero and wrong-kind handles return status 8. A view retains
its native backing independently of its parent's handle.

**Serialize all calls to a loaded library instance**, including reads, retain,
release and generator calls. The registry and backing reference counts are not
atomic. The Python wrapper supplies a process-local lock. Handles must not be
shared between independently loaded library instances. Forked processes should
create their own arrays rather than relying on inherited handles.

Imports copy a caller buffer in C logical order into owned native storage in
requested C/F order. Exports copy the logical values into a C-order caller
buffer. Buffer counts are exact element counts, not capacities. No caller buffer
is retained. Boolean input is one byte per value, any nonzero byte is true;
exports normalize it to 0 or 1. Other values use native-endian fixed-width types.

Pointer arguments must refer to correctly aligned, accessible buffers of the
stated size and type. Null metadata/data pointers are allowed only for zero
lengths; scalar shapes have length zero but scalar data has one element. Output
handle pointers and scalar metadata outputs must be nonnull. The ABI checks
null pointers, counts and shapes; it cannot validate arbitrary C pointer extent
or detect overlapping caller buffers. Do not alias output handle or metadata
buffers with input buffers.

Custom Fortran adapters called through ctypes must follow the
[native descriptor migration rules](STORAGE_LIFETIME.md#migrating-native-and-ctypes-adapters).
Never manually deallocate a managed descriptor's `data` pointer; use its
`release()` method or procedure-exit finalization. The published handle API does
not expose those pointers. Native descriptor release is idempotent; C handle
release consumes a reference and returns status 8 after the final reference is gone.

## Metadata and errors

`frumpy_info` returns strides in **elements** and a **zero-based** storage
offset. Flags are bit 1 C contiguous, bit 2 F contiguous, bit 4 owns data.
Shape/stride capacity must be at least rank; maximum rank is 32. Metadata is a
snapshot, not a pointer to mutable native descriptors.

Each call returns a status; failed handle-producing calls set `*out = 0` when
that pointer is valid. Status values are 0 success, 1 invalid shape/argument,
2 invalid axis, 3 allocation failure, 4 overflow, 5 unsupported dtype,
6 unsupported behavior, 7 singular matrix, 8 invalid handle. There is no global
last-error buffer. Existing arrays remain usable after reported errors.
Assignment stages all source values before writing; identical-handle assignment
is a no-op. Generator state validation is transactional.

## Dispatch contract

The enums in the header select operations; unsupported enum values are errors.
Array-pair arithmetic and comparison use native promotion. Cast destination
dtype is explicit; casting modes 0–4 are no/equiv/safe/same_kind/unsafe.
Reductions take a has-axis flag, optional axis and keepdims flag. Negative
reduction axes normalize at the boundary. Other native axis restrictions remain;
Python normalizes axes before calling. All flags accept only 0 or 1.

Views have the parameter layouts documented in the header. Slice triples are
already normalized, strict native bounds; the C API does not clip Python slices.
Reshape is C-contiguous-only and does not infer dimensions. Copy order A/K uses
the bounded native policy. Norm calls take zero axes for defaults, one for a
vector axis, or two for matrix axes. Matrix norms are Frobenius; vector norms
are Euclidean. Dot/outer/matmul promote registered pairs to float32 or float64
and convert inputs before computation; integral-only products are unsupported.
Solve requires matching float32 or float64 inputs. Norms accept float32 or float64 and preserve input dtype; float32 norms use pairwise
float64 sums of widened squares with a single final rounding.
See [promotion and conversion storage](LINEAR_ALGEBRA.md#floating-result-promotion).

Where, take and joins accept matching value dtypes across all five registered
dtypes; where requires a bool condition. Mixed selection dtypes return status 5.
See [five-dtype selection](SELECTION_DTYPES.md).
`frumpy_mask_select` and `frumpy_assign` support all five dtypes. The additive
ABI v1 symbol `frumpy_mask_assign(target, mask, values)` provides full-shape
boolean-mask assignment with staged values and destination positions. Use a
matching new library with the updated Python binding. See [masking](MASKING_DTYPES.md).
Where, take, joins, sorting, search, mask extraction and assignment retain the
bounded contracts in [SELECTION_SUPPORT.md](SELECTION_SUPPORT.md) and
[ARRAY_OPERATIONS.md](ARRAY_OPERATIONS.md). `frumpy_flatnonzero` takes bool.
`frumpy_take` takes a rank-one int64 index buffer and explicit axis. Join retains
input descriptors for the duration of its call. Sequence constructors are
float64; arange rejects nonfinite arguments and zero/subnormal steps under the
existing native contract. Linspace follows the native endpoint behavior.

Generators are a separate handle kind. State buffers contain exactly seven
int64 words in the [versioned random format](RANDOM.md). Uniform/normal fill
returns owned float64 arrays. Empty fills consume no state.

## Evidence

`c_tests/test_c_api.c` checks actual C linkage, retain/release, parent-independent
views, metadata and invalid pointers/handles. `python/tests/test_c_boundary.py`
uses ctypes directly (without the package wrapper) to compare all dtype pairs,
views, reductions, numerical and selection dispatch against NumPy and exercise
empty buffers, stale handles and repeated failures.


Handle lookup uses a growing bucket index. IDs remain monotonically assigned and
are never reused; retaining, releasing and view lifetimes keep the same contract.
Growth relinks registry entries without moving their descriptor/storage objects.
If optional index growth cannot allocate, the existing index remains valid and
lookup may be slower. Initial index allocation can return allocation-failed with
an output handle of zero. Index capacity is released when the last handle closes.
The C boundary still requires serialized calls; Python supplies that lock.

On Linux/glibc, `make registry-allocation-test` injects allocation failures into
initial index creation and growth. Run it separately from ASan interposition.
The ordinary C caller also checks growth, retained handles and complete cleanup
under the existing memory test target.

Argmin and argmax now support all five existing dtypes, with int64 indices,
first-occurrence ties and first-NaN selection. See the [index reduction contract](ARG_REDUCTIONS.md).

Stable sort and argsort support all five existing dtypes. See the
[stable sorting contract](STABLE_SORT_DTYPES.md) for ordering, axes and memory costs.

Same-dtype searchsorted supports all five dtypes with int64 results. See the
[searching contract](SEARCHSORTED_DTYPES.md) for ordering, errors and exclusions.

`frumpy_nonzero` returns one owned handle per axis in a caller-supplied buffer,
with rollback of all published outputs on failure. `frumpy_argwhere` returns one
int64 coordinate matrix handle. Both cover all five dtypes; see
[capacity, scalar, and ownership rules](COORDINATES.md). These are additive ABI v1
symbols, requiring the updated library for new bindings.
