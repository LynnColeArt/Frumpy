program test_dtypes
  use iso_fortran_env, only: int32, int64
  use frumpy_constants, only: FRUMPY_BYTE_SIZE_BOOL, FRUMPY_BYTE_SIZE_I32, &
    FRUMPY_BYTE_SIZE_I64, FRUMPY_BYTE_SIZE_R32, FRUMPY_BYTE_SIZE_R64
  use frumpy_dtypes, only: FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_I32, &
    FRUMPY_DTYPE_I64, FRUMPY_DTYPE_R32, FRUMPY_DTYPE_R64, &
    FRUMPY_DTYPE_SUPPORT_PLANNED, FRUMPY_DTYPE_SUPPORT_SUPPORTED, &
    FRUMPY_DTYPE_SUPPORT_UNSUPPORTED, dtype_byte_size, dtype_info, &
    dtype_name, dtype_support_state, frumpy_dtype_info, is_supported_dtype
  use frumpy_statuses, only: FRUMPY_STATUS_UNSUPPORTED_DTYPE, frumpy_status

  implicit none

  type(frumpy_dtype_info) :: info
  type(frumpy_status) :: status
  integer(int64) :: byte_size

  info = dtype_info(FRUMPY_DTYPE_R64, status)
  call assert_equal_int32(info%id, FRUMPY_DTYPE_R64, "r64 dtype id")
  call assert_equal_string(info%name, "r64", "r64 dtype name")
  call assert_equal_int64(info%byte_size, FRUMPY_BYTE_SIZE_R64, &
    "r64 byte size")
  call assert_equal_int32(info%support_state, FRUMPY_DTYPE_SUPPORT_SUPPORTED, &
    "r64 support state")
  call assert_true(info%is_supported, "r64 is supported")
  call assert_equal_string(info%status_message, "dtype r64 is supported", &
    "r64 support message")
  call assert_true(status%is_ok(), "r64 dtype status is ok")
  call assert_true(is_supported_dtype(FRUMPY_DTYPE_R64), &
    "r64 supported predicate")
  call assert_equal_int32(dtype_support_state(FRUMPY_DTYPE_R64), &
    FRUMPY_DTYPE_SUPPORT_SUPPORTED, "r64 dtype_support_state")
  call assert_equal_string(dtype_name(FRUMPY_DTYPE_R64), "r64", &
    "r64 dtype_name")

  byte_size = dtype_byte_size(FRUMPY_DTYPE_R64, status)
  call assert_equal_int64(byte_size, FRUMPY_BYTE_SIZE_R64, &
    "r64 dtype_byte_size")
  call assert_true(status%is_ok(), "r64 dtype_byte_size status is ok")

  call assert_planned_dtype(FRUMPY_DTYPE_BOOL, "bool", FRUMPY_BYTE_SIZE_BOOL)
  call assert_planned_dtype(FRUMPY_DTYPE_I32, "i32", FRUMPY_BYTE_SIZE_I32)
  call assert_planned_dtype(FRUMPY_DTYPE_I64, "i64", FRUMPY_BYTE_SIZE_I64)
  call assert_planned_dtype(FRUMPY_DTYPE_R32, "r32", FRUMPY_BYTE_SIZE_R32)

  info = dtype_info(999_int32, status)
  call assert_equal_int32(info%id, -1_int32, "unknown dtype id")
  call assert_equal_string(info%name, "unsupported", "unknown dtype name")
  call assert_equal_int64(info%byte_size, 0_int64, "unknown dtype byte size")
  call assert_equal_int32(info%support_state, &
    FRUMPY_DTYPE_SUPPORT_UNSUPPORTED, "unknown dtype support state")
  call assert_false(info%is_supported, "unknown dtype is not supported")
  call assert_equal_string(info%status_message, "unknown dtype id", &
    "unknown dtype message")
  call assert_equal_int32(dtype_support_state(999_int32), &
    FRUMPY_DTYPE_SUPPORT_UNSUPPORTED, "unknown dtype_support_state")
  call assert_equal_int32(status%code, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
    "unknown dtype status code")
  call assert_equal_string(status%message, "unknown dtype id", &
    "unknown dtype status message")
  call assert_true(status%is_failure(), "unknown dtype status fails")

contains

  subroutine assert_planned_dtype(dtype_id, expected_name, expected_byte_size)
    integer(int32), intent(in) :: dtype_id
    character(len=*), intent(in) :: expected_name
    integer(int64), intent(in) :: expected_byte_size
    type(frumpy_dtype_info) :: planned
    type(frumpy_status) :: planned_status
    integer(int64) :: planned_byte_size
    character(len=128) :: expected_message

    expected_message = "dtype " // expected_name // &
      " is planned but not supported yet"
    planned = dtype_info(dtype_id, planned_status)
    call assert_equal_int32(planned%id, dtype_id, expected_name // " id")
    call assert_equal_string(planned%name, expected_name, &
      expected_name // " name")
    call assert_equal_int64(planned%byte_size, expected_byte_size, &
      expected_name // " byte size")
    call assert_equal_int32(planned%support_state, &
      FRUMPY_DTYPE_SUPPORT_PLANNED, expected_name // " support state")
    call assert_false(planned%is_supported, &
      expected_name // " is planned but not supported")
    call assert_equal_string(planned%status_message, &
      trim(expected_message), expected_name // " status message")
    call assert_false(is_supported_dtype(dtype_id), &
      expected_name // " supported predicate")
    call assert_equal_int32(dtype_support_state(dtype_id), &
      FRUMPY_DTYPE_SUPPORT_PLANNED, &
      expected_name // " dtype_support_state")
    call assert_equal_int32(planned_status%code, &
      FRUMPY_STATUS_UNSUPPORTED_DTYPE, expected_name // " status code")
    call assert_equal_string(planned_status%message, trim(expected_message), &
      expected_name // " returned status message")
    call assert_true(planned_status%is_failure(), &
      expected_name // " status fails")

    planned_byte_size = dtype_byte_size(dtype_id, planned_status)
    call assert_equal_int64(planned_byte_size, expected_byte_size, &
      expected_name // " dtype_byte_size")
    call assert_equal_int32(planned_status%code, &
      FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
      expected_name // " dtype_byte_size status")
  end subroutine assert_planned_dtype

  subroutine assert_true(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not. condition) then
      write (*, '(a)') "FAIL: " // message
      error stop 1
    end if
  end subroutine assert_true

  subroutine assert_false(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    call assert_true(.not. condition, message)
  end subroutine assert_false

  subroutine assert_equal_int32(actual, expected, message)
    integer(int32), intent(in) :: actual
    integer(int32), intent(in) :: expected
    character(len=*), intent(in) :: message

    if (actual /= expected) then
      write (*, '(a,1x,i0,1x,a,1x,i0)') "FAIL:", actual, "/=", expected
      write (*, '(a)') message
      error stop 1
    end if
  end subroutine assert_equal_int32

  subroutine assert_equal_int64(actual, expected, message)
    integer(int64), intent(in) :: actual
    integer(int64), intent(in) :: expected
    character(len=*), intent(in) :: message

    if (actual /= expected) then
      write (*, '(a,1x,i0,1x,a,1x,i0)') "FAIL:", actual, "/=", expected
      write (*, '(a)') message
      error stop 1
    end if
  end subroutine assert_equal_int64

  subroutine assert_equal_string(actual, expected, message)
    character(len=*), intent(in) :: actual
    character(len=*), intent(in) :: expected
    character(len=*), intent(in) :: message

    if (trim(actual) /= expected) then
      write (*, '(a)') "FAIL: " // message
      write (*, '(a)') "actual: " // trim(actual)
      write (*, '(a)') "expected: " // expected
      error stop 1
    end if
  end subroutine assert_equal_string
end program test_dtypes
