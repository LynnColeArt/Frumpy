program test_ndarray_r64
  use iso_fortran_env, only: int32, int64
  use frumpy, only: FRUMPY_ORDER_C, FRUMPY_ORDER_F, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    frumpy_status, metadata_descriptor_r64, ndarray_r64, &
    owned_descriptor_r64
  use frumpy_dtypes, only: FRUMPY_DTYPE_R64

  implicit none

  integer(int64) :: scalar_shape(0)
  integer(int64) :: empty_shape(2)
  integer(int64) :: matrix_shape(2)
  integer(int64) :: negative_strides(1)
  type(frumpy_status) :: status
  type(ndarray_r64) :: array

  empty_shape = [0_int64, 3_int64]
  matrix_shape = [2_int64, 3_int64]
  negative_strides = [-1_int64]

  array = owned_descriptor_r64(scalar_shape, status=status)
  call assert_true(status%is_ok(), "scalar descriptor status")
  call assert_descriptor_metadata(array, 0_int32, scalar_shape, &
    scalar_shape, 1_int64, .true., .true., .true., "scalar descriptor")
  call assert_true(array%has_storage(), "scalar descriptor has storage")
  call assert_equal_int64(array%size(), 1_int64, "scalar descriptor size")
  call assert_equal_int64(array%storage_size(), 1_int64, &
    "scalar descriptor storage size")

  array = owned_descriptor_r64(empty_shape, status=status)
  call assert_true(status%is_ok(), "empty descriptor status")
  call assert_descriptor_metadata(array, 2_int32, empty_shape, &
    [0_int64, 0_int64], 1_int64, .true., .true., .true., &
    "empty descriptor")
  call assert_true(array%has_storage(), "empty descriptor has storage")
  call assert_equal_int64(array%size(), 0_int64, "empty descriptor size")
  call assert_equal_int64(array%storage_size(), 0_int64, &
    "empty descriptor storage size")

  array = owned_descriptor_r64(matrix_shape, FRUMPY_ORDER_C, status)
  call assert_true(status%is_ok(), "C descriptor status")
  call assert_descriptor_metadata(array, 2_int32, matrix_shape, &
    [3_int64, 1_int64], 1_int64, .true., .true., .false., &
    "C-order matrix descriptor")
  call assert_equal_int64(array%size(), 6_int64, "C descriptor size")
  call assert_equal_int64(array%storage_size(), 6_int64, &
    "C descriptor storage size")

  array = owned_descriptor_r64(matrix_shape, FRUMPY_ORDER_F, status)
  call assert_true(status%is_ok(), "F descriptor status")
  call assert_descriptor_metadata(array, 2_int32, matrix_shape, &
    [1_int64, 2_int64], 1_int64, .true., .false., .true., &
    "Fortran-order matrix descriptor")

  array = metadata_descriptor_r64([3_int64], negative_strides, 3_int64, &
    status)
  call assert_true(status%is_ok(), "metadata descriptor status")
  call assert_descriptor_metadata(array, 1_int32, [3_int64], &
    negative_strides, 3_int64, .false., .false., .false., &
    "negative-stride metadata descriptor")
  call assert_false(array%has_storage(), "metadata descriptor has no storage")
  call assert_equal_int64(array%storage_size(), 0_int64, &
    "metadata descriptor storage size")

  array = owned_descriptor_r64([2_int64, -1_int64], status=status)
  call assert_true(status%is_failure(), "negative shape descriptor fails")
  call assert_equal_int32(status%code, FRUMPY_STATUS_INVALID_SHAPE, &
    "negative shape descriptor status code")

  array = metadata_descriptor_r64([2_int64, 3_int64], [1_int64], 1_int64, &
    status)
  call assert_true(status%is_failure(), "rank mismatch descriptor fails")
  call assert_equal_int32(status%code, FRUMPY_STATUS_INVALID_SHAPE, &
    "rank mismatch descriptor status code")

  array = metadata_descriptor_r64([3_int64], [1_int64], 0_int64, status)
  call assert_true(status%is_failure(), "zero offset descriptor fails")
  call assert_equal_int32(status%code, FRUMPY_STATUS_INVALID_SHAPE, &
    "zero offset descriptor status code")

  array = owned_descriptor_r64([2_int64, 3_int64], order=99_int32, &
    status=status)
  call assert_true(status%is_failure(), "unsupported order fails")
  call assert_equal_int32(status%code, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    "unsupported order status code")

contains

  subroutine assert_descriptor_metadata(array, expected_rank, expected_shape, &
      expected_strides, expected_offset, expected_owns_data, &
      expected_is_c_contiguous, expected_is_f_contiguous, message)
    type(ndarray_r64), intent(in) :: array
    integer(int32), intent(in) :: expected_rank
    integer(int64), intent(in) :: expected_shape(:)
    integer(int64), intent(in) :: expected_strides(:)
    integer(int64), intent(in) :: expected_offset
    logical, intent(in) :: expected_owns_data
    logical, intent(in) :: expected_is_c_contiguous
    logical, intent(in) :: expected_is_f_contiguous
    character(len=*), intent(in) :: message

    call assert_equal_int32(array%dtype_id, FRUMPY_DTYPE_R64, &
      message // " dtype")
    call assert_equal_int32(array%rank, expected_rank, &
      message // " rank")
    call assert_equal_vector(array%shape, expected_shape, &
      message // " shape")
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
end program test_ndarray_r64
