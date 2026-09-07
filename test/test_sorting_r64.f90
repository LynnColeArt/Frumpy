program test_sorting_r64
  use iso_fortran_env, only: int32, int64, real64
  use frumpy_constructors_r64, only: asarray_r64, empty_r64
  use frumpy_constants, only: FRUMPY_ORDER_F
  use frumpy_ndarray_i64, only: ndarray_i64
  use frumpy_ndarray_r64, only: ndarray_r64
  use frumpy_sorting_r64, only: argsort_r64, sort_r64
  use frumpy_statuses, only: FRUMPY_STATUS_INVALID_AXIS, FRUMPY_STATUS_OK, &
    frumpy_status

  implicit none

  real(real64), parameter :: TOLERANCE = 1.0e-12_real64

  call test_sort_c_order_axis_last()
  call test_sort_f_order_axis_last()
  call test_sort_axis0_and_argsort_cases()
  call test_sort_repeated_values_and_empty_inputs()
  call test_sort_status_paths()

contains

  subroutine test_sort_c_order_axis_last()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: sorted
    type(ndarray_i64) :: indices

    source = asarray_r64([3.0_real64, 1.0_real64, 2.0_real64, &
        6.0_real64, 5.0_real64, 4.0_real64], [2_int64, 3_int64], &
      status=status)
    call assert_status_ok(status, "sort C source constructor")

    sorted = sort_r64(source, status=status)
    call assert_status_ok(status, "sort C status")
    call assert_equal_int64_vector(sorted%shape, [2_int64, 3_int64], &
      "sort C shape")
    call assert_true(sorted%is_c_contiguous, "sort C flag")
    call assert_close_vector(sorted%data, [1.0_real64, 2.0_real64, &
        3.0_real64, 4.0_real64, 5.0_real64, 6.0_real64], &
      "sort C data")

    indices = argsort_r64(source, status=status)
    call assert_status_ok(status, "argsort C status")
    call assert_equal_int64_vector(indices%shape, [2_int64, 3_int64], &
      "argsort C shape")
    call assert_true(indices%is_c_contiguous, "argsort C flag")
    call assert_close_int64_vector(indices%data, [1_int64, 2_int64, 0_int64, &
        2_int64, 1_int64, 0_int64], "argsort C data")
  end subroutine test_sort_c_order_axis_last

  subroutine test_sort_f_order_axis_last()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: sorted
    type(ndarray_i64) :: indices

    source = asarray_r64([3.0_real64, 1.0_real64, 2.0_real64, &
        6.0_real64, 5.0_real64, 4.0_real64], [2_int64, 3_int64], &
      FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "sort F source constructor")

    sorted = sort_r64(source, status=status)
    call assert_status_ok(status, "sort F status")
    call assert_equal_int64_vector(sorted%shape, [2_int64, 3_int64], &
      "sort F shape")
    call assert_true(sorted%is_f_contiguous, "sort F flag")
    call assert_false(sorted%is_c_contiguous, "sort F C flag")
    call assert_equal_int64_vector(sorted%strides, [1_int64, 2_int64], &
      "sort F strides")
    call assert_close_vector(sorted%data, [1.0_real64, 4.0_real64, &
        2.0_real64, 5.0_real64, 3.0_real64, 6.0_real64], &
      "sort F data")

    indices = argsort_r64(source, status=status)
    call assert_status_ok(status, "argsort F status")
    call assert_equal_int64_vector(indices%shape, [2_int64, 3_int64], &
      "argsort F shape")
    call assert_true(indices%is_c_contiguous, "argsort F flag")
    call assert_false(indices%is_f_contiguous, "argsort F F flag")
    call assert_close_int64_vector(indices%data, [1_int64, 2_int64, 0_int64, &
        2_int64, 1_int64, 0_int64], "argsort F data")
  end subroutine test_sort_f_order_axis_last

  subroutine test_sort_axis0_and_argsort_cases()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: sorted
    type(ndarray_i64) :: indices

    source = asarray_r64([6.0_real64, 1.0_real64, 4.0_real64, &
        3.0_real64, 5.0_real64, 2.0_real64], [2_int64, 3_int64], &
      status=status)
    call assert_status_ok(status, "sort axis0 source constructor")

    sorted = sort_r64(source, axis0=0_int32, status=status)
    call assert_status_ok(status, "sort axis0 status")
    call assert_equal_int64_vector(sorted%shape, [2_int64, 3_int64], &
      "sort axis0 shape")
    call assert_true(sorted%is_c_contiguous, "sort axis0 flag")
    call assert_close_vector(sorted%data, [3.0_real64, 1.0_real64, &
        2.0_real64, 6.0_real64, 5.0_real64, 4.0_real64], &
      "sort axis0 data")

    indices = argsort_r64(source, axis0=0_int32, status=status)
    call assert_status_ok(status, "argsort axis0 status")
    call assert_equal_int64_vector(indices%shape, [2_int64, 3_int64], &
      "argsort axis0 shape")
    call assert_close_int64_vector(indices%data, [1_int64, 0_int64, &
        1_int64, 0_int64, 1_int64, 0_int64], "argsort axis0 data")
  end subroutine test_sort_axis0_and_argsort_cases

  subroutine test_sort_repeated_values_and_empty_inputs()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: sorted
    type(ndarray_i64) :: indices
    type(ndarray_r64) :: empty_source
    type(ndarray_r64) :: empty_sorted
    type(ndarray_i64) :: empty_indices

    source = asarray_r64([3.0_real64, 1.0_real64, 3.0_real64, &
        2.0_real64, 3.0_real64, 1.0_real64], [6_int64], status=status)
    call assert_status_ok(status, "sort repeated source constructor")

    sorted = sort_r64(source, status=status)
    call assert_status_ok(status, "sort repeated status")
    call assert_equal_int64_vector(sorted%shape, [6_int64], &
      "sort repeated shape")
    call assert_close_vector(sorted%data, [1.0_real64, 1.0_real64, &
        2.0_real64, 3.0_real64, 3.0_real64, 3.0_real64], &
      "sort repeated data")

    indices = argsort_r64(source, status=status)
    call assert_status_ok(status, "argsort repeated status")
    call assert_equal_int64_vector(indices%shape, [6_int64], &
      "argsort repeated shape")
    call assert_argsort_values(source, indices, [1.0_real64, 1.0_real64, &
        2.0_real64, 3.0_real64, 3.0_real64, 3.0_real64], &
      "argsort repeated gather")

    empty_source = empty_r64([0_int64, 3_int64], FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "sort empty source constructor")

    empty_sorted = sort_r64(empty_source, status=status)
    call assert_status_ok(status, "sort empty status")
    call assert_equal_int64_vector(empty_sorted%shape, [0_int64, 3_int64], &
      "sort empty shape")
    call assert_equal_int64(empty_sorted%size(), 0_int64, "sort empty size")

    empty_indices = argsort_r64(empty_source, status=status)
    call assert_status_ok(status, "argsort empty status")
    call assert_equal_int64_vector(empty_indices%shape, [0_int64, 3_int64], &
      "argsort empty shape")
    call assert_equal_int64(empty_indices%size(), 0_int64, &
      "argsort empty size")
  end subroutine test_sort_repeated_values_and_empty_inputs

  subroutine test_sort_status_paths()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: sorted
    type(ndarray_i64) :: indices

    source = asarray_r64([3.0_real64, 1.0_real64, 2.0_real64, &
        6.0_real64, 5.0_real64, 4.0_real64], [2_int64, 3_int64], &
      status=status)
    call assert_status_ok(status, "sort status source constructor")

    sorted = sort_r64(source, axis0=2_int32, status=status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_AXIS, &
      "sort invalid axis status")

    indices = argsort_r64(source, axis0=-3_int32, status=status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_AXIS, &
      "argsort invalid axis status")
  end subroutine test_sort_status_paths

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
      write (*, '(a,1x,i0,1x,a,1x,i0)') "FAIL:", status%code, &
        "/=", expected_code
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

  subroutine assert_false(actual, message)
    logical, intent(in) :: actual
    character(len=*), intent(in) :: message

    if (actual) then
      write (*, '(a)') "FAIL: " // message
      error stop 1
    end if
  end subroutine assert_false

  subroutine assert_close_vector(actual, expected, message)
    real(real64), intent(in) :: actual(:)
    real(real64), intent(in) :: expected(:)
    character(len=*), intent(in) :: message

    if (size(actual) /= size(expected)) then
      write (*, '(a)') "FAIL: " // message
      error stop 1
    end if

    if (any(abs(actual - expected) > TOLERANCE)) then
      write (*, '(a)') "FAIL: " // message
      write (*, '(a,*(1x,es16.8))') "actual:", actual
      write (*, '(a,*(1x,es16.8))') "expected:", expected
      error stop 1
    end if
  end subroutine assert_close_vector

  subroutine assert_close_int64_vector(actual, expected, message)
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
  end subroutine assert_close_int64_vector

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

  subroutine assert_equal_int64(actual, expected, message)
    integer(int64), intent(in) :: actual
    integer(int64), intent(in) :: expected
    character(len=*), intent(in) :: message

    if (actual /= expected) then
      write (*, '(a)') "FAIL: " // message
      write (*, '(a,1x,i0,1x,a,1x,i0)') "actual", actual, "/=", expected
      error stop 1
    end if
  end subroutine assert_equal_int64

  subroutine assert_argsort_values(source, indices, expected, message)
    type(ndarray_r64), intent(in) :: source
    type(ndarray_i64), intent(in) :: indices
    real(real64), intent(in) :: expected(:)
    character(len=*), intent(in) :: message
    real(real64), allocatable :: actual(:)
    integer(int64) :: item1

    allocate(actual(size(expected)))
    do item1 = 1_int64, int(size(expected), int64)
      actual(item1) = source%data(indices%data(item1) + 1_int64)
    end do

    call assert_close_vector(actual, expected, message)
  end subroutine assert_argsort_values
end program test_sorting_r64
