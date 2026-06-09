!> Table-backed dtype identifiers and metadata for the concrete r64 path.
module frumpy_dtypes
  use iso_fortran_env, only: int32, int64
  use frumpy_constants, only: FRUMPY_BYTE_SIZE_BOOL, FRUMPY_BYTE_SIZE_I32, &
    FRUMPY_BYTE_SIZE_I64, FRUMPY_BYTE_SIZE_R32, FRUMPY_BYTE_SIZE_R64, &
    FRUMPY_DTYPE_NAME_LEN, FRUMPY_STATUS_MESSAGE_LEN
  use frumpy_statuses, only: FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_UNSUPPORTED_DTYPE, frumpy_status, set_status

  implicit none

  private

  public :: frumpy_dtype_info
  public :: FRUMPY_DTYPE_UNSUPPORTED
  public :: FRUMPY_DTYPE_BOOL
  public :: FRUMPY_DTYPE_I32
  public :: FRUMPY_DTYPE_I64
  public :: FRUMPY_DTYPE_R32
  public :: FRUMPY_DTYPE_R64
  public :: FRUMPY_DTYPE_SUPPORT_UNSUPPORTED
  public :: FRUMPY_DTYPE_SUPPORT_PLANNED
  public :: FRUMPY_DTYPE_SUPPORT_SUPPORTED
  public :: dtype_info
  public :: dtype_name
  public :: dtype_byte_size
  public :: dtype_support_state
  public :: is_supported_dtype

  integer(int32), parameter :: FRUMPY_DTYPE_UNSUPPORTED = -1_int32
  integer(int32), parameter :: FRUMPY_DTYPE_BOOL = 1_int32
  integer(int32), parameter :: FRUMPY_DTYPE_I32 = 2_int32
  integer(int32), parameter :: FRUMPY_DTYPE_I64 = 3_int32
  integer(int32), parameter :: FRUMPY_DTYPE_R32 = 4_int32
  integer(int32), parameter :: FRUMPY_DTYPE_R64 = 5_int32

  integer(int32), parameter :: FRUMPY_DTYPE_SUPPORT_UNSUPPORTED = 0_int32
  integer(int32), parameter :: FRUMPY_DTYPE_SUPPORT_PLANNED = 1_int32
  integer(int32), parameter :: FRUMPY_DTYPE_SUPPORT_SUPPORTED = 2_int32

  type :: frumpy_dtype_info
    integer(int32) :: id = FRUMPY_DTYPE_UNSUPPORTED
    character(len=FRUMPY_DTYPE_NAME_LEN) :: name = "unsupported"
    integer(int64) :: byte_size = 0_int64
    integer(int32) :: support_state = FRUMPY_DTYPE_SUPPORT_UNSUPPORTED
    logical :: is_supported = .false.
    character(len=FRUMPY_STATUS_MESSAGE_LEN) :: status_message = &
      "unknown dtype id"
  end type frumpy_dtype_info

  integer(int32), parameter :: DTYPE_TABLE_LEN = 5_int32

  type(frumpy_dtype_info), parameter :: DTYPE_TABLE(DTYPE_TABLE_LEN) = [ &
    frumpy_dtype_info( &
      id=FRUMPY_DTYPE_BOOL, &
      name="bool", &
      byte_size=FRUMPY_BYTE_SIZE_BOOL, &
      support_state=FRUMPY_DTYPE_SUPPORT_PLANNED, &
      is_supported=.false., &
      status_message="dtype bool is planned but not supported yet" &
    ), &
    frumpy_dtype_info( &
      id=FRUMPY_DTYPE_I32, &
      name="i32", &
      byte_size=FRUMPY_BYTE_SIZE_I32, &
      support_state=FRUMPY_DTYPE_SUPPORT_PLANNED, &
      is_supported=.false., &
      status_message="dtype i32 is planned but not supported yet" &
    ), &
    frumpy_dtype_info( &
      id=FRUMPY_DTYPE_I64, &
      name="i64", &
      byte_size=FRUMPY_BYTE_SIZE_I64, &
      support_state=FRUMPY_DTYPE_SUPPORT_PLANNED, &
      is_supported=.false., &
      status_message="dtype i64 is planned but not supported yet" &
    ), &
    frumpy_dtype_info( &
      id=FRUMPY_DTYPE_R32, &
      name="r32", &
      byte_size=FRUMPY_BYTE_SIZE_R32, &
      support_state=FRUMPY_DTYPE_SUPPORT_PLANNED, &
      is_supported=.false., &
      status_message="dtype r32 is planned but not supported yet" &
    ), &
    frumpy_dtype_info( &
      id=FRUMPY_DTYPE_R64, &
      name="r64", &
      byte_size=FRUMPY_BYTE_SIZE_R64, &
      support_state=FRUMPY_DTYPE_SUPPORT_SUPPORTED, &
      is_supported=.true., &
      status_message="dtype r64 is supported" &
    ) &
  ]

contains

  function dtype_info(dtype_id, status) result(info)
    integer(int32), intent(in) :: dtype_id
    type(frumpy_status), intent(out), optional :: status
    type(frumpy_dtype_info) :: info
    integer :: dtype_position

    dtype_position = dtype_table_position(dtype_id)

    if (dtype_position > 0) then
      info = DTYPE_TABLE(dtype_position)
    else
      info = frumpy_dtype_info()
    end if

    call set_dtype_status(status, info)
  end function dtype_info

  function dtype_name(dtype_id) result(name)
    integer(int32), intent(in) :: dtype_id
    character(len=FRUMPY_DTYPE_NAME_LEN) :: name
    type(frumpy_dtype_info) :: info

    info = dtype_info(dtype_id)
    name = info%name
  end function dtype_name

  function dtype_byte_size(dtype_id, status) result(byte_size)
    integer(int32), intent(in) :: dtype_id
    type(frumpy_status), intent(out), optional :: status
    integer(int64) :: byte_size
    type(frumpy_dtype_info) :: info

    info = dtype_info(dtype_id, status)
    byte_size = info%byte_size
  end function dtype_byte_size

  function dtype_support_state(dtype_id) result(support_state)
    integer(int32), intent(in) :: dtype_id
    integer(int32) :: support_state
    type(frumpy_dtype_info) :: info

    info = dtype_info(dtype_id)
    support_state = info%support_state
  end function dtype_support_state

  logical function is_supported_dtype(dtype_id)
    integer(int32), intent(in) :: dtype_id

    is_supported_dtype = dtype_support_state(dtype_id) == &
      FRUMPY_DTYPE_SUPPORT_SUPPORTED
  end function is_supported_dtype

  integer function dtype_table_position(dtype_id) result(position)
    integer(int32), intent(in) :: dtype_id
    integer :: candidate

    position = 0

    do candidate = 1, size(DTYPE_TABLE)
      if (DTYPE_TABLE(candidate)%id == dtype_id) then
        position = candidate
        return
      end if
    end do
  end function dtype_table_position

  subroutine set_dtype_status(status, info)
    type(frumpy_status), intent(out), optional :: status
    type(frumpy_dtype_info), intent(in) :: info

    if (.not. present(status)) return

    if (info%support_state == FRUMPY_DTYPE_SUPPORT_SUPPORTED) then
      call set_status(status, FRUMPY_STATUS_OK)
    else
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
        trim(info%status_message))
    end if
  end subroutine set_dtype_status

end module frumpy_dtypes
