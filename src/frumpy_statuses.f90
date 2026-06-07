!> Recoverable status values for Frumpy library routines.
module frumpy_statuses
  use iso_fortran_env, only: int32
  use frumpy_constants, only: FRUMPY_STATUS_MESSAGE_LEN

  implicit none

  private

  public :: frumpy_status
  public :: FRUMPY_STATUS_OK
  public :: FRUMPY_STATUS_INVALID_SHAPE
  public :: FRUMPY_STATUS_INVALID_AXIS
  public :: FRUMPY_STATUS_ALLOCATION_FAILED
  public :: FRUMPY_STATUS_OVERFLOW
  public :: FRUMPY_STATUS_UNSUPPORTED_DTYPE
  public :: FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR
  public :: frumpy_ok
  public :: frumpy_error
  public :: set_status
  public :: status_code_name

  integer(int32), parameter :: FRUMPY_STATUS_OK = 0_int32
  integer(int32), parameter :: FRUMPY_STATUS_INVALID_SHAPE = 1_int32
  integer(int32), parameter :: FRUMPY_STATUS_INVALID_AXIS = 2_int32
  integer(int32), parameter :: FRUMPY_STATUS_ALLOCATION_FAILED = 3_int32
  integer(int32), parameter :: FRUMPY_STATUS_OVERFLOW = 4_int32
  integer(int32), parameter :: FRUMPY_STATUS_UNSUPPORTED_DTYPE = 5_int32
  integer(int32), parameter :: FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR = 6_int32

  type :: frumpy_status
    integer(int32) :: code = FRUMPY_STATUS_OK
    logical :: failed = .false.
    character(len=FRUMPY_STATUS_MESSAGE_LEN) :: message = ""
  contains
    procedure :: clear => frumpy_status_clear
    procedure :: is_ok => frumpy_status_is_ok
    procedure :: is_failure => frumpy_status_is_failure
  end type frumpy_status

contains

  function frumpy_ok() result(status)
    type(frumpy_status) :: status

    call status%clear()
  end function frumpy_ok

  function frumpy_error(code, message) result(status)
    integer(int32), intent(in) :: code
    character(len=*), intent(in), optional :: message
    type(frumpy_status) :: status

    status%code = code
    status%failed = code /= FRUMPY_STATUS_OK

    if (present(message)) then
      status%message = message
    else
      status%message = status_code_name(code)
    end if
  end function frumpy_error

  subroutine set_status(status, code, message)
    type(frumpy_status), intent(out) :: status
    integer(int32), intent(in) :: code
    character(len=*), intent(in), optional :: message

    if (code == FRUMPY_STATUS_OK) then
      status = frumpy_ok()
    else if (present(message)) then
      status = frumpy_error(code, message)
    else
      status = frumpy_error(code)
    end if
  end subroutine set_status

  function status_code_name(code) result(name)
    integer(int32), intent(in) :: code
    character(len=32) :: name

    select case (code)
    case (FRUMPY_STATUS_OK)
      name = "ok"
    case (FRUMPY_STATUS_INVALID_SHAPE)
      name = "invalid_shape"
    case (FRUMPY_STATUS_INVALID_AXIS)
      name = "invalid_axis"
    case (FRUMPY_STATUS_ALLOCATION_FAILED)
      name = "allocation_failed"
    case (FRUMPY_STATUS_OVERFLOW)
      name = "overflow"
    case (FRUMPY_STATUS_UNSUPPORTED_DTYPE)
      name = "unsupported_dtype"
    case (FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR)
      name = "unsupported_behavior"
    case default
      name = "unknown_status"
    end select
  end function status_code_name

  subroutine frumpy_status_clear(status)
    class(frumpy_status), intent(inout) :: status

    status%code = FRUMPY_STATUS_OK
    status%failed = .false.
    status%message = ""
  end subroutine frumpy_status_clear

  logical function frumpy_status_is_ok(status)
    class(frumpy_status), intent(in) :: status

    frumpy_status_is_ok = .not. status%failed .and. &
      status%code == FRUMPY_STATUS_OK
  end function frumpy_status_is_ok

  logical function frumpy_status_is_failure(status)
    class(frumpy_status), intent(in) :: status

    frumpy_status_is_failure = status%failed .or. &
      status%code /= FRUMPY_STATUS_OK
  end function frumpy_status_is_failure
end module frumpy_statuses
