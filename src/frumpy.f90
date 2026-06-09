!> Public umbrella module for the current Frumpy core surface.
module frumpy
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
  use frumpy_elementwise_r64, only: abs_r64, add_r64, cos_r64, divide_r64, &
    exp_r64, log_r64, multiply_r64, negate_r64, sin_r64, sqrt_r64, &
    subtract_r64
  use frumpy_ndarray_bool, only: metadata_descriptor_bool, ndarray_bool, &
    owned_descriptor_bool, view_descriptor_bool
  use frumpy_ndarray_i32, only: metadata_descriptor_i32, ndarray_i32, &
    owned_descriptor_i32, view_descriptor_i32
  use frumpy_ndarray_i64, only: metadata_descriptor_i64, ndarray_i64, &
    owned_descriptor_i64, view_descriptor_i64
  use frumpy_ndarray_r32, only: metadata_descriptor_r32, ndarray_r32, &
    owned_descriptor_r32, view_descriptor_r32
  use frumpy_ndarray_r64, only: metadata_descriptor_r64, ndarray_r64, &
    owned_descriptor_r64, view_descriptor_r64
  use frumpy_promotion, only: is_supported_promotion, promote_dtypes, &
    promote_scalar_dtype
  use frumpy_reductions_r64, only: axis0_to_dim1, max_r64, mean_r64, &
    min_r64, prod_r64, sum_r64
  use frumpy_slices, only: slice_all, slice_range, slice_spec
  use frumpy_statuses, only: FRUMPY_STATUS_ALLOCATION_FAILED, &
    FRUMPY_STATUS_INVALID_AXIS, FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_OVERFLOW, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    FRUMPY_STATUS_UNSUPPORTED_DTYPE, frumpy_status
  use frumpy_views_r64, only: expand_dims_r64, flatten_r64, ravel_r64, &
    reshape_r64, slice_r64, squeeze_r64, swapaxes_r64, transpose_r64

  implicit none

  private

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
  public :: promote_dtypes
  public :: promote_scalar_dtype
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
  public :: sum_r64
  public :: squeeze_r64
  public :: swapaxes_r64
  public :: transpose_r64
  public :: view_descriptor_bool
  public :: view_descriptor_i32
  public :: view_descriptor_i64
  public :: view_descriptor_r32
  public :: view_descriptor_r64
  public :: zeros_r64
end module frumpy
