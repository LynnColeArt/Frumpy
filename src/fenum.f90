!> Public umbrella module for the current Fenum core surface.
module fenum
  use fenum_constants, only: FENUM_ORDER_C, FENUM_ORDER_F
  use fenum_ndarray_r64, only: metadata_descriptor_r64, ndarray_r64, &
    owned_descriptor_r64
  use fenum_statuses, only: FENUM_STATUS_ALLOCATION_FAILED, &
    FENUM_STATUS_INVALID_SHAPE, FENUM_STATUS_OK, &
    FENUM_STATUS_UNSUPPORTED_BEHAVIOR, fenum_status

  implicit none

  private

  public :: FENUM_ORDER_C
  public :: FENUM_ORDER_F
  public :: FENUM_STATUS_ALLOCATION_FAILED
  public :: FENUM_STATUS_INVALID_SHAPE
  public :: FENUM_STATUS_OK
  public :: FENUM_STATUS_UNSUPPORTED_BEHAVIOR
  public :: fenum_status
  public :: ndarray_r64
  public :: owned_descriptor_r64
  public :: metadata_descriptor_r64
end module fenum
