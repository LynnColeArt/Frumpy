program test_searching_r64
  use iso_fortran_env, only: int32, int64, real64
  use frumpy_constructors_r64, only: asarray_r64, empty_r64
  use frumpy_ndarray_i64, only: ndarray_i64
  use frumpy_ndarray_r64, only: ndarray_r64
  use frumpy_searching_r64, only: searchsorted_r64
  use frumpy_statuses, only: FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OK, &
    frumpy_status

  implicit none

  call test_searchsorted_left_and_right()
  call test_searchsorted_values_shapes_and_empty_source()
  call test_searchsorted_status_paths()

contains

  subroutine test_searchsorted_left_and_right()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: values
    type(ndarray_i64) :: indices

    source = asarray_r64([1.0_real64, 3.0_real64, 3.0_real64, 7.0_real64], &
      [4_int64], status=status)
    call assert_status_ok(status, "searchsorted source constructor")

    values = asarray_r64([0.0_real64, 1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 7.0_real64, 8.0_real64], [7_int64], status=status)
    call assert_status_ok(status, "searchsorted values constructor")

    indices = searchsorted_r64(source, values, status=status)
    call assert_status_ok(status, "searchsorted left status")
    call assert_equal_int64_vector(indices%shape, [7_int64], &
      "searchsorted left shape")
    call assert_true(indices%is_c_contiguous, "searchsorted left C flag")
    call assert_close_int64_vector(indices%data, [0_int64, 0_int64, 1_int64, &
        1_int64, 3_int64, 3_int64, 4_int64], "searchsorted left data")

    indices = searchsorted_r64(source, values, side_right=.true., status=status)
    call assert_status_ok(status, "searchsorted right status")
    call assert_close_int64_vector(indices%data, [0_int64, 1_int64, 1_int64, &
        3_int64, 3_int64, 4_int64, 4_int64], "searchsorted right data")
  end subroutine test_searchsorted_left_and_right

  subroutine test_searchsorted_values_shapes_and_empty_source()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: values
    type(ndarray_i64) :: indices

    source = empty_r64([0_int64], status=status)
    call assert_status_ok(status, "searchsorted empty source constructor")

    values = asarray_r64([0.0_real64, 2.0_real64, 4.0_real64, 6.0_real64], &
      [2_int64, 2_int64], status=status)
    call assert_status_ok(status, "searchsorted matrix values constructor")

    indices = searchsorted_r64(source, values, status=status)
    call assert_status_ok(status, "searchsorted empty source status")
    call assert_equal_int64_vector(indices%shape, [2_int64, 2_int64], &
      "searchsorted empty source shape")
    call assert_equal_int64_vector(indices%data, [0_int64, 0_int64, 0_int64, &
        0_int64], "searchsorted empty source data")
  end subroutine test_searchsorted_values_shapes_and_empty_source

  subroutine test_searchsorted_status_paths()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: values
    type(ndarray_i64) :: indices

    source = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, 4.0_real64], &
      [2_int64, 2_int64], status=status)
    call assert_status_ok(status, "searchsorted invalid source constructor")

    values = asarray_r64([1.0_real64], [1_int64], status=status)
    call assert_status_ok(status, "searchsorted status values constructor")

    indices = searchsorted_r64(source, values, status=status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_SHAPE, &
      "searchsorted invalid source status")
  end subroutine test_searchsorted_status_paths

  subroutine assert_status_ok(status, message)
    type(frumpy_status), intent(in) :: status
    character(len=*), intent(in) :: message

    call assert_status_code(status, FRUMPY_STATUS_OK, message)
  end subroutine assert_status_ok

  subroutine assert_status_code(status, expected_code, message)
    type(frumpy_status), intent(in) :: status
    integer(int32), intent(in) :: expected_code
    character(len=*), intent(in) :: message

    if (status%code /= expected_code) then
      write (*, '(a,1x,i0,1x,a,1x,i0)') "FAIL:", status%code, "=/", &
        expected_code
      write (*, '(a)') message
      error stop 1
    end if
  end subroutine assert_status_code

  subroutine assert_true(actual, message)
    logical, intent(in) :: actual
    character(len=*), intent(in) :: message

    if (.not. actual) then
      write (*, '(a)') "FAIL: " // message
      error stop 1
    end if
  end subroutine assert_true

  subroutine assert_equal_int64_vector(actual, expected, message)
    integer(int64), intent(in) :: actual(:)
    integer(int64), intent(in) :: expected(:)
    character(len=*), intent(in) :: message

    if (size(actual) /= size(expected)) then
      write (*, '(a)') "FAIL: " // message
      error stop 1
    end if

    if (any(actual /= expected)) then
      write (*, '(a)') "FAIL: " // message
      write (*, '(a,*(1x,i0))') "actual:", actual
      write (*, '(a,*(1x,i0))') "expected:", expected
      error stop 1
    end if
  end subroutine assert_equal_int64_vector

  subroutine assert_close_int64_vector(actual, expected, message)
    integer(int64), intent(in) :: actual(:)
    integer(int64), intent(in) :: expected(:)
    character(len=*), intent(in) :: message

    call assert_equal_int64_vector(actual, expected, message)
  end subroutine assert_close_int64_vector
end program test_searching_r64
