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
    owned_descriptor_r64
  use fenum_statuses, only: FENUM_STATUS_ALLOCATION_FAILED, &
    FENUM_STATUS_INVALID_SHAPE, FENUM_STATUS_OK, FENUM_STATUS_OVERFLOW, &
    FENUM_STATUS_UNSUPPORTED_BEHAVIOR, fenum_status

  implicit none

  private

  public :: FENUM_ORDER_A
  public :: FENUM_ORDER_C
  public :: FENUM_ORDER_F
  public :: FENUM_ORDER_K
  public :: FENUM_STATUS_ALLOCATION_FAILED
  public :: FENUM_STATUS_INVALID_SHAPE
  public :: FENUM_STATUS_OK
  public :: FENUM_STATUS_OVERFLOW
  public :: FENUM_STATUS_UNSUPPORTED_BEHAVIOR
  public :: abs_r64
  public :: arange_r64
  public :: asarray_r64
  public :: ascontiguousarray_r64
  public :: add_r64
  public :: broadcast_plan
  public :: broadcast_plan_r64
  public :: cos_r64
  public :: copy_r64
  public :: divide_r64
  public :: empty_r64
  public :: exp_r64
  public :: fenum_status
  public :: full_r64
  public :: linspace_r64
  public :: log_r64
  public :: multiply_r64
  public :: negate_r64
  public :: ndarray_r64
  public :: ones_r64
  public :: owned_descriptor_r64
  public :: metadata_descriptor_r64
  public :: sin_r64
  public :: sqrt_r64
  public :: subtract_r64
  public :: zeros_r64
end module fenum
