!> Initial dtype identifiers and metadata for the concrete r64 path.
module fenum_dtypes
  use iso_fortran_env, only: int32, int64
  use fenum_constants, only: FENUM_BYTE_SIZE_BOOL, FENUM_BYTE_SIZE_I32, &
    FENUM_BYTE_SIZE_I64, FENUM_BYTE_SIZE_R32, FENUM_BYTE_SIZE_R64, &
    FENUM_DTYPE_NAME_LEN
  use fenum_statuses, only: FENUM_STATUS_OK, &
    FENUM_STATUS_UNSUPPORTED_DTYPE, fenum_status, set_status

  implicit none

  private

  public :: fenum_dtype_info
  public :: FENUM_DTYPE_UNSUPPORTED
  public :: FENUM_DTYPE_BOOL
  public :: FENUM_DTYPE_I32
  public :: FENUM_DTYPE_I64
  public :: FENUM_DTYPE_R32
  public :: FENUM_DTYPE_R64
  public :: dtype_info
  public :: dtype_name
  public :: dtype_byte_size
  public :: is_supported_dtype

  integer(int32), parameter :: FENUM_DTYPE_UNSUPPORTED = -1_int32
  integer(int32), parameter :: FENUM_DTYPE_BOOL = 1_int32
  integer(int32), parameter :: FENUM_DTYPE_I32 = 2_int32
  integer(int32), parameter :: FENUM_DTYPE_I64 = 3_int32
  integer(int32), parameter :: FENUM_DTYPE_R32 = 4_int32
  integer(int32), parameter :: FENUM_DTYPE_R64 = 5_int32

  type :: fenum_dtype_info
    integer(int32) :: id = FENUM_DTYPE_UNSUPPORTED
    character(len=FENUM_DTYPE_NAME_LEN) :: name = "unsupported"
    integer(int64) :: byte_size = 0_int64
    logical :: is_supported = .false.
  end type fenum_dtype_info

contains

  function dtype_info(dtype_id, status) result(info)
    integer(int32), intent(in) :: dtype_id
    type(fenum_status), intent(out), optional :: status
    type(fenum_dtype_info) :: info

    select case (dtype_id)
    case (FENUM_DTYPE_R64)
      info = fenum_dtype_info( &
        id=FENUM_DTYPE_R64, &
        name="r64", &
        byte_size=FENUM_BYTE_SIZE_R64, &
        is_supported=.true. &
      )
      call set_optional_status(status, FENUM_STATUS_OK)
    case (FENUM_DTYPE_BOOL)
      info = planned_dtype_info(FENUM_DTYPE_BOOL, "bool", &
        FENUM_BYTE_SIZE_BOOL)
      call set_optional_status(status, FENUM_STATUS_UNSUPPORTED_DTYPE, &
        "dtype bool is planned but not supported yet")
    case (FENUM_DTYPE_I32)
      info = planned_dtype_info(FENUM_DTYPE_I32, "i32", FENUM_BYTE_SIZE_I32)
      call set_optional_status(status, FENUM_STATUS_UNSUPPORTED_DTYPE, &
        "dtype i32 is planned but not supported yet")
    case (FENUM_DTYPE_I64)
      info = planned_dtype_info(FENUM_DTYPE_I64, "i64", FENUM_BYTE_SIZE_I64)
      call set_optional_status(status, FENUM_STATUS_UNSUPPORTED_DTYPE, &
        "dtype i64 is planned but not supported yet")
    case (FENUM_DTYPE_R32)
      info = planned_dtype_info(FENUM_DTYPE_R32, "r32", FENUM_BYTE_SIZE_R32)
      call set_optional_status(status, FENUM_STATUS_UNSUPPORTED_DTYPE, &
        "dtype r32 is planned but not supported yet")
    case default
      info = fenum_dtype_info()
      call set_optional_status(status, FENUM_STATUS_UNSUPPORTED_DTYPE, &
        "unknown dtype id")
    end select
  end function dtype_info

  function dtype_name(dtype_id) result(name)
    integer(int32), intent(in) :: dtype_id
    character(len=FENUM_DTYPE_NAME_LEN) :: name
    type(fenum_dtype_info) :: info

    info = dtype_info(dtype_id)
    name = info%name
  end function dtype_name

  function dtype_byte_size(dtype_id, status) result(byte_size)
    integer(int32), intent(in) :: dtype_id
    type(fenum_status), intent(out), optional :: status
    integer(int64) :: byte_size
    type(fenum_dtype_info) :: info

    info = dtype_info(dtype_id, status)
    byte_size = info%byte_size
  end function dtype_byte_size

  logical function is_supported_dtype(dtype_id)
    integer(int32), intent(in) :: dtype_id
    type(fenum_dtype_info) :: info

    info = dtype_info(dtype_id)
    is_supported_dtype = info%is_supported
  end function is_supported_dtype

  function planned_dtype_info(dtype_id, name, byte_size) result(info)
    integer(int32), intent(in) :: dtype_id
    character(len=*), intent(in) :: name
    integer(int64), intent(in) :: byte_size
    type(fenum_dtype_info) :: info

    info = fenum_dtype_info( &
      id=dtype_id, &
      name=name, &
      byte_size=byte_size, &
      is_supported=.false. &
    )
  end function planned_dtype_info

  subroutine set_optional_status(status, code, message)
    type(fenum_status), intent(out), optional :: status
    integer(int32), intent(in) :: code
    character(len=*), intent(in), optional :: message

    if (.not. present(status)) return

    if (present(message)) then
      call set_status(status, code, message)
    else
      call set_status(status, code)
    end if
  end subroutine set_optional_status
end module fenum_dtypes
