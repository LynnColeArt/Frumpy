program test_dtype_promotion
  use iso_fortran_env, only: int32
  use frumpy_dtypes, only: FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_I32, &
    FRUMPY_DTYPE_I64, FRUMPY_DTYPE_R32, FRUMPY_DTYPE_R64, &
    FRUMPY_DTYPE_UNSUPPORTED
  use frumpy_promotion, only: is_supported_promotion, promote_dtypes, &
    promote_scalar_dtype
  use frumpy_statuses, only: FRUMPY_STATUS_UNSUPPORTED_DTYPE, frumpy_status

  implicit none

  call assert_promotion(FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_BOOL, &
    FRUMPY_DTYPE_BOOL, "bool + bool")
  call assert_promotion(FRUMPY_DTYPE_I32, FRUMPY_DTYPE_I32, &
    FRUMPY_DTYPE_I32, "i32 + i32")
  call assert_promotion(FRUMPY_DTYPE_I64, FRUMPY_DTYPE_I64, &
    FRUMPY_DTYPE_I64, "i64 + i64")
  call assert_promotion(FRUMPY_DTYPE_R32, FRUMPY_DTYPE_R32, &
    FRUMPY_DTYPE_R32, "r32 + r32")
  call assert_promotion(FRUMPY_DTYPE_R64, FRUMPY_DTYPE_R64, &
    FRUMPY_DTYPE_R64, "r64 + r64")

  call assert_promotion(FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_I32, &
    FRUMPY_DTYPE_I32, "bool + i32")
  call assert_promotion(FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_I64, &
    FRUMPY_DTYPE_I64, "bool + i64")
  call assert_promotion(FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_R32, &
    FRUMPY_DTYPE_R32, "bool + r32")
  call assert_promotion(FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_R64, &
    FRUMPY_DTYPE_R64, "bool + r64")
  call assert_promotion(FRUMPY_DTYPE_I32, FRUMPY_DTYPE_I64, &
    FRUMPY_DTYPE_I64, "i32 + i64")
  call assert_promotion(FRUMPY_DTYPE_I32, FRUMPY_DTYPE_R32, &
    FRUMPY_DTYPE_R64, "i32 + r32")
  call assert_promotion(FRUMPY_DTYPE_I32, FRUMPY_DTYPE_R64, &
    FRUMPY_DTYPE_R64, "i32 + r64")
  call assert_promotion(FRUMPY_DTYPE_I64, FRUMPY_DTYPE_R32, &
    FRUMPY_DTYPE_R64, "i64 + r32")
  call assert_promotion(FRUMPY_DTYPE_I64, FRUMPY_DTYPE_R64, &
    FRUMPY_DTYPE_R64, "i64 + r64")
  call assert_promotion(FRUMPY_DTYPE_R32, FRUMPY_DTYPE_R64, &
    FRUMPY_DTYPE_R64, "r32 + r64")

  call assert_scalar_promotion(FRUMPY_DTYPE_I32, FRUMPY_DTYPE_R32, &
    FRUMPY_DTYPE_R64, "i32 array + r32 scalar-like")
  call assert_scalar_promotion(FRUMPY_DTYPE_R32, FRUMPY_DTYPE_BOOL, &
    FRUMPY_DTYPE_R32, "r32 array + bool scalar-like")

  call assert_unsupported(FRUMPY_DTYPE_R64, 999_int32, &
    "r64 + unknown dtype")
  call assert_unsupported(FRUMPY_DTYPE_UNSUPPORTED, FRUMPY_DTYPE_BOOL, &
    "unsupported + bool")

contains

  subroutine assert_promotion(lhs_dtype_id, rhs_dtype_id, expected, message)
    integer(int32), intent(in) :: lhs_dtype_id
    integer(int32), intent(in) :: rhs_dtype_id
    integer(int32), intent(in) :: expected
    character(len=*), intent(in) :: message
    type(frumpy_status) :: status
    integer(int32) :: result
    integer(int32) :: reversed_result

    result = promote_dtypes(lhs_dtype_id, rhs_dtype_id, status)
    call assert_equal_int32(result, expected, message)
    call assert_status_ok(status, message // " status")
    call assert_true(is_supported_promotion(lhs_dtype_id, rhs_dtype_id), &
      message // " supported predicate")

    reversed_result = promote_dtypes(rhs_dtype_id, lhs_dtype_id, status)
    call assert_equal_int32(reversed_result, expected, &
      message // " reversed")
    call assert_status_ok(status, message // " reversed status")
  end subroutine assert_promotion

  subroutine assert_scalar_promotion(array_dtype_id, scalar_dtype_id, &
      expected, message)
    integer(int32), intent(in) :: array_dtype_id
    integer(int32), intent(in) :: scalar_dtype_id
    integer(int32), intent(in) :: expected
    character(len=*), intent(in) :: message
    type(frumpy_status) :: status
    integer(int32) :: result

    result = promote_scalar_dtype(array_dtype_id, scalar_dtype_id, status)
    call assert_equal_int32(result, expected, message)
    call assert_status_ok(status, message // " status")
  end subroutine assert_scalar_promotion

  subroutine assert_unsupported(lhs_dtype_id, rhs_dtype_id, message)
    integer(int32), intent(in) :: lhs_dtype_id
    integer(int32), intent(in) :: rhs_dtype_id
    character(len=*), intent(in) :: message
    type(frumpy_status) :: status
    integer(int32) :: result

    result = promote_dtypes(lhs_dtype_id, rhs_dtype_id, status)
    call assert_equal_int32(result, FRUMPY_DTYPE_UNSUPPORTED, message)
    call assert_equal_int32(status%code, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
      message // " status code")
    call assert_true(status%is_failure(), message // " status fails")
    call assert_false(is_supported_promotion(lhs_dtype_id, rhs_dtype_id), &
      message // " supported predicate")
  end subroutine assert_unsupported

  subroutine assert_status_ok(status, message)
    type(frumpy_status), intent(in) :: status
    character(len=*), intent(in) :: message

    call assert_true(status%is_ok(), message)
  end subroutine assert_status_ok

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
end program test_dtype_promotion
