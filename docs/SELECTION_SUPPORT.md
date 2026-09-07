# Selection, Sorting, and Searching

The current surface operates on float64 (`r64`) arrays, with boolean masks and
int64 index outputs. These functions allocate independent results; none returns
a view. Input shape, rank, and reachable storage bounds are validated before
reading data. Invalid input returns `frumpy_status` rather than terminating the
caller. Bounds checks include signed-stride and element-count overflow cases.

## Supported operations

| API | NumPy behavior and current subset |
| --- | --- |
| `where_r64(condition, lhs, rhs)` | Three-array `np.where`: trailing-dimension broadcasting, including scalars and zero extents. The condition is `ndarray_bool`; both value arrays are `ndarray_r64`. |
| `take_r64(source, indices, axis0)` | `np.take` with a one-dimensional Fortran int64 index vector. Omitting `axis0` indexes the logical C-order flattening. Explicit positive or negative axes select a dimension. Negative indices wrap once; out-of-bounds indices return invalid-shape status. Scalar sources accept axis 0 or -1. |
| `concatenate_r64(arrays, axis0)` | Join one or more arrays along an existing axis, default 0. Ranks and all other dimensions must match. Positive and negative axes are supported. Scalar inputs are rejected. |
| `stack_r64(arrays, axis0)` | Join one or more equal-shaped arrays along a new axis, default 0. Positive and negative axes and scalar sources are supported. |
| `sort_r64(source, axis0)` | Ascending, stable sorting along an axis, default -1. NaNs follow finite values and infinities. Scalars return invalid-axis status. |
| `argsort_r64(source, axis0)` | Stable, zero-based int64 indices along an axis, default -1. Matches `np.argsort(..., kind="stable")`. Scalar input returns `[0]` for axis -1 or 0 and rejects other axes. |
| `searchsorted_r64(source, values, side_right)` | A sorted one-dimensional float64 source and arbitrarily shaped float64 queries. Default left insertion; `side_right=.true.` selects right insertion. NaNs form the final equivalence class. Output shape matches the queries. |
| `nonzero_bool(source)` | **Flat indices**, matching `np.flatnonzero`, in logical C order. Despite the name, this does not return NumPy `nonzero`'s tuple of coordinate arrays. Scalars produce `[0]` or an empty vector. |

All accept C-order, Fortran-order, transposed, stepped, reversed, and zero-stride
inputs. Empty inputs are supported when the operation's shape/axis rules allow
them. `take` does not materialize a flattened copy of its source.

`where`, `take`, `stack`, and the index outputs use C-contiguous output storage.
`concatenate` preserves Fortran order when all sources are F-contiguous and at
least one is not also C-contiguous; otherwise it allocates C order. `sort` uses
Fortran order for an exclusively F-contiguous source and C order otherwise.
These are explicit layout policies; matching NumPy values does not promise
identical output strides for every arbitrary strided input.

## Changes from the unfinished implementation

- Omitting `axis0` in `take_r64` now means flatten first, as in NumPy. Callers that
  relied on the old default must pass `axis0=0_int32` explicitly.
- Selection accepts negative axes, and `stack` accepts non-C-contiguous inputs.
- Broadcasting zero with one preserves the zero extent.
- Sorting and searching use NumPy's NaN ordering; scalar argsort validates axes.
- Malformed descriptors return invalid-shape status, including bounds arithmetic
  that would otherwise overflow or read outside the backing buffer.

## Explicit limits

This is a bounded subset of NumPy's indexing surface. Multidimensional index
arrays, advanced indexing, boolean gather/scatter, indexed assignment, `out`,
`take` modes `clip`/`wrap`, join `axis=None`, sort `axis=None`, selectable sort
algorithms, and searchsorted's `sorter` argument are not exposed. `searchsorted`
expects an already sorted source, just as the corresponding NumPy call does;
it does not scan for sortedness before each binary search.

Sorting currently uses stable insertion sort, with quadratic worst-case time
per axis slice. No large-array performance claim is made. Non-float64 value
kernels and mixed-dtype array execution remain separate work. Float64 results
now use managed shared storage; see [storage lifetime](STORAGE_LIFETIME.md) for
supported assignment/release operations and container-copy limits. Index and
boolean descriptors still require explicit caller lifetime management.

## Verification

`python/tests/test_frumpy_differential.py` sends input metadata and storage to
`python/fortran/differential_driver.f90`, executes Frumpy, reconstructs actual
outputs from their shape/strides, and compares them with NumPy. Cases include
both memory orders, negative and zero strides, empty arrays, scalars, repeated
values, NaNs, infinities, invalid axes, and seeded three-dimensional inputs.
It also checks output ownership/contiguity and float64 result independence.
The original constructor → broadcast → reshape → reduction demo runs through
the same compiled bridge.

`test/test_selection_validation.f90` checks malformed descriptors in both input
positions, including missing metadata, invalid rank/shape, out-of-bounds offsets,
and extreme signed strides. The standalone selection/sorting/searching tests
remain part of `make test`.

The bridge is test infrastructure, not a C ABI or Python package. Existing
`test_numpy_*.py` files remain reference fixtures; only the compiled differential
suite executes Frumpy alongside the oracle.
