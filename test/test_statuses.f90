program test_statuses
  use iso_fortran_env, only: int32
  use frumpy_statuses, only: FRUMPY_STATUS_ALLOCATION_FAILED, &
    FRUMPY_STATUS_INVALID_AXIS, FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_OVERFLOW, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    FRUMPY_STATUS_UNSUPPORTED_DTYPE, frumpy_error, frumpy_ok, frumpy_status, &
    set_status, status_code_name

  implicit none

  type(frumpy_status) :: status

  status = frumpy_ok()
  call assert_true(status%is_ok(), "ok status reports is_ok")
  call assert_false(status%failed, "ok status is not failed")
  call assert_false(status%is_failure(), "ok status is not a failure")
  call assert_equal_int32(status%code, FRUMPY_STATUS_OK, "ok status code")
  call assert_equal_string(status%message, "", "ok status message")

  call assert_failure(FRUMPY_STATUS_INVALID_SHAPE, "invalid_shape")
  call assert_failure(FRUMPY_STATUS_INVALID_AXIS, "invalid_axis")
  call assert_failure(FRUMPY_STATUS_ALLOCATION_FAILED, "allocation_failed")
  call assert_failure(FRUMPY_STATUS_OVERFLOW, "overflow")
  call assert_failure(FRUMPY_STATUS_UNSUPPORTED_DTYPE, "unsupported_dtype")
  call assert_failure(FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    "unsupported_behavior")

  call set_status(status, FRUMPY_STATUS_OK)
  call assert_true(status%is_ok(), "set_status can reset to ok")

  status = frumpy_error(FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    "object dtype is unsupported")
  call assert_true(status%failed, "custom error status failed flag")
  call assert_equal_string(status%message, "object dtype is unsupported", &
    "custom error status message")

  call status%clear()
  call assert_true(status%is_ok(), "clear resets status to ok")

contains

  subroutine assert_failure(code, expected_name)
    integer(int32), intent(in) :: code
    character(len=*), intent(in) :: expected_name
    type(frumpy_status) :: failure

    failure = frumpy_error(code)

    call assert_true(failure%failed, expected_name // " failed flag")
    call assert_true(failure%is_failure(), expected_name // " is_failure")
    call assert_false(failure%is_ok(), expected_name // " is not ok")
    call assert_equal_int32(failure%code, code, expected_name // " code")
    call assert_equal_string(status_code_name(code), expected_name, &
      expected_name // " status_code_name")
    call assert_equal_string(failure%message, expected_name, &
      expected_name // " default message")
  end subroutine assert_failure

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
end program test_statuses
