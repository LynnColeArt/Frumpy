# Constructors and views across the five dtypes

Each of bool, i32, i64, r32 and r64 has concrete `empty_*`, `zeros_*`, `ones_*`,
`full_*`, `asarray_*`, `copy_*` and `ascontiguousarray_*` entry points, exported
by `frumpy`. Inputs and results retain the named dtype. Float64 alone has arange
and linspace in v0.1. There is no implicit cast in a concrete constructor.

`asarray_*(values, shape, order, status)` copies a one-dimensional Fortran value
buffer interpreted in C logical order. Shape is optional and defaults to a vector
of the same length. Fortran boolean arguments are logical values; bool descriptors
store normalized int8 bytes. Full/zeros/ones likewise normalize boolean payloads.
Empty leaves payload values unspecified. Scalar shape is a zero-length int64
shape vector, and zero extents produce allocated empty descriptors.

Creation order accepts C or F, default C. Copy accepts C/F/A/K, default C; A/K
select F only for exclusively F-contiguous sources and otherwise select C. This
bounded K behavior is an intentional departure from NumPy's general stride-order
preservation. `ascontiguousarray_*` always makes an independent C-order copy and
preserves scalar rank, matching the preexisting Frumpy float64 API. NumPy can
reuse a contiguous input and promotes a scalar to rank one; those behaviors are
not claimed here. `asarray_*` is buffer import, not a descriptor aliasing API.

The new bool/i32/i64/r32 constructors validate source dtype, rank, shape/stride
bounds and byte counts before copying. Invalid shapes return INVALID_SHAPE,
unsupported order returns UNSUPPORTED_BEHAVIOR, forged dtype returns
UNSUPPORTED_DTYPE, and size/byte overflow returns OVERFLOW. Failed new
constructors return no storage, including when status is omitted. The existing
compiler-generated metadata-allocation limitations still apply.

## Views

All five concrete types export reshape, ravel, flatten, transpose, swapaxes,
squeeze, expand_dims and slice with the same bounded contract:

- Reshape is a view for C-contiguous inputs and matching nonnegative target
  shapes. Non-C sources are explicitly unsupported; no implicit reshape copy or
  inferred -1 extent is claimed.
- Ravel returns a view for C-contiguous inputs and a C-logical copy otherwise.
  Flatten always returns an owned independent C-logical vector.
- Transpose reverses all axes. Swapaxes exchanges two specified axes.
- Squeeze removes all singleton dimensions or one specified singleton axis.
- Expand_dims inserts a singleton dimension, represented with stride zero.
- Slice requires one `slice_spec` per source axis. Use `slice_all()` or
  `slice_range(start0, stop0, step)` with explicit, already-normalized bounds.
  Negative steps are supported. Python-style clipping and omitted bounds belong
  to the future Python boundary; native slice bounds are validated strictly.
- Explicit view axes are nonnegative, zero-based. Negative axis aliases are not
  accepted by this native subset. Norm/reduction axis contracts are separate.

Metadata-only plans are shared, while each concrete wrapper retains its own
storage type. Views survive release of the source descriptor, and mutation
through a view reaches shared backing. Plans validate reachable signed strides
and never touch payload. Empty slices retain a valid source offset without
calculating an inaccessible conceptual start. Slice lengths handle extreme
signed steps without overflowing; unrepresentable stride products return
OVERFLOW. Malformed input metadata is rejected before planning or payload access.

Result shape/strides, offset and contiguity are recomputed. Views do not own new
payload; flatten and noncontiguous ravel do. No wrapper creates a float64 proxy
buffer for another dtype.

## Evidence

`test_constructors_dtypes.f90` and `test_views_dtypes.f90` exercise all four added
dtypes, C/F ordering, independent copies, aliasing, mutation, source release,
invalid metadata and extreme slicing. The original `test_views_r64.f90` still
checks the same float64 contract after the common metadata planner was introduced.

`test_numpy_dtype_constructors` checks values, dtypes, layouts, scalar/empty
shapes and unsupported creation orders. `test_numpy_dtype_views` checks all five
dtypes across eight view/copy operations and eight layouts, including zero and
negative strides. Tests explicitly require Frumpy's declared copy/reshape behavior
where it differs from NumPy. These programs and cases are included in the GNU
memory and overflow gates.
