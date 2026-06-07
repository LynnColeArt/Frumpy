program test_constructors_r64
  use iso_fortran_env, only: int32, int64, real64
  use frumpy, only: FRUMPY_ORDER_A, FRUMPY_ORDER_C, FRUMPY_ORDER_F, &
    FRUMPY_ORDER_K, FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, arange_r64, asarray_r64, &
    ascontiguousarray_r64, copy_r64, empty_r64, frumpy_status, full_r64, &
    linspace_r64, metadata_descriptor_r64, ndarray_r64, ones_r64, zeros_r64

  implicit none

  real(real64), parameter :: TOLERANCE = 1.0e-12_real64

  call test_empty_constructor()
  call test_fill_constructors()
  call test_arange_constructor()
  call test_linspace_constructor()
  call test_asarray_constructor()
  call test_copy_constructor()
  call test_ascontiguousarray_constructor()
  call test_constructor_status_paths()

contains

  subroutine test_empty_constructor()
    type(frumpy_status) :: status
    type(ndarray_r64) :: array

    array = empty_r64([2_int64, 3_int64], FRUMPY_ORDER_C, status)

    call assert_status_ok(status, "empty_r64 status")
    call assert_equal_int32(array%rank, 2_int32, "empty_r64 rank")
    call assert_equal_int64_vector(array%shape, [2_int64, 3_int64], &
      "empty_r64 shape")
    call assert_equal_int64_vector(array%strides, [3_int64, 1_int64], &
      "empty_r64 C strides")
    call assert_true(array%owns_data, "empty_r64 owns data")
    call assert_true(array%has_storage(), "empty_r64 has storage")
    call assert_equal_int64(array%storage_size(), 6_int64, &
      "empty_r64 storage size")
  end subroutine test_empty_constructor

  subroutine test_fill_constructors()
    type(frumpy_status) :: status
    type(ndarray_r64) :: array

    array = zeros_r64([2_int64, 3_int64], status=status)
    call assert_status_ok(status, "zeros_r64 status")
    call assert_close_vector(array%data, &
      [0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, &
        0.0_real64], "zeros_r64 data")

    array = ones_r64([2_int64, 2_int64], status=status)
    call assert_status_ok(status, "ones_r64 status")
    call assert_close_vector(array%data, &
      [1.0_real64, 1.0_real64, 1.0_real64, 1.0_real64], &
      "ones_r64 data")

    array = full_r64([2_int64, 3_int64], 2.5_real64, FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "full_r64 status")
    call assert_equal_int64_vector(array%strides, [1_int64, 2_int64], &
      "full_r64 F strides")
    call assert_close_vector(array%data, &
      [2.5_real64, 2.5_real64, 2.5_real64, 2.5_real64, 2.5_real64, &
        2.5_real64], "full_r64 data")
  end subroutine test_fill_constructors

  subroutine test_arange_constructor()
    type(frumpy_status) :: status
    type(ndarray_r64) :: array

    array = arange_r64(0.0_real64, 5.0_real64, status=status)
    call assert_status_ok(status, "arange default step status")
    call assert_equal_int64_vector(array%shape, [5_int64], &
      "arange default step shape")
    call assert_close_vector(array%data, &
      [0.0_real64, 1.0_real64, 2.0_real64, 3.0_real64, 4.0_real64], &
      "arange default step data")

    array = arange_r64(5.0_real64, 0.0_real64, -2.0_real64, status)
    call assert_status_ok(status, "arange negative step status")
    call assert_close_vector(array%data, &
      [5.0_real64, 3.0_real64, 1.0_real64], &
      "arange negative step data")

    array = arange_r64(0.0_real64, 1.0_real64, 0.25_real64, status)
    call assert_status_ok(status, "arange fractional step status")
    call assert_close_vector(array%data, &
      [0.0_real64, 0.25_real64, 0.5_real64, 0.75_real64], &
      "arange fractional step data")

    array = arange_r64(5.0_real64, 0.0_real64, status=status)
    call assert_status_ok(status, "arange empty direction status")
    call assert_equal_int64_vector(array%shape, [0_int64], &
      "arange empty direction shape")
    call assert_equal_int64(array%storage_size(), 0_int64, &
      "arange empty direction storage")
  end subroutine test_arange_constructor

  subroutine test_linspace_constructor()
    type(frumpy_status) :: status
    type(ndarray_r64) :: array

    array = linspace_r64(0.0_real64, 1.0_real64, 5_int64, status=status)
    call assert_status_ok(status, "linspace endpoint status")
    call assert_close_vector(array%data, &
      [0.0_real64, 0.25_real64, 0.5_real64, 0.75_real64, 1.0_real64], &
      "linspace endpoint data")

    array = linspace_r64(0.0_real64, 1.0_real64, 4_int64, .false., status)
    call assert_status_ok(status, "linspace no endpoint status")
    call assert_close_vector(array%data, &
      [0.0_real64, 0.25_real64, 0.5_real64, 0.75_real64], &
      "linspace no endpoint data")

    array = linspace_r64(2.0_real64, 9.0_real64, 1_int64, status=status)
    call assert_status_ok(status, "linspace singleton status")
    call assert_close_vector(array%data, [2.0_real64], &
      "linspace singleton data")

    array = linspace_r64(2.0_real64, 9.0_real64, 0_int64, status=status)
    call assert_status_ok(status, "linspace empty status")
    call assert_equal_int64_vector(array%shape, [0_int64], &
      "linspace empty shape")
  end subroutine test_linspace_constructor

  subroutine test_asarray_constructor()
    type(frumpy_status) :: status
    type(ndarray_r64) :: array

    array = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64], &
      status=status)
    call assert_status_ok(status, "asarray vector status")
    call assert_equal_int64_vector(array%shape, [3_int64], &
      "asarray vector shape")
    call assert_close_vector(array%data, &
      [1.0_real64, 2.0_real64, 3.0_real64], "asarray vector data")

    array = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      FRUMPY_ORDER_C, status)
    call assert_status_ok(status, "asarray C matrix status")
    call assert_equal_int64_vector(array%strides, [3_int64, 1_int64], &
      "asarray C matrix strides")
    call assert_close_vector(array%data, &
      [1.0_real64, 2.0_real64, 3.0_real64, 4.0_real64, 5.0_real64, &
        6.0_real64], "asarray C matrix storage")

    array = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "asarray F matrix status")
    call assert_equal_int64_vector(array%strides, [1_int64, 2_int64], &
      "asarray F matrix strides")
    call assert_close_vector(array%data, &
      [1.0_real64, 4.0_real64, 2.0_real64, 5.0_real64, 3.0_real64, &
        6.0_real64], "asarray F matrix storage")
  end subroutine test_asarray_constructor

  subroutine test_copy_constructor()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: copied

    source = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      FRUMPY_ORDER_C, status)
    call assert_status_ok(status, "copy source status")

    copied = copy_r64(source, FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "copy to F status")
    call assert_equal_int64_vector(copied%strides, [1_int64, 2_int64], &
      "copy to F strides")
    call assert_close_vector(copied%data, &
      [1.0_real64, 4.0_real64, 2.0_real64, 5.0_real64, 3.0_real64, &
        6.0_real64], "copy to F storage")

    source%data(1) = 99.0_real64
    call assert_close_vector(copied%data, &
      [1.0_real64, 4.0_real64, 2.0_real64, 5.0_real64, 3.0_real64, &
        6.0_real64], "copy is independent")

    copied = copy_r64(source, FRUMPY_ORDER_A, status)
    call assert_status_ok(status, "copy A order status")
    call assert_equal_int64_vector(copied%strides, [3_int64, 1_int64], &
      "copy A order keeps C source C")

    source = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "copy F source status")

    copied = copy_r64(source, FRUMPY_ORDER_K, status)
    call assert_status_ok(status, "copy K order status")
    call assert_equal_int64_vector(copied%strides, [1_int64, 2_int64], &
      "copy K order preserves F source")
  end subroutine test_copy_constructor

  subroutine test_ascontiguousarray_constructor()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: contiguous

    source = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "ascontiguous source status")

    contiguous = ascontiguousarray_r64(source, status)
    call assert_status_ok(status, "ascontiguous status")
    call assert_equal_int64_vector(contiguous%strides, [3_int64, 1_int64], &
      "ascontiguous strides")
    call assert_true(contiguous%is_c_contiguous, "ascontiguous C flag")
    call assert_close_vector(contiguous%data, &
      [1.0_real64, 2.0_real64, 3.0_real64, 4.0_real64, 5.0_real64, &
        6.0_real64], "ascontiguous storage")
  end subroutine test_ascontiguousarray_constructor

  subroutine test_constructor_status_paths()
    type(frumpy_status) :: status
    type(ndarray_r64) :: array

    array = zeros_r64([2_int64, -1_int64], status=status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_SHAPE, &
      "zeros_r64 invalid shape status")

    array = arange_r64(0.0_real64, 1.0_real64, 0.0_real64, status)
    call assert_status_code(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
      "arange_r64 zero step status")

    array = linspace_r64(0.0_real64, 1.0_real64, -1_int64, status=status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_SHAPE, &
      "linspace_r64 negative num status")

    array = asarray_r64([1.0_real64, 2.0_real64], [3_int64], &
      status=status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_SHAPE, &
      "asarray_r64 shape mismatch status")

    array = metadata_descriptor_r64([3_int64], [1_int64], 1_int64, &
      status)
    call assert_status_ok(status, "metadata descriptor without storage")
    array = copy_r64(array, status=status)
    call assert_status_code(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
      "copy_r64 no source storage status")

    array = zeros_r64([2_int64, 2_int64], order=99_int32, status=status)
    call assert_status_code(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
      "zeros_r64 unsupported order status")

    array = copy_r64(array, order=99_int32, status=status)
    call assert_status_code(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
      "copy_r64 unsupported order status")
  end subroutine test_constructor_status_paths

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

    if ((expected_code == FRUMPY_STATUS_OK) .neqv. status%is_ok()) then
      write (*, '(a)') "FAIL: " // message
      write (*, '(a,l1)') "status ok flag: ", status%is_ok()
      error stop 1
    end if
  end subroutine assert_status_code

  subroutine assert_true(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not. condition) then
      write (*, '(a)') "FAIL: " // message
      error stop 1
    end if
  end subroutine assert_true

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

  subroutine assert_equal_int64_vector(actual, expected, message)
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
  end subroutine assert_equal_int64_vector

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
end program test_constructors_r64
