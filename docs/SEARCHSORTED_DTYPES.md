# Same-dtype searchsorted

Native `searchsorted(source, values, side_right, status)`, the existing C
`frumpy_searchsorted` entry point, and Python `frumpy.searchsorted(source,
values, side='left')` accept matching bool, int32, int64, float32 or float64
inputs. Native `searchsorted_r64` remains available. This is an additive dtype
extension with no C signature or ABI-version change.

Source must be a sorted one-dimensional array. Queries can have any shape,
including scalar and empty. The result is an owned C-order int64 ndarray with
the query shape; scalar queries produce rank-zero Frumpy arrays, not Python
integers. Use `.item()` when a Python integer is needed. Inputs remain unchanged
and results survive releasing both inputs.

Left insertion returns the first position where a query could be inserted;
right insertion returns the position after existing equal keys. Results range
from zero through source length. An empty source returns zero for every query.
No source sortedness scan is performed: supplying correctly ordered input is
the caller's responsibility, as for NumPy searchsorted.

Bool orders False before True, interpreting any nonzero native bool byte as
True. Int32/int64 comparisons remain exact without floating conversion. Floating
NaNs form the final equivalence class, and opposite signed zeros compare equal.
Float32 values widen exactly for comparisons; neither source nor query buffers
are copied or cast in full. Signed/zero source strides and C/F, reversed,
stepped or broadcasted query layouts are supported in logical order.

Source and query dtypes must match. Mixed-dtype calls return
`UNSUPPORTED_DTYPE` / Python `TypeError`; there is no implicit promotion.
Python scalars are inferred by the existing `asarray` policy, so explicitly
construct/cast queries when their inferred dtype differs from the source.
A scalar or multidimensional source returns `INVALID_SHAPE` / `ValueError`.
Only `left`/`right` are accepted in Python; the C flag must be zero or one.
Malformed descriptors and output-size overflow return recoverable status.
New-dtype native failures have no output storage and failed C output handles
are zero. Existing compiler-generated allocation limitations still apply.

The four added dtypes share binary-search kernels with overflow-safe midpoint
arithmetic. Float64 retains its existing kernel and direct C dispatch. There
is no full-input temporary; new-dtype output payload is 8 bytes per query plus
small descriptor metadata. Work is O(Q log N), with query offset traversal also
depending on rank. This slice excludes `sorter`, mixed-dtype promotion, complex
inputs, and new ndarray methods.
