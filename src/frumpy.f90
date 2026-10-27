!> Public umbrella module for the current Frumpy core surface.
module frumpy
  use frumpy_constructors_bool, only: empty_bool, zeros_bool, ones_bool, full_bool, &
    asarray_bool, copy_bool, ascontiguousarray_bool
  use frumpy_constructors_i32, only: empty_i32, zeros_i32, ones_i32, full_i32, &
    asarray_i32, copy_i32, ascontiguousarray_i32
  use frumpy_constructors_i64, only: empty_i64, zeros_i64, ones_i64, full_i64, &
    asarray_i64, copy_i64, ascontiguousarray_i64
  use frumpy_constructors_r32, only: empty_r32, zeros_r32, ones_r32, full_r32, &
    asarray_r32, copy_r32, ascontiguousarray_r32
  use frumpy_views_bool, only: reshape_bool, ravel_bool, flatten_bool, transpose_bool, &
    swapaxes_bool, squeeze_bool, expand_dims_bool, slice_bool
  use frumpy_views_i32, only: reshape_i32, ravel_i32, flatten_i32, transpose_i32, &
    swapaxes_i32, squeeze_i32, expand_dims_i32, slice_i32
  use frumpy_views_i64, only: reshape_i64, ravel_i64, flatten_i64, transpose_i64, &
    swapaxes_i64, squeeze_i64, expand_dims_i64, slice_i64
  use frumpy_views_r32, only: reshape_r32, ravel_r32, flatten_r32, transpose_r32, &
    swapaxes_r32, squeeze_r32, expand_dims_r32, slice_r32
  use frumpy_comparisons, only: equal, not_equal, less, less_equal, greater, greater_equal, &
    logical_and_bool, logical_or_bool, logical_xor_bool, logical_not_bool
  use frumpy_reductions_discrete, only: sum_i32, prod_i32, min_i32, max_i32, mean_i32, &
    sum_i64, prod_i64, min_i64, max_i64, mean_i64, all_bool, any_bool
  use frumpy_indexing_r64, only: mask_select_r64, assign_r64
  use frumpy_array_casting, only: astype
  use frumpy_random, only: random_generator, uniform_r64, normal_r64
  use frumpy_norms_r64, only: vector_norm_r64, matrix_norm_r64
  use frumpy_arithmetic, only: add, subtract, multiply, divide
  use frumpy_linalg_r32, only: matmul_r32, solve_r32
  use frumpy_linalg_r64, only: matmul_r64, solve_r64, outer_r64, dot_r64
  use frumpy_constants, only: FRUMPY_ORDER_A, FRUMPY_ORDER_C, FRUMPY_ORDER_F, &
    FRUMPY_ORDER_K
  use frumpy_broadcast, only: broadcast_plan, broadcast_plan_r64
  use frumpy_casting, only: FRUMPY_CASTING_EQUIV, FRUMPY_CASTING_NO, &
    FRUMPY_CASTING_SAFE, FRUMPY_CASTING_SAME_KIND, FRUMPY_CASTING_UNSAFE, &
    can_cast_dtype, cast_bool_to_i32, cast_i32_to_i64, cast_i32_to_r64, &
    cast_i64_to_i32, cast_i64_to_r64, cast_r32_to_r64, cast_r64_to_i32, &
    cast_r64_to_r32, copy_r64_value, require_cast_dtype
  use frumpy_constructors_r64, only: arange_r64, asarray_r64, &
    ascontiguousarray_r64, copy_r64, empty_r64, full_r64, linspace_r64, &
    ones_r64, zeros_r64
  use frumpy_dtypes, only: FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_I32, &
    FRUMPY_DTYPE_I64, FRUMPY_DTYPE_R32, FRUMPY_DTYPE_R64
  use frumpy_elementwise_i32, only: add_i32, subtract_i32, multiply_i32, divide_i32
  use frumpy_elementwise_i64, only: add_i64, subtract_i64, multiply_i64, divide_i64
  use frumpy_elementwise_r32, only: add_r32, subtract_r32, multiply_r32, divide_r32, &
    negate_r32, abs_r32, sqrt_r32, exp_r32, log_r32, sin_r32, cos_r32
  use frumpy_elementwise_r64, only: abs_r64, add_r64, cos_r64, divide_r64, &
    exp_r64, log_r64, multiply_r64, negate_r64, sin_r64, sqrt_r64, &
    subtract_r64
  use frumpy_ndarray_bool, only: metadata_descriptor_bool, ndarray_bool, &
    share_descriptors_bool, &
    owned_descriptor_bool, view_descriptor_bool
  use frumpy_ndarray_i32, only: metadata_descriptor_i32, ndarray_i32, &
    share_descriptors_i32, &
    owned_descriptor_i32, view_descriptor_i32
  use frumpy_ndarray_i64, only: metadata_descriptor_i64, ndarray_i64, &
    share_descriptors_i64, &
    owned_descriptor_i64, view_descriptor_i64
  use frumpy_ndarray_r32, only: metadata_descriptor_r32, ndarray_r32, &
    share_descriptors_r32, &
    owned_descriptor_r32, view_descriptor_r32
  use frumpy_ndarray_r64, only: share_descriptors_r64, metadata_descriptor_r64, ndarray_r64, &
    owned_descriptor_r64, view_descriptor_r64
  use frumpy_promotion, only: binary_result_dtype, is_supported_promotion, promote_dtypes, &
    promote_scalar_dtype
  use frumpy_selection_r64, only: concatenate_r64, nonzero_bool, stack_r64, &
    take_r64, where_r64
  use frumpy_searching_r64, only: searchsorted_r64
  use frumpy_sorting_r64, only: argsort_r64, sort_r64
  use frumpy_reductions_r32, only: sum_r32, prod_r32, mean_r32, min_r32, max_r32
  use frumpy_reductions_r64, only: axis0_to_dim1, max_r64, mean_r64, &
    min_r64, prod_r64, sum_r64
  use frumpy_slices, only: slice_all, slice_range, slice_spec
  use frumpy_statuses, only: FRUMPY_STATUS_INVALID_HANDLE, FRUMPY_STATUS_ALLOCATION_FAILED, &
    FRUMPY_STATUS_INVALID_AXIS, FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_OVERFLOW, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, FRUMPY_STATUS_SINGULAR_MATRIX, &
    FRUMPY_STATUS_UNSUPPORTED_DTYPE, frumpy_status
  use frumpy_views_r64, only: expand_dims_r64, flatten_r64, ravel_r64, &
    reshape_r64, slice_r64, squeeze_r64, swapaxes_r64, transpose_r64

  implicit none

  private

  public :: matmul_r32, solve_r32
  public :: matmul_r64, solve_r64, outer_r64, dot_r64, FRUMPY_STATUS_SINGULAR_MATRIX
  public :: empty_bool, zeros_bool, ones_bool, full_bool
  public :: asarray_bool, copy_bool, ascontiguousarray_bool
  public :: empty_i32, zeros_i32, ones_i32, full_i32
  public :: asarray_i32, copy_i32, ascontiguousarray_i32
  public :: empty_i64, zeros_i64, ones_i64, full_i64
  public :: asarray_i64, copy_i64, ascontiguousarray_i64
  public :: empty_r32, zeros_r32, ones_r32, full_r32
  public :: asarray_r32, copy_r32, ascontiguousarray_r32
  public :: reshape_bool, ravel_bool, flatten_bool, transpose_bool
  public :: swapaxes_bool, squeeze_bool, expand_dims_bool, slice_bool
  public :: reshape_i32, ravel_i32, flatten_i32, transpose_i32
  public :: swapaxes_i32, squeeze_i32, expand_dims_i32, slice_i32
  public :: reshape_i64, ravel_i64, flatten_i64, transpose_i64
  public :: swapaxes_i64, squeeze_i64, expand_dims_i64, slice_i64
  public :: reshape_r32, ravel_r32, flatten_r32, transpose_r32
  public :: swapaxes_r32, squeeze_r32, expand_dims_r32, slice_r32
  public :: equal, not_equal, less, less_equal, greater, greater_equal
  public :: logical_and_bool, logical_or_bool, logical_xor_bool, logical_not_bool
  public :: sum_i32, prod_i32, min_i32, max_i32, mean_i32
  public :: sum_i64, prod_i64, min_i64, max_i64, mean_i64, all_bool, any_bool
  public :: mask_select_r64, assign_r64
  public :: FRUMPY_STATUS_INVALID_HANDLE
  public :: astype
  public :: random_generator, uniform_r64, normal_r64
  public :: vector_norm_r64, matrix_norm_r64
  public :: add, subtract, multiply, divide, binary_result_dtype
  public :: share_descriptors_bool
  public :: share_descriptors_i32
  public :: share_descriptors_i64
  public :: share_descriptors_r32
  public :: share_descriptors_r64

  public :: FRUMPY_ORDER_A
  public :: FRUMPY_ORDER_C
  public :: FRUMPY_ORDER_F
  public :: FRUMPY_ORDER_K
  public :: FRUMPY_CASTING_EQUIV
  public :: FRUMPY_CASTING_NO
  public :: FRUMPY_CASTING_SAFE
  public :: FRUMPY_CASTING_SAME_KIND
  public :: FRUMPY_CASTING_UNSAFE
  public :: FRUMPY_DTYPE_BOOL
  public :: FRUMPY_DTYPE_I32
  public :: FRUMPY_DTYPE_I64
  public :: FRUMPY_DTYPE_R32
  public :: FRUMPY_DTYPE_R64
  public :: FRUMPY_STATUS_ALLOCATION_FAILED
  public :: FRUMPY_STATUS_INVALID_AXIS
  public :: FRUMPY_STATUS_INVALID_SHAPE
  public :: FRUMPY_STATUS_OK
  public :: FRUMPY_STATUS_OVERFLOW
  public :: FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR
  public :: FRUMPY_STATUS_UNSUPPORTED_DTYPE
  public :: abs_r64
  public :: arange_r64
  public :: asarray_r64
  public :: ascontiguousarray_r64
  public :: add_i32, subtract_i32, multiply_i32, divide_i32
  public :: add_i64, subtract_i64, multiply_i64, divide_i64
  public :: add_r32, subtract_r32, multiply_r32, divide_r32
  public :: negate_r32, abs_r32, sqrt_r32, exp_r32, log_r32, sin_r32, cos_r32
  public :: add_r64
  public :: axis0_to_dim1
  public :: broadcast_plan
  public :: broadcast_plan_r64
  public :: can_cast_dtype
  public :: cast_bool_to_i32
  public :: cast_i32_to_i64
  public :: cast_i32_to_r64
  public :: cast_i64_to_i32
  public :: cast_i64_to_r64
  public :: cast_r32_to_r64
  public :: cast_r64_to_i32
  public :: cast_r64_to_r32
  public :: cos_r64
  public :: copy_r64_value
  public :: copy_r64
  public :: concatenate_r64
  public :: argsort_r64
  public :: nonzero_bool
  public :: searchsorted_r64
  public :: divide_r64
  public :: empty_r64
  public :: expand_dims_r64
  public :: exp_r64
  public :: frumpy_status
  public :: flatten_r64
  public :: full_r64
  public :: is_supported_promotion
  public :: linspace_r64
  public :: log_r64
  public :: max_r64
  public :: mean_r64
  public :: metadata_descriptor_bool
  public :: metadata_descriptor_i32
  public :: metadata_descriptor_i64
  public :: metadata_descriptor_r32
  public :: metadata_descriptor_r64
  public :: min_r64
  public :: multiply_r64
  public :: negate_r64
  public :: ndarray_bool
  public :: ndarray_i32
  public :: ndarray_i64
  public :: ndarray_r32
  public :: ndarray_r64
  public :: ones_r64
  public :: owned_descriptor_bool
  public :: owned_descriptor_i32
  public :: owned_descriptor_i64
  public :: owned_descriptor_r32
  public :: owned_descriptor_r64
  public :: prod_r64
  public :: ravel_r64
  public :: reshape_r64
  public :: require_cast_dtype
  public :: slice_all
  public :: slice_range
  public :: slice_r64
  public :: slice_spec
  public :: sin_r64
  public :: sqrt_r64
  public :: subtract_r64
  public :: sum_r32, prod_r32, mean_r32, min_r32, max_r32
  public :: sum_r64
  public :: squeeze_r64
  public :: swapaxes_r64
  public :: take_r64
  public :: sort_r64
  public :: stack_r64
  public :: transpose_r64
  public :: where_r64
  public :: view_descriptor_bool
  public :: view_descriptor_i32
  public :: view_descriptor_i64
  public :: view_descriptor_r32
  public :: view_descriptor_r64
  public :: zeros_r64
end module frumpy
