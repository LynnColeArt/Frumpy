program test_casting
  use iso_fortran_env, only: int32, int64, real32, real64
  use frumpy_casting, only: FRUMPY_CASTING_EQUIV, FRUMPY_CASTING_NO, &
    FRUMPY_CASTING_SAFE, FRUMPY_CASTING_SAME_KIND, FRUMPY_CASTING_UNSAFE, &
    can_cast_dtype, cast_bool_to_i32, cast_i32_to_i64, cast_i32_to_r64, &
    cast_i64_to_i32, cast_i64_to_r64, cast_r32_to_r64, cast_r64_to_i32, &
    cast_r64_to_r32, copy_r64_value, require_cast_dtype
  use frumpy_dtypes, only: FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_I32, &
    FRUMPY_DTYPE_I64, FRUMPY_DTYPE_R32, FRUMPY_DTYPE_R64
  use frumpy_statuses, only: FRUMPY_STATUS_OK, FRUMPY_STATUS_OVERFLOW, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
    frumpy_status

  implicit none

  call assert_casting_policy()
  call assert_require_cast_status()
  call assert_safe_scalar_kernels()
  call assert_narrowing_scalar_kernels_are_checked()

contains

  subroutine assert_casting_policy()
    call assert_can_cast(FRUMPY_DTYPE_I32, FRUMPY_DTYPE_I32, &
      FRUMPY_CASTING_NO, "no permits identical dtype")
    call assert_cannot_cast(FRUMPY_DTYPE_I32, FRUMPY_DTYPE_I64, &
      FRUMPY_CASTING_NO, "no rejects conversion")
    call assert_can_cast(FRUMPY_DTYPE_R64, FRUMPY_DTYPE_R64, &
      FRUMPY_CASTING_EQUIV, "equiv permits identical dtype")
    call assert_cannot_cast(FRUMPY_DTYPE_R64, FRUMPY_DTYPE_R32, &
      FRUMPY_CASTING_EQUIV, "equiv rejects conversion")

    call assert_can_cast(FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_R64, &
      FRUMPY_CASTING_SAFE, "safe permits bool to r64")
    call assert_can_cast(FRUMPY_DTYPE_I32, FRUMPY_DTYPE_I64, &
      FRUMPY_CASTING_SAFE, "safe permits i32 to i64")
    call assert_can_cast(FRUMPY_DTYPE_I32, FRUMPY_DTYPE_R64, &
      FRUMPY_CASTING_SAFE, "safe permits i32 to r64")
    call assert_cannot_cast(FRUMPY_DTYPE_I32, FRUMPY_DTYPE_R32, &
      FRUMPY_CASTING_SAFE, "safe rejects i32 to r32")
    call assert_cannot_cast(FRUMPY_DTYPE_R64, FRUMPY_DTYPE_R32, &
      FRUMPY_CASTING_SAFE, "safe rejects r64 to r32")
    call assert_cannot_cast(FRUMPY_DTYPE_I64, FRUMPY_DTYPE_I32, &
      FRUMPY_CASTING_SAFE, "safe rejects i64 to i32")

    call assert_can_cast(FRUMPY_DTYPE_I64, FRUMPY_DTYPE_I32, &
      FRUMPY_CASTING_SAME_KIND, "same_kind permits integer narrowing")
    call assert_can_cast(FRUMPY_DTYPE_R64, FRUMPY_DTYPE_R32, &
      FRUMPY_CASTING_SAME_KIND, "same_kind permits real narrowing")
    call assert_cannot_cast(FRUMPY_DTYPE_R64, FRUMPY_DTYPE_I32, &
      FRUMPY_CASTING_SAME_KIND, "same_kind rejects real to integer")

    call assert_can_cast(FRUMPY_DTYPE_R64, FRUMPY_DTYPE_I32, &
      FRUMPY_CASTING_UNSAFE, "unsafe permits registered pair")
    call assert_cannot_cast(FRUMPY_DTYPE_R64, 999_int32, &
      FRUMPY_CASTING_UNSAFE, "unsafe rejects unknown dtype")
  end subroutine assert_casting_policy

  subroutine assert_require_cast_status()
    type(frumpy_status) :: status
    logical :: allowed

    allowed = require_cast_dtype(FRUMPY_DTYPE_I32, FRUMPY_DTYPE_I64, &
      FRUMPY_CASTING_SAFE, status)
    call assert_true(allowed, "require_cast_dtype allows safe pair")
    call assert_status_code(status, FRUMPY_STATUS_OK, &
      "require_cast_dtype safe pair status")

    allowed = require_cast_dtype(FRUMPY_DTYPE_R64, FRUMPY_DTYPE_R32, &
      FRUMPY_CASTING_SAFE, status)
    call assert_false(allowed, "require_cast_dtype rejects policy mismatch")
    call assert_status_code(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
      "require_cast_dtype policy mismatch status")

    allowed = require_cast_dtype(FRUMPY_DTYPE_R64, 999_int32, &
      FRUMPY_CASTING_UNSAFE, status)
    call assert_false(allowed, "require_cast_dtype rejects unknown dtype")
    call assert_status_code(status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
      "require_cast_dtype unknown dtype status")
  end subroutine assert_require_cast_status

  subroutine assert_safe_scalar_kernels()
    type(frumpy_status) :: status

    call assert_equal_r64(copy_r64_value(3.5_real64, status), 3.5_real64, &
      "copy_r64_value copies value")
    call assert_status_code(status, FRUMPY_STATUS_OK, &
      "copy_r64_value status")

    call assert_equal_i32(cast_bool_to_i32(.true., status), 1_int32, &
      "cast_bool_to_i32 true")
    call assert_status_code(status, FRUMPY_STATUS_OK, &
      "cast_bool_to_i32 true status")
    call assert_equal_i32(cast_bool_to_i32(.false., status), 0_int32, &
      "cast_bool_to_i32 false")
    call assert_status_code(status, FRUMPY_STATUS_OK, &
      "cast_bool_to_i32 false status")

    call assert_equal_i64(cast_i32_to_i64(17_int32, status), 17_int64, &
      "cast_i32_to_i64")
    call assert_status_code(status, FRUMPY_STATUS_OK, &
      "cast_i32_to_i64 status")
    call assert_equal_r64(cast_i32_to_r64(-9_int32, status), -9.0_real64, &
      "cast_i32_to_r64")
    call assert_status_code(status, FRUMPY_STATUS_OK, &
      "cast_i32_to_r64 status")
    call assert_equal_r64(cast_i64_to_r64(23_int64, status), 23.0_real64, &
      "cast_i64_to_r64")
    call assert_status_code(status, FRUMPY_STATUS_OK, &
      "cast_i64_to_r64 status")
    call assert_equal_r64(cast_i64_to_r64(9007199254740993_int64, status), &
      0.0_real64, "cast_i64_to_r64 lossy value returns default")
    call assert_status_code(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
      "cast_i64_to_r64 lossy value status")
    call assert_equal_r64(cast_r32_to_r64(1.25_real32, status), &
      1.25_real64, "cast_r32_to_r64")
    call assert_status_code(status, FRUMPY_STATUS_OK, &
      "cast_r32_to_r64 status")
  end subroutine assert_safe_scalar_kernels

  subroutine assert_narrowing_scalar_kernels_are_checked()
    type(frumpy_status) :: status
    integer(int32) :: narrowed_i32
    real(real32) :: narrowed_r32

    narrowed_i32 = cast_i64_to_i32(42_int64, FRUMPY_CASTING_SAME_KIND, &
      status)
    call assert_equal_i32(narrowed_i32, 42_int32, &
      "cast_i64_to_i32 in range")
    call assert_status_code(status, FRUMPY_STATUS_OK, &
      "cast_i64_to_i32 in range status")

    narrowed_i32 = cast_i64_to_i32(int(huge(0_int32), int64) + 1_int64, &
      FRUMPY_CASTING_SAME_KIND, status)
    call assert_equal_i32(narrowed_i32, 0_int32, &
      "cast_i64_to_i32 overflow returns default")
    call assert_status_code(status, FRUMPY_STATUS_OVERFLOW, &
      "cast_i64_to_i32 overflow status")

    narrowed_i32 = cast_i64_to_i32(7_int64, status=status)
    call assert_equal_i32(narrowed_i32, 0_int32, &
      "cast_i64_to_i32 default safe policy returns default")
    call assert_status_code(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
      "cast_i64_to_i32 default safe policy status")

    narrowed_i32 = cast_r64_to_i32(42.0_real64, FRUMPY_CASTING_UNSAFE, &
      status)
    call assert_equal_i32(narrowed_i32, 42_int32, &
      "cast_r64_to_i32 integral value")
    call assert_status_code(status, FRUMPY_STATUS_OK, &
      "cast_r64_to_i32 integral value status")

    narrowed_i32 = cast_r64_to_i32(42.5_real64, FRUMPY_CASTING_UNSAFE, &
      status)
    call assert_equal_i32(narrowed_i32, 0_int32, &
      "cast_r64_to_i32 fractional value returns default")
    call assert_status_code(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
      "cast_r64_to_i32 fractional value status")

    narrowed_i32 = cast_r64_to_i32(1.0e30_real64, FRUMPY_CASTING_UNSAFE, &
      status)
    call assert_equal_i32(narrowed_i32, 0_int32, &
      "cast_r64_to_i32 overflow returns default")
    call assert_status_code(status, FRUMPY_STATUS_OVERFLOW, &
      "cast_r64_to_i32 overflow status")

    narrowed_r32 = cast_r64_to_r32(1.5_real64, FRUMPY_CASTING_SAME_KIND, &
      status)
    call assert_equal_r32(narrowed_r32, 1.5_real32, &
      "cast_r64_to_r32 exact value")
    call assert_status_code(status, FRUMPY_STATUS_OK, &
      "cast_r64_to_r32 exact value status")

    narrowed_r32 = cast_r64_to_r32(0.1_real64, FRUMPY_CASTING_UNSAFE, &
      status)
    call assert_equal_r32(narrowed_r32, 0.0_real32, &
      "cast_r64_to_r32 lossy value returns default")
    call assert_status_code(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
      "cast_r64_to_r32 lossy value status")
  end subroutine assert_narrowing_scalar_kernels_are_checked

  subroutine assert_can_cast(source_dtype_id, target_dtype_id, casting, &
      message)
    integer(int32), intent(in) :: source_dtype_id
    integer(int32), intent(in) :: target_dtype_id
    integer(int32), intent(in) :: casting
    character(len=*), intent(in) :: message

    call assert_true(can_cast_dtype(source_dtype_id, target_dtype_id, &
      casting), message)
  end subroutine assert_can_cast

  subroutine assert_cannot_cast(source_dtype_id, target_dtype_id, casting, &
      message)
    integer(int32), intent(in) :: source_dtype_id
    integer(int32), intent(in) :: target_dtype_id
    integer(int32), intent(in) :: casting
    character(len=*), intent(in) :: message

    call assert_false(can_cast_dtype(source_dtype_id, target_dtype_id, &
      casting), message)
  end subroutine assert_cannot_cast

  subroutine assert_status_code(status, expected, message)
    type(frumpy_status), intent(in) :: status
    integer(int32), intent(in) :: expected
    character(len=*), intent(in) :: message

    call assert_equal_i32(status%code, expected, message)
    call assert_equal_logical(status%failed, expected /= FRUMPY_STATUS_OK, &
      message // " failed flag")
  end subroutine assert_status_code

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

  subroutine assert_equal_logical(actual, expected, message)
    logical, intent(in) :: actual
    logical, intent(in) :: expected
    character(len=*), intent(in) :: message

    if (actual .neqv. expected) then
      write (*, '(a)') "FAIL: " // message
      error stop 1
    end if
  end subroutine assert_equal_logical

  subroutine assert_equal_i32(actual, expected, message)
    integer(int32), intent(in) :: actual
    integer(int32), intent(in) :: expected
    character(len=*), intent(in) :: message

    if (actual /= expected) then
      write (*, '(a,1x,i0,1x,a,1x,i0)') "FAIL:", actual, "/=", expected
      write (*, '(a)') message
      error stop 1
    end if
  end subroutine assert_equal_i32

  subroutine assert_equal_i64(actual, expected, message)
    integer(int64), intent(in) :: actual
    integer(int64), intent(in) :: expected
    character(len=*), intent(in) :: message

    if (actual /= expected) then
      write (*, '(a,1x,i0,1x,a,1x,i0)') "FAIL:", actual, "/=", expected
      write (*, '(a)') message
      error stop 1
    end if
  end subroutine assert_equal_i64

  subroutine assert_equal_r32(actual, expected, message)
    real(real32), intent(in) :: actual
    real(real32), intent(in) :: expected
    character(len=*), intent(in) :: message

    if (abs(actual - expected) > 0.0_real32) then
      write (*, '(a,1x,es16.8,1x,a,1x,es16.8)') &
        "FAIL:", actual, "/=", expected
      write (*, '(a)') message
      error stop 1
    end if
  end subroutine assert_equal_r32

  subroutine assert_equal_r64(actual, expected, message)
    real(real64), intent(in) :: actual
    real(real64), intent(in) :: expected
    character(len=*), intent(in) :: message

    if (abs(actual - expected) > 0.0_real64) then
      write (*, '(a,1x,es16.8,1x,a,1x,es16.8)') &
        "FAIL:", actual, "/=", expected
      write (*, '(a)') message
      error stop 1
    end if
  end subroutine assert_equal_r64
end program test_casting
