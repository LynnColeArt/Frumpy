program test_ndarray_r32
  use iso_fortran_env, only: int32, int64, real32
  use frumpy, only: FRUMPY_ORDER_C, FRUMPY_ORDER_F, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    frumpy_status, metadata_descriptor_r32, ndarray_r32, &
    owned_descriptor_r32, view_descriptor_r32
  use frumpy_dtypes, only: FRUMPY_DTYPE_R32

  implicit none

  integer(int64) :: scalar_shape(0)
  type(frumpy_status) :: status
  type(ndarray_r32) :: source
  type(ndarray_r32) :: array

  array = owned_descriptor_r32(scalar_shape, status=status)
  call assert_true(status%is_ok(), "scalar r32 descriptor status")
  call assert_descriptor_metadata(array, 0_int32, scalar_shape, &
    scalar_shape, 1_int64, .true., .true., .true., "scalar r32")
  call assert_true(array%has_storage(), "scalar r32 has storage")
  call assert_equal_int64(array%storage_size(), 1_int64, &
    "scalar r32 storage size")
  array%data(1) = 1.5_real32
  call assert_equal_r32(array%data(1), 1.5_real32, "r32 storage kind")

  array = owned_descriptor_r32([0_int64, 3_int64], status=status)
  call assert_true(status%is_ok(), "empty r32 descriptor status")
  call assert_descriptor_metadata(array, 2_int32, [0_int64, 3_int64], &
    [0_int64, 0_int64], 1_int64, .true., .true., .true., "empty r32")
  call assert_equal_int64(array%size(), 0_int64, "empty r32 size")
  call assert_equal_int64(array%storage_size(), 0_int64, &
    "empty r32 storage size")

  array = owned_descriptor_r32([2_int64, 3_int64], FRUMPY_ORDER_C, status)
  call assert_true(status%is_ok(), "C-order r32 descriptor status")
  call assert_descriptor_metadata(array, 2_int32, [2_int64, 3_int64], &
    [3_int64, 1_int64], 1_int64, .true., .true., .false., &
    "C-order r32")

  array = owned_descriptor_r32([2_int64, 3_int64], FRUMPY_ORDER_F, status)
  call assert_true(status%is_ok(), "F-order r32 descriptor status")
  call assert_descriptor_metadata(array, 2_int32, [2_int64, 3_int64], &
    [1_int64, 2_int64], 1_int64, .true., .false., .true., &
    "F-order r32")

  array = metadata_descriptor_r32([3_int64], [-1_int64], 3_int64, status)
  call assert_true(status%is_ok(), "metadata r32 descriptor status")
  call assert_descriptor_metadata(array, 1_int32, [3_int64], [-1_int64], &
    3_int64, .false., .false., .false., "metadata r32")
  call assert_false(array%has_storage(), "metadata r32 has no storage")

  source = owned_descriptor_r32([4_int64], status=status)
  call assert_true(status%is_ok(), "source r32 descriptor status")
  array = view_descriptor_r32(source, [2_int64], [1_int64], 2_int64, status)
  call assert_true(status%is_ok(), "view r32 descriptor status")
  call assert_descriptor_metadata(array, 1_int32, [2_int64], [1_int64], &
    2_int64, .false., .true., .true., "view r32")
  call assert_true(array%has_storage(), "view r32 shares storage")

  array = owned_descriptor_r32([2_int64, -1_int64], status=status)
  call assert_true(status%is_failure(), "negative r32 shape fails")
  call assert_equal_int32(status%code, FRUMPY_STATUS_INVALID_SHAPE, &
    "negative r32 shape status code")

  array = metadata_descriptor_r32([2_int64, 3_int64], [1_int64], 1_int64, &
    status)
  call assert_true(status%is_failure(), "r32 rank mismatch fails")
  call assert_equal_int32(status%code, FRUMPY_STATUS_INVALID_SHAPE, &
    "r32 rank mismatch status code")

  array = metadata_descriptor_r32([3_int64], [1_int64], 0_int64, status)
  call assert_true(status%is_failure(), "r32 zero offset fails")
  call assert_equal_int32(status%code, FRUMPY_STATUS_INVALID_SHAPE, &
    "r32 zero offset status code")

  array = owned_descriptor_r32([2_int64, 3_int64], order=99_int32, &
    status=status)
  call assert_true(status%is_failure(), "unsupported r32 order fails")
  call assert_equal_int32(status%code, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    "unsupported r32 order status code")

contains

  subroutine assert_descriptor_metadata(array, expected_rank, expected_shape, &
      expected_strides, expected_offset, expected_owns_data, &
      expected_is_c_contiguous, expected_is_f_contiguous, message)
    type(ndarray_r32), intent(in) :: array
    integer(int32), intent(in) :: expected_rank
    integer(int64), intent(in) :: expected_shape(:)
    integer(int64), intent(in) :: expected_strides(:)
    integer(int64), intent(in) :: expected_offset
    logical, intent(in) :: expected_owns_data
    logical, intent(in) :: expected_is_c_contiguous
    logical, intent(in) :: expected_is_f_contiguous
    character(len=*), intent(in) :: message

    call assert_equal_int32(array%dtype_id, FRUMPY_DTYPE_R32, &
      message // " dtype")
    call assert_equal_int32(array%rank, expected_rank, message // " rank")
    call assert_equal_vector(array%shape, expected_shape, message // " shape")
    call assert_equal_vector(array%strides, expected_strides, &
      message // " strides")
    call assert_equal_int64(array%offset, expected_offset, &
      message // " offset")
    call assert_equal_logical(array%owns_data, expected_owns_data, &
      message // " ownership")
    call assert_equal_logical(array%is_c_contiguous, &
      expected_is_c_contiguous, message // " C-contiguous")
    call assert_equal_logical(array%is_f_contiguous, &
      expected_is_f_contiguous, message // " F-contiguous")
  end subroutine assert_descriptor_metadata

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

  subroutine assert_equal_r32(actual, expected, message)
    real(real32), intent(in) :: actual
    real(real32), intent(in) :: expected
    character(len=*), intent(in) :: message

    if (abs(actual - expected) > 0.0_real32) then
      write (*, '(a)') "FAIL: " // message
      error stop 1
    end if
  end subroutine assert_equal_r32

  subroutine assert_equal_vector(actual, expected, message)
    integer(int64), intent(in) :: actual(:)
    integer(int64), intent(in) :: expected(:)
    character(len=*), intent(in) :: message

    if (size(actual) /= size(expected)) then
      write (*, '(a)') "FAIL: " // message
      error stop 1
    end if

    if (any(actual /= expected)) then
      write (*, '(a)') "FAIL: " // message
      error stop 1
    end if
  end subroutine assert_equal_vector
end program test_ndarray_r32
