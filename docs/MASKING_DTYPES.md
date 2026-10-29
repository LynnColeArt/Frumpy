# Boolean extraction and staged assignment

Bool, int32, int64, float32 and float64 support full-shape boolean extraction,
broadcast assignment through basic views, and boolean-mask assignment. Values
must have exactly the target dtype; mixed assignment and implicit casts are
unsupported. Int64 payloads never pass through floating point. Floating copies
preserve signed zeros and NaN payload bits. Copied bool values normalize to 0/1.

| Native API from `frumpy` | Contract |
| --- | --- |
| `result = mask_select(source, mask, status)` | Boolean mask of exactly the source shape, including scalar/empty shapes. Independent rank-one result, in C logical selection order. |
| `call assign(target, values, status)` | Broadcast values to the target's existing shape. No target expansion, metadata change or replacement storage. |
| `call mask_assign(target, mask, values, status)` | Exact-shape boolean mask. Values must be scalar or rank one, with length one or the number selected. |

Native generic assignment accepts registered descriptors and validates dtype at
runtime. Its descriptor dummies have `intent(in)` because only the pointed-to
payload changes; passing the same descriptor is supported. Legacy `assign_r64`
retains its distinct-descriptor restriction and existing implementation.
Legacy `mask_select_r64` also remains available.

All inputs are validated before writes. RHS payloads are captured before any target
mutation. A single-element RHS is captured in one typed scalar; other values use
a staging array. Mask assignment also snapshots every selected destination, so masks
may share boolean target storage. Reported validation/allocation failures leave
the target unchanged. Explicit allocations have status paths; compiler-generated
temporary allocation limitations still apply. For a scalar RHS, basic assignment needs O(1) working storage and masked
assignment needs O(K) int64 positions for K selected entries. Nonscalar basic
assignment stages O(N) values; masked assignment stages O(K) values and positions. Extraction allocates only its result after counting selected entries.

C/F-contiguous, reversed, stepped, transposed and zero-stride descriptors are
supported. Repeated destination positions are written in C logical order, with
the last selected write winning. Constant fills may visit contiguous F-order
storage in physical order because all writes use the same captured value. A
uniform zero-stride constant fill writes once, even for huge logical shapes
that previously exceeded staging-byte limits. Empty selections still validate RHS rank,
dtype and length: scalar, length-one and length-zero values are valid.

## NumPy correspondence and intentional boundaries

For supported non-overlapping inputs, results match NumPy. Frumpy snapshots the
RHS and mask before writing even if they alias the target. NumPy 2.4.6 can consume
an aliased RHS while overwriting it during boolean assignment; for example,
`a[all_true_mask] = a[::-1]` need not reverse the original values. Frumpy guarantees
the snapshot result, equivalent to using independent RHS and mask copies. This
extends its existing staged basic-assignment contract. Tests
`test_overlap_and_atomic_errors`, `test_boolean_mask_alias`, and the native
`test_indexing_dtypes` lock in that decision.

Masks must match the whole shape: no prefix-mask broadcasting or scalar mask
indexing into higher-rank arrays. Python recognizes Frumpy mask arrays and NumPy
boolean ndarrays; boolean lists, tuples and bare Python/NumPy bool scalars are
outside this interface. Use a rank-zero boolean ndarray for a scalar target.
Multidimensional integer indexing, mixed value dtypes and assignment casting
remain separate work. Leading singleton RHS dimensions that increase basic
assignment rank are rejected under the existing bounded broadcast contract.

## C and Python

C ABI v1 retains `frumpy_mask_select(source, mask, out)` and
`frumpy_assign(target, values)` and adds
`frumpy_mask_assign(target, mask, values)`. Output handles are cleared on extraction
failure. Status 1 means invalid shape/rank, 3 allocation failure, 4 overflow,
5 unsupported dtype and 8 invalid handle. Ordinary identical-handle C assignment
retains its no-allocation no-op shortcut; masked identical handles are validated
and staged normally. The updated Python binding requires the new library symbol;
existing compiled C clients remain compatible.

Python uses `a[mask]`, `a[basic_slice] = values`, and `a[mask] = values`.
Scalar dtype inference is unchanged: for int32 targets, use `np.int32(1)` rather
than a Python integer. Errors propagate as Python exceptions; target storage stays
unchanged. Extraction remains valid after all inputs are closed. Assigning through
a view updates its shared backing storage.

## Validation

`test_indexing_dtypes` covers native sharing, extraction lifetime, reversed RHS,
identical descriptors, malformed metadata and repeated destinations across all
five dtypes. `test_mask_dtypes.py` compares native driver results, direct C calls
and Python behavior against NumPy and snapshot-based overlap expectations.
Installed-package regressions exercise extraction lifetime and both assignment
forms. These tests are included in the full suite and native/C memory gates.

Scalar fill performance and before/after evidence are recorded in
[the focused optimization report](performance/scalar-assignment-2026-10-29/README.md).
