program test_reductions_r64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
  use iso_fortran_env, only: int32, int64, real64
  use frumpy_constructors_r64, only: asarray_r64, empty_r64
  use frumpy_constants, only: FRUMPY_ORDER_F
  use frumpy_ndarray_r64, only: metadata_descriptor_r64, ndarray_r64
  use frumpy_reductions_r64, only: axis0_to_dim1, max_r64, mean_r64, &
    min_r64, prod_r64, sum_r64
  use frumpy_statuses, only: FRUMPY_STATUS_INVALID_AXIS, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, frumpy_status

  implicit none

  real(real64), parameter :: TOLERANCE = 1.0e-12_real64
  integer(int64) :: scalar_shape(0)

  call test_axis0_validation_helper()
  call test_axis_reductions()
  call test_keepdims_and_all_axes()
  call test_scalar_reductions()
  call test_empty_reduction_behavior()
  call test_strided_reduction_fallbacks()
  call test_reduction_status_paths()

contains

  subroutine test_axis0_validation_helper()
    type(frumpy_status) :: status
    integer(int32) :: dim1

    dim1 = axis0_to_dim1(2_int32, 3_int32, status)
    call assert_status_ok(status, "valid axis0 status")
    call assert_equal_int32(dim1, 3_int32, "valid axis0 converts to dim1")

    dim1 = axis0_to_dim1(-1_int32, 3_int32, status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_AXIS, &
      "negative axis0 status")

    dim1 = axis0_to_dim1(3_int32, 3_int32, status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_AXIS, &
      "axis0 equal to rank status")
  end subroutine test_axis0_validation_helper

  subroutine test_axis_reductions()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: result

    source = matrix_source(status)

    result = sum_r64(source, axis0=0_int32, status=status)
    call assert_status_ok(status, "sum axis0=0 status")
    call assert_equal_int64_vector(result%shape, [3_int64], &
      "sum axis0=0 shape")
    call assert_close_vector(result%data, [5.0_real64, 7.0_real64, &
      9.0_real64], "sum axis0=0 data")

    result = sum_r64(source, axis0=1_int32, status=status)
    call assert_status_ok(status, "sum axis0=1 status")
    call assert_equal_int64_vector(result%shape, [2_int64], &
      "sum axis0=1 shape")
    call assert_close_vector(result%data, [6.0_real64, 15.0_real64], &
      "sum axis0=1 data")

    result = prod_r64(source, axis0=1_int32, status=status)
    call assert_status_ok(status, "prod axis0=1 status")
    call assert_close_vector(result%data, [6.0_real64, 120.0_real64], &
      "prod axis0=1 data")

    result = min_r64(source, axis0=0_int32, status=status)
    call assert_status_ok(status, "min axis0=0 status")
    call assert_close_vector(result%data, [1.0_real64, 2.0_real64, &
      3.0_real64], "min axis0=0 data")

    result = max_r64(source, axis0=1_int32, status=status)
    call assert_status_ok(status, "max axis0=1 status")
    call assert_close_vector(result%data, [3.0_real64, 6.0_real64], &
      "max axis0=1 data")

    result = mean_r64(source, axis0=0_int32, status=status)
    call assert_status_ok(status, "mean axis0=0 status")
    call assert_close_vector(result%data, [2.5_real64, 3.5_real64, &
      4.5_real64], "mean axis0=0 data")
  end subroutine test_axis_reductions

  subroutine test_keepdims_and_all_axes()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: result

    source = matrix_source(status)

    result = sum_r64(source, axis0=1_int32, keepdims=.true., status=status)
    call assert_status_ok(status, "sum axis keepdims status")
    call assert_equal_int64_vector(result%shape, [2_int64, 1_int64], &
      "sum axis keepdims shape")
    call assert_close_vector(result%data, [6.0_real64, 15.0_real64], &
      "sum axis keepdims data")

    result = sum_r64(source, keepdims=.true., status=status)
    call assert_status_ok(status, "sum all keepdims status")
    call assert_equal_int64_vector(result%shape, [1_int64, 1_int64], &
      "sum all keepdims shape")
    call assert_close_vector(result%data, [21.0_real64], &
      "sum all keepdims data")

    result = mean_r64(source, status=status)
    call assert_status_ok(status, "mean all status")
    call assert_equal_int64_vector(result%shape, scalar_shape, &
      "mean all scalar shape")
    call assert_close_vector(result%data, [3.5_real64], "mean all data")
  end subroutine test_keepdims_and_all_axes

  subroutine test_scalar_reductions()
    type(frumpy_status) :: status
    type(ndarray_r64) :: scalar
    type(ndarray_r64) :: result

    scalar = asarray_r64([7.0_real64], scalar_shape, status=status)
    call assert_status_ok(status, "scalar constructor")

    result = sum_r64(scalar, status=status)
    call assert_status_ok(status, "scalar sum status")
    call assert_equal_int64_vector(result%shape, scalar_shape, &
      "scalar sum shape")
    call assert_close_vector(result%data, [7.0_real64], "scalar sum data")

    result = sum_r64(scalar, axis0=0_int32, status=status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_AXIS, &
      "scalar axis0 reduction status")
  end subroutine test_scalar_reductions

  subroutine test_empty_reduction_behavior()
    type(frumpy_status) :: status
    type(ndarray_r64) :: empty_matrix
    type(ndarray_r64) :: result

    empty_matrix = empty_r64([0_int64, 3_int64], status=status)
    call assert_status_ok(status, "empty matrix constructor")

    result = sum_r64(empty_matrix, axis0=0_int32, status=status)
    call assert_status_ok(status, "empty sum axis0=0 status")
    call assert_equal_int64_vector(result%shape, [3_int64], &
      "empty sum axis0=0 shape")
    call assert_close_vector(result%data, [0.0_real64, 0.0_real64, &
      0.0_real64], "empty sum axis0=0 data")

    result = prod_r64(empty_matrix, axis0=0_int32, status=status)
    call assert_status_ok(status, "empty prod axis0=0 status")
    call assert_close_vector(result%data, [1.0_real64, 1.0_real64, &
      1.0_real64], "empty prod axis0=0 data")

    result = mean_r64(empty_matrix, axis0=0_int32, status=status)
    call assert_status_ok(status, "empty mean axis0=0 status")
    call assert_all_nan(result%data, "empty mean axis0=0 data")

    result = min_r64(empty_matrix, axis0=0_int32, status=status)
    call assert_status_code(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
      "empty min axis0=0 status")

    result = max_r64(empty_matrix, axis0=1_int32, status=status)
    call assert_status_ok(status, "empty max axis0=1 status")
    call assert_equal_int64_vector(result%shape, [0_int64], &
      "empty max axis0=1 shape")
    call assert_equal_int64(result%storage_size(), 0_int64, &
      "empty max axis0=1 storage")
  end subroutine test_empty_reduction_behavior

  subroutine test_strided_reduction_fallbacks()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: result

    source = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "Fortran order source constructor")

    result = sum_r64(source, axis0=0_int32, status=status)
    call assert_status_ok(status, "Fortran order sum status")
    call assert_close_vector(result%data, [5.0_real64, 7.0_real64, &
      9.0_real64], "Fortran order sum data")

    source = asarray_r64([10.0_real64, 20.0_real64, 30.0_real64], &
      status=status)
    call assert_status_ok(status, "negative stride source constructor")
    source%offset = 3_int64
    source%strides = [-1_int64]
    source%is_c_contiguous = .false.
    source%is_f_contiguous = .false.

    result = sum_r64(source, axis0=0_int32, status=status)
    call assert_status_ok(status, "negative stride sum status")
    call assert_close_vector(result%data, [60.0_real64], &
      "negative stride sum data")
  end subroutine test_strided_reduction_fallbacks

  subroutine test_reduction_status_paths()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: result

    source = matrix_source(status)

    result = sum_r64(source, axis0=2_int32, status=status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_AXIS, &
      "invalid high axis0 reduction status")

    result = sum_r64(source, axis0=-1_int32, status=status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_AXIS, &
      "invalid negative axis0 reduction status")

    source = metadata_descriptor_r64([2_int64], [1_int64], 1_int64, status)
    call assert_status_ok(status, "metadata descriptor status")

    result = sum_r64(source, status=status)
    call assert_status_code(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
      "missing storage reduction status")
  end subroutine test_reduction_status_paths

  function matrix_source(status) result(source)
    type(frumpy_status), intent(out) :: status
    type(ndarray_r64) :: source

    source = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      status=status)
    call assert_status_ok(status, "matrix source constructor")
  end function matrix_source

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

  subroutine assert_equal_int32(actual, expected, message)
    integer(int32), intent(in) :: actual
    integer(int32), intent(in) :: expected
    character(len=*), intent(in) :: message

    if (actual /= expected) then
      write (*, '(a)') "FAIL: " // message
      error stop 1
    end if
  end subroutine assert_equal_int32

  subroutine assert_equal_int64(actual, expected, message)
    integer(int64), intent(in) :: actual
    integer(int64), intent(in) :: expected
    character(len=*), intent(in) :: message

    if (actual /= expected) then
      write (*, '(a)') "FAIL: " // message
      error stop 1
    end if
  end subroutine assert_equal_int64

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

  subroutine assert_all_nan(actual, message)
    real(real64), intent(in) :: actual(:)
    character(len=*), intent(in) :: message

    if (.not. all(ieee_is_nan(actual))) then
      write (*, '(a)') "FAIL: " // message
      error stop 1
    end if
  end subroutine assert_all_nan
end program test_reductions_r64
