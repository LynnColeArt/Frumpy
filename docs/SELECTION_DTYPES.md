# Five-dtype selection

The native generic functions `where`, `take`, `concatenate`, and `stack` accept
bool, int32, int64, float32 and float64 descriptors. They return the input value
dtype, with independent managed storage. Native `_r64` entry points remain
available and retain their established kernels. The new concrete functions
(`where_i32`, for example) are available from `frumpy_selection`.

This is a same-dtype slice: the two `where` branches must match, and all join
inputs must match. No value promotion or float64 conversion is performed.
Int64 keys beyond 2**53 remain exact; floating copies preserve signed zeros and
NaN payloads. Bool values use nonzero-as-true semantics and new bool results
normalize payloads to 0/1.

| Native API | Contract |
| --- | --- |
| `where(condition, lhs, rhs, status)` | Boolean condition; three-way trailing broadcasting, including scalar and empty dimensions. Only the selected value is copied. |
| `take(source, indices, axis0, status)` | Rank-one int64 index vector; omitted axis indexes C-logical flattening. Explicit negative axes normalize once; scalar source accepts 0/-1. Negative indices wrap once; all indices are bounds-checked even when another output dimension is empty. |
| `concatenate(arrays, axis0, status)` | Nonempty sequence; default axis 0. Equal ranks and all non-axis dimensions must match; scalars are rejected. Axis extents may differ, including zero. |
| `stack(arrays, axis0, status)` | Nonempty sequence of identical shapes, including scalars; default insertion axis 0. Negative insertion axes normalize against result rank. |

`where`, `take` and `stack` allocate C-order results. Concatenate uses F order
when all sources are F-contiguous and at least one is not also C-contiguous;
otherwise it uses C order. Signed, zero, stepped, transposed and F-order inputs
are traversed in logical order. The new kernels derive contiguity from validated
metadata rather than trusting cached flags. No flattened/cast input buffers are
needed by the native kernels. Join borrows metadata during the call; C joins
retain each descriptor explicitly and release every reference after publishing
or discarding the result.

All inputs are validated before copying. Rank, axis, reachable storage, index
bounds, concatenated extent overflow, result element count and byte count have
status paths. Failed native results have no storage; failed C calls clear their
output handle. Explicit allocation failures return allocation status; the
existing limits on compiler-generated temporary allocations still apply.
Results remain valid after releasing all inputs. This does not change intrinsic
Fortran descriptor-container copying restrictions; see [ownership](STORAGE_LIFETIME.md).

## C and Python

The ABI version and signatures are unchanged: `frumpy_where`, `frumpy_take` and
`frumpy_join` now dispatch on the matching dtype. Non-bool conditions and mixed
value dtypes return status 5; Python raises `TypeError`. Null/negative index
buffer arguments and malformed join requests are rejected. An index-buffer byte
count that cannot fit int64 returns overflow before pointer association.

Python exposes `fp.where`, `fp.take`, `fp.concatenate`, and `fp.stack` with the
existing signatures. Scalar operands are independently inferred by `asarray`,
so use explicitly typed scalars when necessary, e.g. `np.int32(0)` alongside
int32 branches. Python `take(axis=None)` retains its existing ravel wrapper
(which may copy an irregular view); the native omitted-axis path does not copy
its source. Python scalar `take` now accepts axes 0/-1, matching native and
NumPy behavior. Scalar concatenation raises `ValueError` before axis handling.

Mixed selection promotion, multidimensional index arrays, take clip/wrap modes,
join `axis=None`, `out`, and additional masking/assignment dtypes are excluded.
Float64 mask extraction, staged assignment, and bool flatnonzero are unchanged.

## Verification

`test_selection_dtypes.f90` checks native dtype/lifetime contracts, malformed
metadata, overflow using huge logical zero-stride borrows, bool normalization,
rank limits and invalid axes/indices. `test_selection_dtypes.py` compares native
results through the differential driver, direct C handles and public Python
views with NumPy, including exact int64 values, floating bit patterns, mixed
dtype rejections, irregular layouts, variable-length joins and input release.
The native memory/overflow gates and C/Python memory gate include these tests.
