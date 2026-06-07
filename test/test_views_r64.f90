program test_views_r64
  use iso_fortran_env, only: int32, int64, real64
  use frumpy_constructors_r64, only: asarray_r64
  use frumpy_ndarray_r64, only: metadata_descriptor_r64, ndarray_r64
  use frumpy_slices, only: slice_all, slice_range, slice_spec
  use frumpy_statuses, only: FRUMPY_STATUS_INVALID_AXIS, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, frumpy_status
  use frumpy_views_r64, only: expand_dims_r64, flatten_r64, ravel_r64, &
    reshape_r64, slice_r64, squeeze_r64, swapaxes_r64, transpose_r64

  implicit none

  real(real64), parameter :: TOLERANCE = 1.0e-12_real64

  call test_reshape_view_shares_storage()
  call test_ravel_and_flatten_copy_behavior()
  call test_transpose_and_swapaxes_views()
  call test_squeeze_and_expand_dims_views()
  call test_slice_views_and_negative_strides()
  call test_view_status_paths()

contains

  subroutine test_reshape_view_shares_storage()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: view

    source = matrix_source(status)

    view = reshape_r64(source, [3_int64, 2_int64], status)
    call assert_status_ok(status, "reshape status")
    call assert_equal_int64_vector(view%shape, [3_int64, 2_int64], &
      "reshape shape")
    call assert_equal_int64_vector(view%strides, [2_int64, 1_int64], &
      "reshape strides")
    call assert_false(view%owns_data, "reshape view ownership")
    call assert_same_storage(source, view, "reshape shares storage")
    call assert_logical_values(view, [1.0_real64, 2.0_real64, 3.0_real64, &
      4.0_real64, 5.0_real64, 6.0_real64], "reshape logical values")

    view%data(view%offset) = 99.0_real64
    call assert_close_scalar(source%data(1), 99.0_real64, &
      "reshape mutation reaches source")
  end subroutine test_reshape_view_shares_storage

  subroutine test_ravel_and_flatten_copy_behavior()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: transposed
    type(ndarray_r64) :: raveled
    type(ndarray_r64) :: flattened

    source = matrix_source(status)

    raveled = ravel_r64(source, status)
    call assert_status_ok(status, "contiguous ravel status")
    call assert_equal_int64_vector(raveled%shape, [6_int64], &
      "contiguous ravel shape")
    call assert_false(raveled%owns_data, "contiguous ravel ownership")
    call assert_same_storage(source, raveled, "contiguous ravel storage")

    raveled%data(2) = 22.0_real64
    call assert_close_scalar(source%data(2), 22.0_real64, &
      "contiguous ravel mutation reaches source")

    flattened = flatten_r64(source, status)
    call assert_status_ok(status, "flatten status")
    call assert_true(flattened%owns_data, "flatten ownership")
    call assert_logical_values(flattened, [1.0_real64, 22.0_real64, &
      3.0_real64, 4.0_real64, 5.0_real64, 6.0_real64], "flatten data")

    flattened%data(1) = -1.0_real64
    call assert_close_scalar(source%data(1), 1.0_real64, &
      "flatten mutation does not reach source")

    source = matrix_source(status)
    transposed = transpose_r64(source, status)
    call assert_status_ok(status, "transpose before ravel status")

    raveled = ravel_r64(transposed, status)
    call assert_status_ok(status, "non-contiguous ravel status")
    call assert_true(raveled%owns_data, "non-contiguous ravel owns copy")
    call assert_logical_values(raveled, [1.0_real64, 4.0_real64, &
      2.0_real64, 5.0_real64, 3.0_real64, 6.0_real64], &
      "non-contiguous ravel data")

    raveled%data(1) = -5.0_real64
    call assert_close_scalar(source%data(1), 1.0_real64, &
      "non-contiguous ravel copy mutation does not reach source")
  end subroutine test_ravel_and_flatten_copy_behavior

  subroutine test_transpose_and_swapaxes_views()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: transposed
    type(ndarray_r64) :: swapped

    source = matrix_source(status)

    transposed = transpose_r64(source, status)
    call assert_status_ok(status, "transpose status")
    call assert_equal_int64_vector(transposed%shape, [3_int64, 2_int64], &
      "transpose shape")
    call assert_equal_int64_vector(transposed%strides, [1_int64, 3_int64], &
      "transpose strides")
    call assert_same_storage(source, transposed, "transpose shares storage")
    call assert_logical_values(transposed, [1.0_real64, 4.0_real64, &
      2.0_real64, 5.0_real64, 3.0_real64, 6.0_real64], &
      "transpose logical values")

    swapped = swapaxes_r64(source, 0_int32, 1_int32, status)
    call assert_status_ok(status, "swapaxes status")
    call assert_equal_int64_vector(swapped%shape, transposed%shape, &
      "swapaxes shape")
    call assert_equal_int64_vector(swapped%strides, transposed%strides, &
      "swapaxes strides")
    call assert_same_storage(source, swapped, "swapaxes shares storage")
  end subroutine test_transpose_and_swapaxes_views

  subroutine test_squeeze_and_expand_dims_views()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: squeezed
    type(ndarray_r64) :: expanded

    source = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], &
      [1_int64, 2_int64, 1_int64, 3_int64], status=status)
    call assert_status_ok(status, "squeeze source constructor")

    squeezed = squeeze_r64(source, status=status)
    call assert_status_ok(status, "squeeze all status")
    call assert_equal_int64_vector(squeezed%shape, [2_int64, 3_int64], &
      "squeeze all shape")
    call assert_same_storage(source, squeezed, "squeeze shares storage")
    call assert_logical_values(squeezed, [1.0_real64, 2.0_real64, &
      3.0_real64, 4.0_real64, 5.0_real64, 6.0_real64], &
      "squeeze logical values")

    expanded = expand_dims_r64(squeezed, 1_int32, status)
    call assert_status_ok(status, "expand dims status")
    call assert_equal_int64_vector(expanded%shape, &
      [2_int64, 1_int64, 3_int64], "expand dims shape")
    call assert_same_storage(source, expanded, "expand dims shares storage")

    squeezed = squeeze_r64(expanded, axis0=1_int32, status=status)
    call assert_status_ok(status, "squeeze axis status")
    call assert_equal_int64_vector(squeezed%shape, [2_int64, 3_int64], &
      "squeeze axis shape")
  end subroutine test_squeeze_and_expand_dims_views

  subroutine test_slice_views_and_negative_strides()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: sliced
    type(slice_spec) :: specs(2)

    source = matrix_source(status)

    specs = [slice_range(1_int64, 2_int64, status=status), slice_all()]
    call assert_status_ok(status, "row slice spec status")
    sliced = slice_r64(source, specs, status)
    call assert_status_ok(status, "row slice status")
    call assert_equal_int64_vector(sliced%shape, [1_int64, 3_int64], &
      "row slice shape")
    call assert_equal_int64_vector(sliced%strides, [3_int64, 1_int64], &
      "row slice strides")
    call assert_same_storage(source, sliced, "row slice shares storage")
    call assert_logical_values(sliced, [4.0_real64, 5.0_real64, &
      6.0_real64], "row slice logical values")

    specs = [slice_all(), slice_range(2_int64, -1_int64, -1_int64, status)]
    call assert_status_ok(status, "negative slice spec status")
    sliced = slice_r64(source, specs, status)
    call assert_status_ok(status, "negative slice status")
    call assert_equal_int64_vector(sliced%shape, [2_int64, 3_int64], &
      "negative slice shape")
    call assert_equal_int64_vector(sliced%strides, [3_int64, -1_int64], &
      "negative slice strides")
    call assert_logical_values(sliced, [3.0_real64, 2.0_real64, &
      1.0_real64, 6.0_real64, 5.0_real64, 4.0_real64], &
      "negative slice logical values")

    sliced%data(sliced%offset) = 33.0_real64
    call assert_close_scalar(source%data(3), 33.0_real64, &
      "negative slice mutation reaches source")

    specs = [slice_all(), slice_range(3_int64, 3_int64, status=status)]
    call assert_status_ok(status, "empty slice spec status")
    sliced = slice_r64(source, specs, status)
    call assert_status_ok(status, "empty slice status")
    call assert_equal_int64_vector(sliced%shape, [2_int64, 0_int64], &
      "empty slice shape")
    call assert_equal_int64(sliced%size(), 0_int64, "empty slice size")
  end subroutine test_slice_views_and_negative_strides

  subroutine test_view_status_paths()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: transposed
    type(ndarray_r64) :: result
    type(slice_spec) :: specs(1)

    source = matrix_source(status)

    result = reshape_r64(source, [4_int64, 2_int64], status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_SHAPE, &
      "reshape invalid shape status")

    transposed = transpose_r64(source, status)
    call assert_status_ok(status, "transpose for status path")
    result = reshape_r64(transposed, [6_int64], status)
    call assert_status_code(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
      "reshape non-contiguous status")

    result = swapaxes_r64(source, 0_int32, 2_int32, status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_AXIS, &
      "swapaxes invalid axis status")

    result = squeeze_r64(source, axis0=0_int32, status=status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_SHAPE, &
      "squeeze non-singleton status")

    result = expand_dims_r64(source, 3_int32, status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_AXIS, &
      "expand dims invalid axis status")

    specs = [slice_range(0_int64, 1_int64, 0_int64, status)]
    call assert_status_code(status, FRUMPY_STATUS_INVALID_SHAPE, &
      "zero step slice spec status")

    source = metadata_descriptor_r64([2_int64], [1_int64], 1_int64, status)
    call assert_status_ok(status, "metadata descriptor status")
    result = ravel_r64(source, status)
    call assert_status_code(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
      "missing storage view status")
  end subroutine test_view_status_paths

  function matrix_source(status) result(source)
    type(frumpy_status), intent(out) :: status
    type(ndarray_r64) :: source

    source = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      status=status)
    call assert_status_ok(status, "matrix source constructor")
  end function matrix_source

  subroutine assert_logical_values(array, expected, message)
    type(ndarray_r64), intent(in) :: array
    real(real64), intent(in) :: expected(:)
    character(len=*), intent(in) :: message
    integer(int64), allocatable :: index0(:)
    integer(int64) :: item1
    integer(int64) :: position

    if (array%size() /= int(size(expected), int64)) then
      write (*, '(a)') "FAIL: " // message
      error stop 1
    end if

    if (array%size() == 0_int64) return

    if (array%rank == 0_int32) then
      call assert_close_scalar(array%data(array%offset), expected(1), message)
      return
    end if

    allocate(index0(array%rank))
    index0 = 0_int64
    do item1 = 1_int64, array%size()
      position = storage_position(array, index0)
      call assert_close_scalar(array%data(position), &
        expected(int(item1)), message)
      call advance_c_order_index(index0, array%shape)
    end do
  end subroutine assert_logical_values

  integer(int64) function storage_position(array, index0) result(position)
    type(ndarray_r64), intent(in) :: array
    integer(int64), intent(in) :: index0(:)
    integer(int32) :: dim1

    position = array%offset
    do dim1 = 1_int32, int(size(index0), int32)
      position = position + index0(dim1) * array%strides(dim1)
    end do
  end function storage_position

  subroutine advance_c_order_index(index0, shape)
    integer(int64), intent(inout) :: index0(:)
    integer(int64), intent(in) :: shape(:)
    integer(int32) :: dim1

    do dim1 = int(size(shape), int32), 1_int32, -1_int32
      index0(dim1) = index0(dim1) + 1_int64
      if (index0(dim1) < shape(dim1)) return
      index0(dim1) = 0_int64
    end do
  end subroutine advance_c_order_index

  subroutine assert_same_storage(source, view, message)
    type(ndarray_r64), intent(in) :: source
    type(ndarray_r64), intent(in) :: view
    character(len=*), intent(in) :: message

    if (.not. associated(view%data, source%data)) then
      write (*, '(a)') "FAIL: " // message
      error stop 1
    end if
  end subroutine assert_same_storage

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
      error stop 1
    end if
  end subroutine assert_equal_int64

  subroutine assert_close_scalar(actual, expected, message)
    real(real64), intent(in) :: actual
    real(real64), intent(in) :: expected
    character(len=*), intent(in) :: message

    if (abs(actual - expected) > TOLERANCE) then
      write (*, '(a)') "FAIL: " // message
      write (*, '(a,1x,es16.8)') "actual:", actual
      write (*, '(a,1x,es16.8)') "expected:", expected
      error stop 1
    end if
  end subroutine assert_close_scalar
end program test_views_r64
