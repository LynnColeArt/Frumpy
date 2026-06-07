program test_elementwise_r64
  use iso_fortran_env, only: int32, int64, real64
  use fenum_constructors_r64, only: asarray_r64, empty_r64
  use fenum_constants, only: FENUM_ORDER_F
  use fenum_elementwise_r64, only: abs_r64, add_r64, cos_r64, divide_r64, &
    exp_r64, log_r64, multiply_r64, negate_r64, sin_r64, sqrt_r64, &
    subtract_r64
  use fenum_ndarray_r64, only: metadata_descriptor_r64, ndarray_r64
  use fenum_statuses, only: FENUM_STATUS_INVALID_SHAPE, &
    FENUM_STATUS_UNSUPPORTED_BEHAVIOR, FENUM_STATUS_OK, fenum_status

  implicit none

  real(real64), parameter :: TOLERANCE = 1.0e-12_real64
  real(real64), parameter :: PI = acos(-1.0_real64)
  integer(int64) :: scalar_shape(0)

  call test_binary_broadcast_kernels()
  call test_scalar_broadcast_kernel()
  call test_zero_extent_broadcast_kernel()
  call test_fortran_order_strided_fallback()
  call test_manual_negative_stride_fallback()
  call test_unary_kernels()
  call test_elementwise_status_paths()

contains

  subroutine test_binary_broadcast_kernels()
    type(fenum_status) :: status
    type(ndarray_r64) :: lhs
    type(ndarray_r64) :: rhs
    type(ndarray_r64) :: result

    lhs = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      status=status)
    call assert_status_ok(status, "binary lhs constructor")

    rhs = asarray_r64([10.0_real64, 20.0_real64, 30.0_real64], &
      [3_int64], status=status)
    call assert_status_ok(status, "binary rhs constructor")

    result = add_r64(lhs, rhs, status)
    call assert_status_ok(status, "add_r64 status")
    call assert_equal_int64_vector(result%shape, [2_int64, 3_int64], &
      "add_r64 shape")
    call assert_close_vector(result%data, &
      [11.0_real64, 22.0_real64, 33.0_real64, 14.0_real64, &
        25.0_real64, 36.0_real64], "add_r64 data")

    result = subtract_r64(lhs, rhs, status)
    call assert_status_ok(status, "subtract_r64 status")
    call assert_close_vector(result%data, &
      [-9.0_real64, -18.0_real64, -27.0_real64, -6.0_real64, &
        -15.0_real64, -24.0_real64], "subtract_r64 data")

    result = multiply_r64(lhs, rhs, status)
    call assert_status_ok(status, "multiply_r64 status")
    call assert_close_vector(result%data, &
      [10.0_real64, 40.0_real64, 90.0_real64, 40.0_real64, &
        100.0_real64, 180.0_real64], "multiply_r64 data")

    result = divide_r64(lhs, rhs, status)
    call assert_status_ok(status, "divide_r64 status")
    call assert_close_vector(result%data, &
      [0.1_real64, 0.1_real64, 0.1_real64, 0.4_real64, 0.25_real64, &
        0.2_real64], "divide_r64 data")
  end subroutine test_binary_broadcast_kernels

  subroutine test_scalar_broadcast_kernel()
    type(fenum_status) :: status
    type(ndarray_r64) :: scalar
    type(ndarray_r64) :: vector
    type(ndarray_r64) :: result

    scalar = asarray_r64([2.0_real64], scalar_shape, status=status)
    call assert_status_ok(status, "scalar constructor")

    vector = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64], &
      status=status)
    call assert_status_ok(status, "vector constructor")

    result = multiply_r64(scalar, vector, status)
    call assert_status_ok(status, "scalar multiply status")
    call assert_equal_int64_vector(result%shape, [3_int64], &
      "scalar multiply shape")
    call assert_close_vector(result%data, &
      [2.0_real64, 4.0_real64, 6.0_real64], "scalar multiply data")
  end subroutine test_scalar_broadcast_kernel

  subroutine test_zero_extent_broadcast_kernel()
    type(fenum_status) :: status
    type(ndarray_r64) :: lhs
    type(ndarray_r64) :: rhs
    type(ndarray_r64) :: result

    lhs = empty_r64([0_int64, 3_int64], status=status)
    call assert_status_ok(status, "zero extent lhs constructor")

    rhs = asarray_r64([10.0_real64, 20.0_real64, 30.0_real64], &
      [1_int64, 3_int64], status=status)
    call assert_status_ok(status, "zero extent rhs constructor")

    result = add_r64(lhs, rhs, status)
    call assert_status_ok(status, "zero extent add status")
    call assert_equal_int64_vector(result%shape, [0_int64, 3_int64], &
      "zero extent add shape")
    call assert_equal_int64(result%storage_size(), 0_int64, &
      "zero extent add storage")
  end subroutine test_zero_extent_broadcast_kernel

  subroutine test_fortran_order_strided_fallback()
    type(fenum_status) :: status
    type(ndarray_r64) :: lhs
    type(ndarray_r64) :: rhs
    type(ndarray_r64) :: result

    lhs = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      FENUM_ORDER_F, status)
    call assert_status_ok(status, "Fortran lhs constructor")

    rhs = asarray_r64([10.0_real64, 20.0_real64], [2_int64, 1_int64], &
      status=status)
    call assert_status_ok(status, "column rhs constructor")

    result = add_r64(lhs, rhs, status)
    call assert_status_ok(status, "Fortran strided add status")
    call assert_close_vector(result%data, &
      [11.0_real64, 12.0_real64, 13.0_real64, 24.0_real64, &
        25.0_real64, 26.0_real64], "Fortran strided add data")
  end subroutine test_fortran_order_strided_fallback

  subroutine test_manual_negative_stride_fallback()
    type(fenum_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: result

    source = asarray_r64([10.0_real64, 20.0_real64, 30.0_real64], &
      status=status)
    call assert_status_ok(status, "negative stride source constructor")
    source%offset = 3_int64
    source%strides = [-1_int64]
    source%is_c_contiguous = .false.
    source%is_f_contiguous = .false.

    result = negate_r64(source, status)
    call assert_status_ok(status, "negative stride negate status")
    call assert_close_vector(result%data, &
      [-30.0_real64, -20.0_real64, -10.0_real64], &
      "negative stride negate data")
  end subroutine test_manual_negative_stride_fallback

  subroutine test_unary_kernels()
    type(fenum_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: result

    source = asarray_r64([-1.0_real64, 0.0_real64, 4.0_real64], &
      status=status)
    call assert_status_ok(status, "unary source constructor")

    result = abs_r64(source, status)
    call assert_status_ok(status, "abs_r64 status")
    call assert_close_vector(result%data, &
      [1.0_real64, 0.0_real64, 4.0_real64], "abs_r64 data")

    result = sqrt_r64(abs_r64(source), status)
    call assert_status_ok(status, "sqrt_r64 status")
    call assert_close_vector(result%data, &
      [1.0_real64, 0.0_real64, 2.0_real64], "sqrt_r64 data")

    source = asarray_r64([1.0_real64, exp(1.0_real64)], status=status)
    call assert_status_ok(status, "log source constructor")
    result = log_r64(source, status)
    call assert_status_ok(status, "log_r64 status")
    call assert_close_vector(result%data, [0.0_real64, 1.0_real64], &
      "log_r64 data")

    source = asarray_r64([0.0_real64, 1.0_real64], status=status)
    call assert_status_ok(status, "exp source constructor")
    result = exp_r64(source, status)
    call assert_status_ok(status, "exp_r64 status")
    call assert_close_vector(result%data, [1.0_real64, exp(1.0_real64)], &
      "exp_r64 data")

    source = asarray_r64([0.0_real64, PI / 2.0_real64, PI], &
      status=status)
    call assert_status_ok(status, "trig source constructor")

    result = sin_r64(source, status)
    call assert_status_ok(status, "sin_r64 status")
    call assert_close_vector(result%data, &
      [0.0_real64, 1.0_real64, 0.0_real64], "sin_r64 data")

    result = cos_r64(source, status)
    call assert_status_ok(status, "cos_r64 status")
    call assert_close_vector(result%data, &
      [1.0_real64, 0.0_real64, -1.0_real64], "cos_r64 data")
  end subroutine test_unary_kernels

  subroutine test_elementwise_status_paths()
    type(fenum_status) :: status
    type(ndarray_r64) :: lhs
    type(ndarray_r64) :: rhs
    type(ndarray_r64) :: result

    lhs = asarray_r64([1.0_real64, 2.0_real64], [2_int64], &
      status=status)
    call assert_status_ok(status, "status lhs constructor")

    rhs = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64], &
      [3_int64], status=status)
    call assert_status_ok(status, "status rhs constructor")

    result = add_r64(lhs, rhs, status)
    call assert_status_code(status, FENUM_STATUS_INVALID_SHAPE, &
      "incompatible add status")

    rhs = metadata_descriptor_r64([2_int64], [1_int64], 1_int64, status)
    call assert_status_ok(status, "metadata descriptor status")
    result = add_r64(lhs, rhs, status)
    call assert_status_code(status, FENUM_STATUS_UNSUPPORTED_BEHAVIOR, &
      "missing storage add status")
  end subroutine test_elementwise_status_paths

  subroutine assert_status_ok(status, message)
    type(fenum_status), intent(in) :: status
    character(len=*), intent(in) :: message

    call assert_status_code(status, FENUM_STATUS_OK, message)
  end subroutine assert_status_ok

  subroutine assert_status_code(status, expected_code, message)
    type(fenum_status), intent(in) :: status
    integer(int32), intent(in) :: expected_code
    character(len=*), intent(in) :: message

    if (status%code /= expected_code) then
      write (*, '(a,1x,i0,1x,a,1x,i0)') "FAIL:", status%code, &
        "/=", expected_code
      write (*, '(a)') message
      error stop 1
    end if
  end subroutine assert_status_code

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
      write (*, '(a,1x,i0,1x,a,1x,i0)') "FAIL:", actual, "/=", expected
      write (*, '(a)') message
      error stop 1
    end if
  end subroutine assert_equal_int64

  subroutine assert_close_vector(actual, expected, message)
    real(real64), intent(in) :: actual(:)
    real(real64), intent(in) :: expected(:)
    character(len=*), intent(in) :: message

    if (size(actual) /= size(expected)) then
      write (*, '(a)') "FAIL: " // message
      write (*, '(a,1x,i0,1x,a,1x,i0)') "size:", size(actual), &
        "/=", size(expected)
      error stop 1
    end if

    if (any(abs(actual - expected) > TOLERANCE)) then
      write (*, '(a)') "FAIL: " // message
      write (*, '(a,*(1x,es12.5))') "actual:", actual
      write (*, '(a,*(1x,es12.5))') "expected:", expected
      error stop 1
    end if
  end subroutine assert_close_vector
end program test_elementwise_r64
