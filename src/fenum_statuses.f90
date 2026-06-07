!> Recoverable status values for Fenum library routines.
module fenum_statuses
  use iso_fortran_env, only: int32
  use fenum_constants, only: FENUM_STATUS_MESSAGE_LEN

  implicit none

  private

  public :: fenum_status
  public :: FENUM_STATUS_OK
  public :: FENUM_STATUS_INVALID_SHAPE
  public :: FENUM_STATUS_INVALID_AXIS
  public :: FENUM_STATUS_ALLOCATION_FAILED
  public :: FENUM_STATUS_OVERFLOW
  public :: FENUM_STATUS_UNSUPPORTED_DTYPE
  public :: FENUM_STATUS_UNSUPPORTED_BEHAVIOR
  public :: fenum_ok
  public :: fenum_error
  public :: set_status
  public :: status_code_name

  integer(int32), parameter :: FENUM_STATUS_OK = 0_int32
  integer(int32), parameter :: FENUM_STATUS_INVALID_SHAPE = 1_int32
  integer(int32), parameter :: FENUM_STATUS_INVALID_AXIS = 2_int32
  integer(int32), parameter :: FENUM_STATUS_ALLOCATION_FAILED = 3_int32
  integer(int32), parameter :: FENUM_STATUS_OVERFLOW = 4_int32
  integer(int32), parameter :: FENUM_STATUS_UNSUPPORTED_DTYPE = 5_int32
  integer(int32), parameter :: FENUM_STATUS_UNSUPPORTED_BEHAVIOR = 6_int32

  type :: fenum_status
    integer(int32) :: code = FENUM_STATUS_OK
    logical :: failed = .false.
    character(len=FENUM_STATUS_MESSAGE_LEN) :: message = ""
  contains
    procedure :: clear => fenum_status_clear
    procedure :: is_ok => fenum_status_is_ok
    procedure :: is_failure => fenum_status_is_failure
  end type fenum_status

contains

  function fenum_ok() result(status)
    type(fenum_status) :: status

    call status%clear()
  end function fenum_ok

  function fenum_error(code, message) result(status)
    integer(int32), intent(in) :: code
    character(len=*), intent(in), optional :: message
    type(fenum_status) :: status

    status%code = code
    status%failed = code /= FENUM_STATUS_OK

    if (present(message)) then
      status%message = message
    else
      status%message = status_code_name(code)
    end if
  end function fenum_error

  subroutine set_status(status, code, message)
    type(fenum_status), intent(out) :: status
    integer(int32), intent(in) :: code
    character(len=*), intent(in), optional :: message

    if (code == FENUM_STATUS_OK) then
      status = fenum_ok()
    else if (present(message)) then
      status = fenum_error(code, message)
    else
      status = fenum_error(code)
    end if
  end subroutine set_status

  function status_code_name(code) result(name)
    integer(int32), intent(in) :: code
    character(len=32) :: name

    select case (code)
    case (FENUM_STATUS_OK)
      name = "ok"
    case (FENUM_STATUS_INVALID_SHAPE)
      name = "invalid_shape"
    case (FENUM_STATUS_INVALID_AXIS)
      name = "invalid_axis"
    case (FENUM_STATUS_ALLOCATION_FAILED)
      name = "allocation_failed"
    case (FENUM_STATUS_OVERFLOW)
      name = "overflow"
    case (FENUM_STATUS_UNSUPPORTED_DTYPE)
      name = "unsupported_dtype"
    case (FENUM_STATUS_UNSUPPORTED_BEHAVIOR)
      name = "unsupported_behavior"
    case default
      name = "unknown_status"
    end select
  end function status_code_name

  subroutine fenum_status_clear(status)
    class(fenum_status), intent(inout) :: status

    status%code = FENUM_STATUS_OK
    status%failed = .false.
    status%message = ""
  end subroutine fenum_status_clear

  logical function fenum_status_is_ok(status)
    class(fenum_status), intent(in) :: status

    fenum_status_is_ok = .not. status%failed .and. &
      status%code == FENUM_STATUS_OK
  end function fenum_status_is_ok

  logical function fenum_status_is_failure(status)
    class(fenum_status), intent(in) :: status

    fenum_status_is_failure = status%failed .or. &
      status%code /= FENUM_STATUS_OK
  end function fenum_status_is_failure
end module fenum_statuses
