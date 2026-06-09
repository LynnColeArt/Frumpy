program test_ndarray_bool
  use iso_fortran_env, only: int32, int64
  use frumpy, only: FRUMPY_ORDER_C, FRUMPY_ORDER_F, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    frumpy_status, metadata_descriptor_bool, ndarray_bool, &
    owned_descriptor_bool, view_descriptor_bool
  use frumpy_dtypes, only: FRUMPY_DTYPE_BOOL

  implicit none

  integer(int64) :: scalar_shape(0)
  type(frumpy_status) :: status
  type(ndarray_bool) :: source
  type(ndarray_bool) :: array

  array = owned_descriptor_bool(scalar_shape, status=status)
  call assert_true(status%is_ok(), "scalar bool descriptor status")
  call assert_descriptor_metadata(array, 0_int32, scalar_shape, &
    scalar_shape, 1_int64, .true., .true., .true., "scalar bool")
  call assert_true(array%has_storage(), "scalar bool has storage")
  call assert_equal_int64(array%storage_size(), 1_int64, &
    "scalar bool storage size")
  array%data(1) = .true.
  call assert_true(array%data(1), "bool storage kind")

  array = owned_descriptor_bool([0_int64, 3_int64], status=status)
  call assert_true(status%is_ok(), "empty bool descriptor status")
  call assert_descriptor_metadata(array, 2_int32, [0_int64, 3_int64], &
    [0_int64, 0_int64], 1_int64, .true., .true., .true., "empty bool")
  call assert_equal_int64(array%size(), 0_int64, "empty bool size")
  call assert_equal_int64(array%storage_size(), 0_int64, &
    "empty bool storage size")

  array = owned_descriptor_bool([2_int64, 3_int64], FRUMPY_ORDER_C, status)
  call assert_true(status%is_ok(), "C-order bool descriptor status")
  call assert_descriptor_metadata(array, 2_int32, [2_int64, 3_int64], &
    [3_int64, 1_int64], 1_int64, .true., .true., .false., &
    "C-order bool")

  array = owned_descriptor_bool([2_int64, 3_int64], FRUMPY_ORDER_F, status)
  call assert_true(status%is_ok(), "F-order bool descriptor status")
  call assert_descriptor_metadata(array, 2_int32, [2_int64, 3_int64], &
    [1_int64, 2_int64], 1_int64, .true., .false., .true., &
    "F-order bool")

  array = metadata_descriptor_bool([3_int64], [-1_int64], 3_int64, status)
  call assert_true(status%is_ok(), "metadata bool descriptor status")
  call assert_descriptor_metadata(array, 1_int32, [3_int64], [-1_int64], &
    3_int64, .false., .false., .false., "metadata bool")
  call assert_false(array%has_storage(), "metadata bool has no storage")

  source = owned_descriptor_bool([4_int64], status=status)
  call assert_true(status%is_ok(), "source bool descriptor status")
  array = view_descriptor_bool(source, [2_int64], [1_int64], 2_int64, status)
  call assert_true(status%is_ok(), "view bool descriptor status")
  call assert_descriptor_metadata(array, 1_int32, [2_int64], [1_int64], &
    2_int64, .false., .true., .true., "view bool")
  call assert_true(array%has_storage(), "view bool shares storage")

  call assert_invalid_descriptors()

contains

  subroutine assert_invalid_descriptors()
    type(ndarray_bool) :: invalid_array
    type(frumpy_status) :: invalid_status

    invalid_array = owned_descriptor_bool([2_int64, -1_int64], &
      status=invalid_status)
    call assert_true(invalid_status%is_failure(), &
      "negative bool shape fails")
    call assert_equal_int32(invalid_status%code, FRUMPY_STATUS_INVALID_SHAPE, &
      "negative bool shape status code")

    invalid_array = metadata_descriptor_bool([2_int64, 3_int64], [1_int64], &
      1_int64, invalid_status)
    call assert_true(invalid_status%is_failure(), &
      "bool rank mismatch fails")
    call assert_equal_int32(invalid_status%code, FRUMPY_STATUS_INVALID_SHAPE, &
      "bool rank mismatch status code")

    invalid_array = metadata_descriptor_bool([3_int64], [1_int64], 0_int64, &
      invalid_status)
    call assert_true(invalid_status%is_failure(), "bool zero offset fails")
    call assert_equal_int32(invalid_status%code, FRUMPY_STATUS_INVALID_SHAPE, &
      "bool zero offset status code")

    invalid_array = owned_descriptor_bool([2_int64, 3_int64], &
      order=99_int32, status=invalid_status)
    call assert_true(invalid_status%is_failure(), &
      "unsupported bool order fails")
    call assert_equal_int32(invalid_status%code, &
      FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
      "unsupported bool order status code")
  end subroutine assert_invalid_descriptors

  subroutine assert_descriptor_metadata(array, expected_rank, expected_shape, &
      expected_strides, expected_offset, expected_owns_data, &
      expected_is_c_contiguous, expected_is_f_contiguous, message)
    type(ndarray_bool), intent(in) :: array
    integer(int32), intent(in) :: expected_rank
    integer(int64), intent(in) :: expected_shape(:)
    integer(int64), intent(in) :: expected_strides(:)
    integer(int64), intent(in) :: expected_offset
    logical, intent(in) :: expected_owns_data
    logical, intent(in) :: expected_is_c_contiguous
    logical, intent(in) :: expected_is_f_contiguous
    character(len=*), intent(in) :: message

    call assert_equal_int32(array%dtype_id, FRUMPY_DTYPE_BOOL, &
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

  subroutine assert_equal_vector(actual, expected, message)
    integer(int64), intent(in) :: actual(:)
    integer(int64), intent(in) :: expected(:)
    character(len=*), intent(in) :: message

    if (size(actual) /= size(expected) .or. any(actual /= expected)) then
      write (*, '(a)') "FAIL: " // message
      error stop 1
    end if
  end subroutine assert_equal_vector
end program test_ndarray_bool
