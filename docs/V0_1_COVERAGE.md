# v0.1 operation and dtype coverage

This is the bounded public release surface. “All” means bool/int32/int64/
float32/float64, not every NumPy dtype. Unsupported combinations raise or return
a recoverable status; no operation falls back to NumPy execution. Native names
use suffixes `_bool`, `_i32`, `_i64`, `_r32`, `_r64` where concrete.

| Operation | Input dtypes | Fortran API | Python API | Regression evidence |
| --- | --- | --- | --- | --- |
| Owned constructors/import/copy | All | `empty/zeros/ones/full/asarray/copy/ascontiguousarray_*` | same names, plus `array` | `test_constructors_*`, differential `dtype_constructors`, package constructors |
| Sequences | float64 | `arange_r64`, `linspace_r64` | `arange`, `linspace` | `test_constructors_r64`, ABI sequences |
| Metadata views/basic slices | All | `reshape/transpose/swapaxes/squeeze/expand_dims/slice/ravel/flatten_*` | same names/methods; `a[...]` | `test_views_*`, differential `dtype_views`, package views |
| Add/subtract/multiply/divide | All ordered pairs; bool subtraction excluded | mixed `add/subtract/multiply/divide`; concrete numeric functions | functions and operators | `test_arithmetic`, differential `numpy_mixed`, ABI/package all pairs |
| Array casting | All 25 pairs | `astype(source,result,casting,status)` | `a.astype(dtype,casting=...)` | `test_array_casting`, differential `astype`, ABI/package casts |
| Comparisons | All ordered pairs | `equal/not_equal/less/less_equal/greater/greater_equal` | functions and operators | `test_comparisons`, differential `comparisons`, ABI/package pairs |
| Logical and/or/xor/not | bool | `logical_*_bool` | `logical_*`, `&`, `|`, `^`, `~` | `test_comparisons`, differential `logical_bool`, ABI/package bool |
| Negate/abs/sqrt/exp/log/sin/cos | float32/float64 | `negate/abs/sqrt/exp/log/sin/cos_*` | `negative/absolute/sqrt/exp/log/sin/cos`, `-`, `abs` | `test_elementwise_r32/r64`, differential unary, ABI unary |
| Sum/prod/min/max/mean | int32/int64/float32/float64 | concrete `sum/prod/min/max/mean_*` | functions and methods | `test_reductions_*`, differential discrete/float reductions, ABI/package reductions |
| All/any | bool | `all_bool`, `any_bool` | functions and methods | `test_reductions_discrete`, differential `bool_reductions`, ABI/package |
| Full-shape mask extraction | float64 plus bool mask | `mask_select_r64` | `a[mask]` | `test_indexing_r64`, differential `mask_select`, ABI/package selection |
| Basic-view assignment | float64 target and RHS | `assign_r64` | `a[basic_key] = values` | `test_indexing_r64`, differential `numpy_assign`, package alias/error tests |
| Broadcast selection | bool condition, float64 branches | `where_r64` | `where` | `test_selection_r64`, differential selection, ABI/package |
| Gather | float64 plus rank-one int64 indices | `take_r64` | `take` | `test_selection_r64`, differential selection, ABI/package |
| Join | float64 | `concatenate_r64`, `stack_r64` | `concatenate`, `stack` | `test_selection_r64`, differential selection, ABI/package |
| Stable sort/indices | float64, indices return int64 | `sort_r64`, `argsort_r64` | `sort`, `argsort` | `test_sorting_r64`, differential sort, ABI/package |
| Ordered search | float64, returns int64 | `searchsorted_r64` | `searchsorted` | `test_searching_r64`, differential search, ABI/package |
| Flat nonzero | bool, returns int64 | `nonzero_bool` | `flatnonzero` | `test_selection_r64`, differential selection, ABI/package |
| Outer/dot | same-dtype float32/float64 | `outer_r32/r64`, `dot_r32/r64` | `outer`, `dot` | `test_products_r32`, `test_linalg_r64`, differential/ABI/package products |
| Matmul/solve | same-dtype finite float32/float64, LP64 backend | `matmul_r32/r64`, `solve_r32/r64` | `matmul`, `@`, `linalg.solve` | `test_linalg_r32/r64`, differential matmul/solve, `test_float32_linalg`, ABI/package |
| Euclidean/Frobenius norms | float64 | `vector_norm_r64`, `matrix_norm_r64` | `linalg.vector_norm/matrix_norm` | `test_linalg_r64`, differential norms, ABI/package |
| Uniform/standard normal | float64 output | explicit `random_generator`, `uniform_r64`, `normal_r64` | `random.default_rng`, `Generator.random/standard_normal/state` | `test_random`, differential random, ABI/package state tests |
| Lifetime/status/metadata | All | descriptors, status, explicit sharing/release | ndarray metadata, `close`, context manager | `test_storage_lifetime_*`, C caller, package lifetime |

Files live under `test/`, `c_tests/`, and `python/tests/`. The executable native
oracle bridge is `python/fortran/differential_driver.f90`; its Python oracle
checks are in `test_frumpy_differential.py`. `test_c_boundary.py` exercises C
symbols directly, and `test_package.py` exercises the public Python wrapper.
The [C header](../include/frumpy.h) maps each operation group to a dispatch enum
or named entry point; all declared functions have test coverage. Metadata-only
Fortran descriptor/broadcast/dtype-policy utilities remain native APIs, tested
in their respective unit programs, not Python array execution fallbacks.

## Result types and restrictions

Integer sum/prod returns int64 with modular payload overflow. Integer min/max
preserves width; integer mean returns float64. Float reductions preserve width.
Comparisons and logic return normalized bool. Integer/bool true division returns
float64. Mixed arithmetic uses the published promotion table. Python scalar
strength is defined in [PYTHON.md](PYTHON.md), separately from array-pair rules.

All-axis or one-axis reductions support keepdims, not tuple axes. Native
float64 reductions retain nonnegative explicit-axis rules (including rejection
of explicit axes on scalars); Python/C normalize negative nonscalar axes.
Reshape remains a C-contiguous view; Python can infer one dimension. Transpose
reverses all axes. Native slices use strict normalized bounds; Python clips.
Empty mean is NaN without native warnings. Empty reductions, floating-point
rounding and casting departures are detailed in [ARRAY_OPERATIONS.md](ARRAY_OPERATIONS.md),
[FLOAT32_REDUCTIONS.md](FLOAT32_REDUCTIONS.md), and [DTYPE_SUPPORT.md](DTYPE_SUPPORT.md).

Copy/order policies are in [CONSTRUCTORS_AND_VIEWS.md](CONSTRUCTORS_AND_VIEWS.md).
Backend/rank/finite-input limits are in [LINEAR_ALGEBRA.md](LINEAR_ALGEBRA.md).
Selection details are in [SELECTION_SUPPORT.md](SELECTION_SUPPORT.md).
Random reproducibility is in [RANDOM.md](RANDOM.md). Container-copy and compiler
allocation limitations are in [STORAGE_LIFETIME.md](STORAGE_LIFETIME.md).

No complex/object/string/time dtypes, arbitrary advanced indices, boolean
assignment, integer unary kernels, float32 norms, multi-axis reduction
tuples, FFT, GPU, autograd, zero-copy Python interchange or broad Array API
conformance are implied. These remain post-v0.1 work.
