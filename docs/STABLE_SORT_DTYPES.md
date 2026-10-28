# Stable sorting across five dtypes

`sort` and `argsort` support bool, int32, int64, float32 and float64 in native
Fortran, C and Python. Sort preserves the input dtype; argsort returns int64
zero-based positions along the selected axis. Native `sort` is a generic over
concrete descriptors; `sort_bool/i32/i64/r32/r64` remain callable directly.
Native `argsort` accepts any supported descriptor; `argsort_r64` remains available.
The existing `frumpy_sort` C ABI now dispatches all five dtypes without a
signature or ABI-version change. Python exposes `frumpy.sort` and `frumpy.argsort`.

Sorting is ascending and stable. Equal keys retain their original order.
Bool orders False before True; any nonzero native bool byte means True, and
sorted bool values are normalized to 0/1. Integers compare exactly, including
adjacent int64 values beyond floating-point precision. Floating NaNs sort last
and retain their relative order. Opposite signed zeros are ties. Float32 sort
gathers original values after comparing keys, preserving signed zeros and NaN
payload bits without casting the result.

The default axis is -1. Positive/negative integer axes are supported. Native/C
sort rejects scalars; argsort accepts scalar axes -1 and 0 and returns `[0]`.
Python now exposes that same scalar argsort behavior (its former axis validator
rejected it). Python `axis=None` retains its existing C-order ravel wrapper;
this may copy noncontiguous input. Native/C have no flatten-axis sentinel.
Empty inputs are valid when the axis is valid. Invalid axes and descriptors
return recoverable status; Python maps these to exceptions.

Both functions allocate independent results and leave inputs unchanged. Sort
uses F order for exclusively F-contiguous inputs, C order otherwise; argsort
uses C order. Signed, zero and irregular strides are supported. Source dtype,
shape/rank, storage and bounds are validated before reading keys.

The existing float64 stable merge kernel is retained. The other dtypes use a
shared index merge sort with insertion runs of 32, stable left-first comparisons,
ordered-run skipping and a lazily allocated merge buffer reused across slices.
There is no conversion of integer keys to floats. Float32 key comparison widens
exactly to float64, while sort copies original float32 values into its result.

For the four new dtypes, argsort allocates its 8N-byte output plus an 8L-byte
index slice and, when merging is needed, another 8L-byte workspace. Sort also
uses a full 8N-byte argsort temporary plus its dtype-sized output. N is total
input elements and L the axis length; metadata adds small overhead. Full-input
value packing is avoided, but indirect comparisons may cost more than a typed
value-buffer kernel. Workspace/output overflow and explicit allocation failures
return status; failed new-dtype native results have no storage. Existing
compiler-generated allocation limitations remain documented in STORAGE_LIFETIME.md.

This slice does not add searchsorted dtype coverage, selectable sorting
algorithms, complex values, in-place methods or new indexing operations.
