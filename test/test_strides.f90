program test_strides
  use iso_fortran_env, only: int32, int64
  use fenum_statuses, only: FENUM_STATUS_INVALID_SHAPE, &
    FENUM_STATUS_OVERFLOW, fenum_status
  use fenum_strides, only: c_order_strides, f_order_strides, &
    has_negative_stride, is_c_contiguous, is_f_contiguous

  implicit none

  integer(int64) :: scalar_shape(0)
  integer(int64) :: empty_shape(2)
  integer(int64) :: matrix_shape(2)
  integer(int64) :: singleton_row_shape(2)
  integer(int64) :: singleton_col_shape(2)
  integer(int64) :: negative_strides(2)
  integer(int64) :: singleton_negative_stride(1)
  integer(int64) :: overflow_shape(3)
  integer(int64), allocatable :: strides(:)
  type(fenum_status) :: status
  logical :: is_contiguous

  empty_shape = [0_int64, 3_int64]
  matrix_shape = [2_int64, 3_int64]
  singleton_row_shape = [1_int64, 3_int64]
  singleton_col_shape = [3_int64, 1_int64]
  negative_strides = [3_int64, -1_int64]
  singleton_negative_stride = [-1_int64]
  overflow_shape = [2_int64, huge(1_int64), 2_int64]

  strides = c_order_strides(scalar_shape, status)
  call assert_true(status%is_ok(), "scalar C strides status")
  call assert_equal_int32(int(size(strides), int32), 0_int32, &
    "scalar C stride rank")
  call assert_true(is_c_contiguous(scalar_shape, strides, status), &
    "scalar is C-contiguous")
  call assert_true(status%is_ok(), "scalar C-contiguous status")
  call assert_true(is_f_contiguous(scalar_shape, strides, status), &
    "scalar is F-contiguous")

  strides = c_order_strides(empty_shape, status)
  call assert_true(status%is_ok(), "empty C strides status")
  call assert_equal_vector(strides, [0_int64, 0_int64], "empty C strides")
  call assert_true(is_c_contiguous(empty_shape, strides, status), &
    "empty is C-contiguous")
  call assert_true(is_f_contiguous(empty_shape, strides, status), &
    "empty is F-contiguous")

  strides = c_order_strides(matrix_shape, status)
  call assert_true(status%is_ok(), "matrix C strides status")
  call assert_equal_vector(strides, [3_int64, 1_int64], "matrix C strides")
  call assert_true(is_c_contiguous(matrix_shape, strides, status), &
    "matrix C strides are C-contiguous")
  call assert_false(is_f_contiguous(matrix_shape, strides, status), &
    "matrix C strides are not F-contiguous")

  strides = f_order_strides(matrix_shape, status)
  call assert_true(status%is_ok(), "matrix F strides status")
  call assert_equal_vector(strides, [1_int64, 2_int64], "matrix F strides")
  call assert_true(is_f_contiguous(matrix_shape, strides, status), &
    "matrix F strides are F-contiguous")
  call assert_false(is_c_contiguous(matrix_shape, strides, status), &
    "matrix F strides are not C-contiguous")

  strides = c_order_strides(singleton_row_shape, status)
  call assert_equal_vector(strides, [3_int64, 1_int64], &
    "singleton row C strides")
  call assert_true(is_c_contiguous(singleton_row_shape, strides, status), &
    "singleton row C-contiguous")
  call assert_true(is_f_contiguous(singleton_row_shape, strides, status), &
    "singleton row also F-contiguous")

  strides = f_order_strides(singleton_col_shape, status)
  call assert_equal_vector(strides, [1_int64, 3_int64], &
    "singleton column F strides")
  call assert_true(is_c_contiguous(singleton_col_shape, strides, status), &
    "singleton column also C-contiguous")
  call assert_true(is_f_contiguous(singleton_col_shape, strides, status), &
    "singleton column F-contiguous")

  call assert_true(has_negative_stride(negative_strides), &
    "negative strides are representable")
  call assert_false(is_c_contiguous(matrix_shape, negative_strides, status), &
    "negative stride matrix is not C-contiguous")
  call assert_true(status%is_ok(), "negative stride contiguity status")
  call assert_true(is_c_contiguous([1_int64], singleton_negative_stride, &
    status), "singleton negative stride can be C-contiguous")
  call assert_true(is_f_contiguous([1_int64], singleton_negative_stride, &
    status), "singleton negative stride can be F-contiguous")

  is_contiguous = is_c_contiguous([2_int64, 3_int64], [1_int64], status)
  call assert_false(is_contiguous, "rank mismatch is not contiguous")
  call assert_equal_int32(status%code, FENUM_STATUS_INVALID_SHAPE, &
    "rank mismatch status code")

  strides = c_order_strides(overflow_shape, status)
  call assert_equal_int32(status%code, FENUM_STATUS_OVERFLOW, &
    "C stride overflow status")
  call assert_equal_vector(strides, [0_int64, 0_int64, 0_int64], &
    "C stride overflow returns zero strides")

  strides = f_order_strides(overflow_shape, status)
  call assert_equal_int32(status%code, FENUM_STATUS_OVERFLOW, &
    "F stride overflow status")
  call assert_equal_vector(strides, [0_int64, 0_int64, 0_int64], &
    "F stride overflow returns zero strides")

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

  subroutine assert_equal_vector(actual, expected, message)
    integer(int64), intent(in) :: actual(:)
    integer(int64), intent(in) :: expected(:)
    character(len=*), intent(in) :: message

    if (size(actual) /= size(expected)) then
      write (*, '(a)') "FAIL: " // message
      write (*, '(a,1x,i0,1x,a,1x,i0)') "size:", size(actual), &
        "/=", size(expected)
      error stop 1
    end if

    if (any(actual /= expected)) then
      write (*, '(a)') "FAIL: " // message
      write (*, '(a,*(1x,i0))') "actual:", actual
      write (*, '(a,*(1x,i0))') "expected:", expected
      error stop 1
    end if
  end subroutine assert_equal_vector
end program test_strides
