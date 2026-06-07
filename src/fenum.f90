!> Public umbrella module for the current Fenum core surface.
module fenum
  use fenum_constants, only: FENUM_ORDER_A, FENUM_ORDER_C, FENUM_ORDER_F, &
    FENUM_ORDER_K
  use fenum_broadcast, only: broadcast_plan, broadcast_plan_r64
  use fenum_constructors_r64, only: arange_r64, asarray_r64, &
    ascontiguousarray_r64, copy_r64, empty_r64, full_r64, linspace_r64, &
    ones_r64, zeros_r64
  use fenum_elementwise_r64, only: abs_r64, add_r64, cos_r64, divide_r64, &
    exp_r64, log_r64, multiply_r64, negate_r64, sin_r64, sqrt_r64, &
    subtract_r64
  use fenum_ndarray_r64, only: metadata_descriptor_r64, ndarray_r64, &
    owned_descriptor_r64, view_descriptor_r64
  use fenum_reductions_r64, only: axis0_to_dim1, max_r64, mean_r64, &
    min_r64, prod_r64, sum_r64
  use fenum_slices, only: slice_all, slice_range, slice_spec
  use fenum_statuses, only: FENUM_STATUS_ALLOCATION_FAILED, &
    FENUM_STATUS_INVALID_AXIS, FENUM_STATUS_INVALID_SHAPE, FENUM_STATUS_OK, &
    FENUM_STATUS_OVERFLOW, FENUM_STATUS_UNSUPPORTED_BEHAVIOR, fenum_status
  use fenum_views_r64, only: expand_dims_r64, flatten_r64, ravel_r64, &
    reshape_r64, slice_r64, squeeze_r64, swapaxes_r64, transpose_r64

  implicit none

  private

  public :: FENUM_ORDER_A
  public :: FENUM_ORDER_C
  public :: FENUM_ORDER_F
  public :: FENUM_ORDER_K
  public :: FENUM_STATUS_ALLOCATION_FAILED
  public :: FENUM_STATUS_INVALID_AXIS
  public :: FENUM_STATUS_INVALID_SHAPE
  public :: FENUM_STATUS_OK
  public :: FENUM_STATUS_OVERFLOW
  public :: FENUM_STATUS_UNSUPPORTED_BEHAVIOR
  public :: abs_r64
  public :: arange_r64
  public :: asarray_r64
  public :: ascontiguousarray_r64
  public :: add_r64
  public :: axis0_to_dim1
  public :: broadcast_plan
  public :: broadcast_plan_r64
  public :: cos_r64
  public :: copy_r64
  public :: divide_r64
  public :: empty_r64
  public :: expand_dims_r64
  public :: exp_r64
  public :: fenum_status
  public :: flatten_r64
  public :: full_r64
  public :: linspace_r64
  public :: log_r64
  public :: max_r64
  public :: mean_r64
  public :: min_r64
  public :: multiply_r64
  public :: negate_r64
  public :: ndarray_r64
  public :: ones_r64
  public :: owned_descriptor_r64
  public :: metadata_descriptor_r64
  public :: prod_r64
  public :: ravel_r64
  public :: reshape_r64
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
  public :: view_descriptor_r64
  public :: zeros_r64
end module fenum
