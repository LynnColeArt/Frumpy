program test_shape
  use iso_fortran_env, only: int32, int64
  use fenum_constants, only: FENUM_MAX_RANK
  use fenum_shape, only: element_count, has_zero_extent, is_scalar_shape, &
    is_valid_shape, shape_rank, validate_shape
  use fenum_statuses, only: FENUM_STATUS_INVALID_SHAPE, &
    FENUM_STATUS_OVERFLOW, fenum_status

  implicit none

  integer(int64) :: scalar_shape(0)
  integer(int64) :: empty_shape(2)
  integer(int64) :: singleton_shape(1)
  integer(int64) :: multidim_shape(3)
  integer(int64) :: invalid_shape(2)
  integer(int64) :: overflow_shape(2)
  integer(int64) :: too_many_dims(FENUM_MAX_RANK + 1_int32)
  type(fenum_status) :: status
  integer(int64) :: count

  empty_shape = [0_int64, 3_int64]
  singleton_shape = [1_int64]
  multidim_shape = [2_int64, 3_int64, 4_int64]
  invalid_shape = [2_int64, -1_int64]
  overflow_shape = [huge(1_int64), 2_int64]
  too_many_dims = 1_int64

  call validate_shape(scalar_shape, status)
  call assert_true(status%is_ok(), "scalar shape validates")
  call assert_true(is_scalar_shape(scalar_shape), "scalar shape is rank zero")
  call assert_equal_int32(shape_rank(scalar_shape, status), 0_int32, &
    "scalar shape rank")
  call assert_true(status%is_ok(), "scalar shape rank status")
  call assert_equal_int64(element_count(scalar_shape, status), 1_int64, &
    "scalar element count")
  call assert_true(status%is_ok(), "scalar element count status")

  call validate_shape(empty_shape, status)
  call assert_true(status%is_ok(), "empty shape validates")
  call assert_true(has_zero_extent(empty_shape), "empty shape has zero extent")
  call assert_equal_int32(shape_rank(empty_shape, status), 2_int32, &
    "empty shape rank")
  call assert_equal_int64(element_count(empty_shape, status), 0_int64, &
    "empty shape element count")
  call assert_true(status%is_ok(), "empty element count status")

  call assert_true(is_valid_shape(singleton_shape), "singleton shape valid")
  call assert_equal_int64(element_count(singleton_shape, status), 1_int64, &
    "singleton element count")
  call assert_true(status%is_ok(), "singleton element count status")

  call assert_true(is_valid_shape(multidim_shape), "multidim shape valid")
  call assert_equal_int32(shape_rank(multidim_shape, status), 3_int32, &
    "multidim shape rank")
  call assert_equal_int64(element_count(multidim_shape, status), 24_int64, &
    "multidim element count")
  call assert_true(status%is_ok(), "multidim element count status")

  call validate_shape(invalid_shape, status)
  call assert_true(status%is_failure(), "negative shape fails validation")
  call assert_equal_int32(status%code, FENUM_STATUS_INVALID_SHAPE, &
    "negative shape status code")
  call assert_false(is_valid_shape(invalid_shape), "negative shape invalid")
  count = element_count(invalid_shape, status)
  call assert_equal_int64(count, 0_int64, "negative shape count")
  call assert_equal_int32(status%code, FENUM_STATUS_INVALID_SHAPE, &
    "negative shape count status")

  call validate_shape(too_many_dims, status)
  call assert_true(status%is_failure(), "rank over max fails validation")
  call assert_equal_int32(status%code, FENUM_STATUS_INVALID_SHAPE, &
    "rank over max status code")

  count = element_count(overflow_shape, status)
  call assert_equal_int64(count, 0_int64, "overflow count returns zero")
  call assert_equal_int32(status%code, FENUM_STATUS_OVERFLOW, &
    "overflow status code")

contains

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
end program test_shape
