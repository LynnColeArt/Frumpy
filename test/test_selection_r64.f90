program test_selection_r64
  use iso_fortran_env, only: int8, int32, int64, real64
  use frumpy_constructors_r64, only: asarray_r64, empty_r64
  use frumpy_constants, only: FRUMPY_ORDER_F
  use frumpy_ndarray_bool, only: ndarray_bool, owned_descriptor_bool
  use frumpy_ndarray_i64, only: ndarray_i64
  use frumpy_ndarray_r64, only: ndarray_r64
  use frumpy_selection_r64, only: concatenate_r64, nonzero_bool, stack_r64, &
    take_r64, where_r64
  use frumpy_statuses, only: FRUMPY_STATUS_INVALID_AXIS, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OK, &
    frumpy_status

  implicit none

  call test_concatenate_c_order_inputs()
  call test_concatenate_f_order_inputs()
  call test_concatenate_empty_input_support()
  call test_where_same_shape_inputs()
  call test_where_broadcast_inputs()
  call test_where_empty_and_status_paths()
  call test_nonzero_boolean_mask_subset()
  call test_take_subset_and_status_paths()
  call test_stack_c_order_inputs()
  call test_stack_status_paths()

contains

  subroutine test_concatenate_c_order_inputs()
    type(frumpy_status) :: status
    type(ndarray_r64) :: lhs
    type(ndarray_r64) :: rhs
    type(ndarray_r64) :: result

    lhs = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      status=status)
    call assert_status_ok(status, "concatenate C lhs constructor")

    rhs = asarray_r64([7.0_real64, 8.0_real64, 9.0_real64, &
        10.0_real64, 11.0_real64, 12.0_real64], [2_int64, 3_int64], &
      status=status)
    call assert_status_ok(status, "concatenate C rhs constructor")

    result = concatenate_r64([lhs, rhs], axis0=0_int32, status=status)
    call assert_status_ok(status, "concatenate C axis0 status")
    call assert_equal_int64_vector(result%shape, [4_int64, 3_int64], &
      "concatenate C axis0 shape")
    call assert_true(result%is_c_contiguous, "concatenate C axis0 C flag")
    call assert_false(result%is_f_contiguous, "concatenate C axis0 F flag")
    call assert_close_vector(result%data, &
      [1.0_real64, 2.0_real64, 3.0_real64, 4.0_real64, 5.0_real64, &
        6.0_real64, 7.0_real64, 8.0_real64, 9.0_real64, 10.0_real64, &
        11.0_real64, 12.0_real64], "concatenate C axis0 data")

    result = concatenate_r64([lhs, rhs], axis0=1_int32, status=status)
    call assert_status_ok(status, "concatenate C axis1 status")
    call assert_equal_int64_vector(result%shape, [2_int64, 6_int64], &
      "concatenate C axis1 shape")
    call assert_close_vector(result%data, &
      [1.0_real64, 2.0_real64, 3.0_real64, 7.0_real64, 8.0_real64, &
        9.0_real64, 4.0_real64, 5.0_real64, 6.0_real64, 10.0_real64, &
        11.0_real64, 12.0_real64], "concatenate C axis1 data")
  end subroutine test_concatenate_c_order_inputs

  subroutine test_concatenate_f_order_inputs()
    type(frumpy_status) :: status
    type(ndarray_r64) :: lhs
    type(ndarray_r64) :: rhs
    type(ndarray_r64) :: result

    lhs = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "concatenate F lhs constructor")

    rhs = asarray_r64([7.0_real64, 8.0_real64, 9.0_real64, &
        10.0_real64, 11.0_real64, 12.0_real64], [2_int64, 3_int64], &
      FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "concatenate F rhs constructor")

    result = concatenate_r64([lhs, rhs], axis0=0_int32, status=status)
    call assert_status_ok(status, "concatenate F axis0 status")
    call assert_equal_int64_vector(result%shape, [4_int64, 3_int64], &
      "concatenate F axis0 shape")
    call assert_true(result%is_f_contiguous, "concatenate F axis0 F flag")
    call assert_false(result%is_c_contiguous, "concatenate F axis0 C flag")
    call assert_equal_int64_vector(result%strides, [1_int64, 4_int64], &
      "concatenate F axis0 strides")
    call assert_close_vector(result%data, &
      [1.0_real64, 4.0_real64, 7.0_real64, 10.0_real64, 2.0_real64, &
        5.0_real64, 8.0_real64, 11.0_real64, 3.0_real64, 6.0_real64, &
        9.0_real64, 12.0_real64], "concatenate F axis0 storage")

    result = concatenate_r64([lhs, rhs], axis0=1_int32, status=status)
    call assert_status_ok(status, "concatenate F axis1 status")
    call assert_equal_int64_vector(result%shape, [2_int64, 6_int64], &
      "concatenate F axis1 shape")
    call assert_true(result%is_f_contiguous, "concatenate F axis1 F flag")
    call assert_equal_int64_vector(result%strides, [1_int64, 2_int64], &
      "concatenate F axis1 strides")
    call assert_close_vector(result%data, &
      [1.0_real64, 4.0_real64, 2.0_real64, 5.0_real64, 3.0_real64, &
        6.0_real64, 7.0_real64, 10.0_real64, 8.0_real64, 11.0_real64, &
        9.0_real64, 12.0_real64], "concatenate F axis1 storage")
  end subroutine test_concatenate_f_order_inputs

  subroutine test_concatenate_empty_input_support()
    type(frumpy_status) :: status
    type(ndarray_r64) :: empty_rows
    type(ndarray_r64) :: rows
    type(ndarray_r64) :: result

    empty_rows = empty_r64([0_int64, 3_int64], status=status)
    call assert_status_ok(status, "empty concatenate input constructor")

    rows = asarray_r64([7.0_real64, 8.0_real64, 9.0_real64, &
        10.0_real64, 11.0_real64, 12.0_real64], [2_int64, 3_int64], &
      status=status)
    call assert_status_ok(status, "concatenate empty rhs constructor")

    result = concatenate_r64([empty_rows, rows], status=status)
    call assert_status_ok(status, "concatenate empty status")
    call assert_equal_int64_vector(result%shape, [2_int64, 3_int64], &
      "concatenate empty shape")
    call assert_close_vector(result%data, &
      [7.0_real64, 8.0_real64, 9.0_real64, 10.0_real64, 11.0_real64, &
        12.0_real64], "concatenate empty data")
  end subroutine test_concatenate_empty_input_support

  subroutine test_where_same_shape_inputs()
    type(frumpy_status) :: status
    type(ndarray_r64) :: lhs
    type(ndarray_r64) :: rhs
    type(ndarray_r64) :: result
    type(ndarray_bool) :: condition

    condition = owned_descriptor_bool([2_int64, 3_int64], status=status)
    call assert_status_ok(status, "where condition constructor")
    condition%data = [1_int8, 0_int8, 1_int8, 0_int8, 1_int8, 0_int8]

    lhs = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "where lhs constructor")

    rhs = asarray_r64([11.0_real64, 12.0_real64, 13.0_real64, &
        14.0_real64, 15.0_real64, 16.0_real64], [2_int64, 3_int64], &
      FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "where rhs constructor")

    result = where_r64(condition, lhs, rhs, status)
    call assert_status_ok(status, "where status")
    call assert_equal_int64_vector(result%shape, [2_int64, 3_int64], &
      "where shape")
    call assert_true(result%is_c_contiguous, "where C flag")
    call assert_false(result%is_f_contiguous, "where F flag")
    call assert_close_vector(result%data, &
      [1.0_real64, 12.0_real64, 3.0_real64, 14.0_real64, 5.0_real64, &
        16.0_real64], "where data")
  end subroutine test_where_same_shape_inputs

  subroutine test_where_broadcast_inputs()
    type(frumpy_status) :: status
    type(ndarray_r64) :: lhs
    type(ndarray_r64) :: rhs
    type(ndarray_r64) :: result
    type(ndarray_bool) :: condition

    condition = owned_descriptor_bool([1_int64, 3_int64], status=status)
    call assert_status_ok(status, "where broadcast condition constructor")
    condition%data = [1_int8, 0_int8, 1_int8]

    lhs = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "where broadcast lhs constructor")

    rhs = asarray_r64([11.0_real64, 12.0_real64, 13.0_real64, &
        14.0_real64, 15.0_real64, 16.0_real64], [2_int64, 3_int64], &
      FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "where broadcast rhs constructor")

    result = where_r64(condition, lhs, rhs, status)
    call assert_status_ok(status, "where broadcast status")
    call assert_equal_int64_vector(result%shape, [2_int64, 3_int64], &
      "where broadcast shape")
    call assert_true(result%is_c_contiguous, "where broadcast C flag")
    call assert_close_vector(result%data, &
      [1.0_real64, 12.0_real64, 3.0_real64, 4.0_real64, 15.0_real64, &
        6.0_real64], "where broadcast data")
  end subroutine test_where_broadcast_inputs

  subroutine test_where_empty_and_status_paths()
    type(frumpy_status) :: status
    type(ndarray_bool) :: condition
    type(ndarray_r64) :: lhs
    type(ndarray_r64) :: rhs
    type(ndarray_r64) :: result

    condition = owned_descriptor_bool([0_int64, 3_int64], status=status)
    call assert_status_ok(status, "where empty condition constructor")

    lhs = empty_r64([0_int64, 3_int64], FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "where empty lhs constructor")

    rhs = empty_r64([0_int64, 3_int64], status=status)
    call assert_status_ok(status, "where empty rhs constructor")

    result = where_r64(condition, lhs, rhs, status)
    call assert_status_ok(status, "where empty status")
    call assert_equal_int64_vector(result%shape, [0_int64, 3_int64], &
      "where empty shape")
    call assert_equal_int64(result%size(), 0_int64, "where empty size")

    rhs = empty_r64([0_int64, 2_int64], status=status)
    call assert_status_ok(status, "where mismatch rhs constructor")

    result = where_r64(condition, lhs, rhs, status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_SHAPE, &
      "where mismatch status")
  end subroutine test_where_empty_and_status_paths

  subroutine test_nonzero_boolean_mask_subset()
    type(frumpy_status) :: status
    type(ndarray_bool) :: vector
    type(ndarray_bool) :: matrix
    type(ndarray_bool) :: scalar
    type(ndarray_bool) :: empty_mask
    type(ndarray_i64) :: indices
    integer(int64) :: scalar_shape(0)

    vector = owned_descriptor_bool([4_int64], status=status)
    call assert_status_ok(status, "nonzero vector constructor")
    vector%data = [0_int8, 1_int8, 0_int8, 1_int8]

    indices = nonzero_bool(vector, status=status)
    call assert_status_ok(status, "nonzero vector status")
    call assert_equal_int64_vector(indices%shape, [2_int64], &
      "nonzero vector shape")
    call assert_equal_int64_vector(indices%data, [1_int64, 3_int64], &
      "nonzero vector data")

    matrix = owned_descriptor_bool([2_int64, 3_int64], FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "nonzero matrix constructor")
    matrix%data = [1_int8, 0_int8, 0_int8, 1_int8, 1_int8, 0_int8]

    indices = nonzero_bool(matrix, status=status)
    call assert_status_ok(status, "nonzero matrix status")
    call assert_equal_int64_vector(indices%shape, [3_int64], &
      "nonzero matrix shape")
    call assert_equal_int64_vector(indices%data, [0_int64, 2_int64, 4_int64], &
      "nonzero matrix data")

    scalar = owned_descriptor_bool(scalar_shape, status=status)
    call assert_status_ok(status, "nonzero scalar constructor")
    scalar%data(1) = 1_int8

    indices = nonzero_bool(scalar, status=status)
    call assert_status_ok(status, "nonzero scalar true status")
    call assert_equal_int64_vector(indices%shape, [1_int64], &
      "nonzero scalar true shape")
    call assert_equal_int64_vector(indices%data, [0_int64], &
      "nonzero scalar true data")

    scalar%data(1) = 0_int8
    indices = nonzero_bool(scalar, status=status)
    call assert_status_ok(status, "nonzero scalar false status")
    call assert_equal_int64_vector(indices%shape, [0_int64], &
      "nonzero scalar false shape")
    call assert_equal_int64(indices%size(), 0_int64, &
      "nonzero scalar false size")

    empty_mask = owned_descriptor_bool([0_int64, 3_int64], status=status)
    call assert_status_ok(status, "nonzero empty constructor")

    indices = nonzero_bool(empty_mask, status=status)
    call assert_status_ok(status, "nonzero empty status")
    call assert_equal_int64_vector(indices%shape, [0_int64], &
      "nonzero empty shape")
    call assert_equal_int64(indices%size(), 0_int64, "nonzero empty size")
  end subroutine test_nonzero_boolean_mask_subset

  subroutine test_take_subset_and_status_paths()
    type(frumpy_status) :: status
    type(ndarray_r64) :: source
    type(ndarray_r64) :: result
    integer(int64), allocatable :: indices(:)

    source = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "take source constructor")

    result = take_r64(source, [1_int64, 0_int64, 1_int64], axis0=0_int32, status=status)
    call assert_status_ok(status, "take axis0 status")
    call assert_equal_int64_vector(result%shape, [3_int64, 3_int64], &
      "take axis0 shape")
    call assert_true(result%is_c_contiguous, "take axis0 C flag")
    call assert_close_vector(result%data, &
      [4.0_real64, 5.0_real64, 6.0_real64, 1.0_real64, 2.0_real64, &
        3.0_real64, 4.0_real64, 5.0_real64, 6.0_real64], &
      "take axis0 data")

    result = take_r64(source, [0_int64, -1_int64, 0_int64], axis0=1_int32, &
      status=status)
    call assert_status_ok(status, "take axis1 status")
    call assert_equal_int64_vector(result%shape, [2_int64, 3_int64], &
      "take axis1 shape")
    call assert_close_vector(result%data, &
      [1.0_real64, 3.0_real64, 1.0_real64, 4.0_real64, 6.0_real64, &
        4.0_real64], "take axis1 data")

    allocate(indices(0))
    result = take_r64(source, indices, axis0=1_int32, status=status)
    call assert_status_ok(status, "take empty indices status")
    call assert_equal_int64_vector(result%shape, [2_int64, 0_int64], &
      "take empty indices shape")
    call assert_equal_int64(result%size(), 0_int64, "take empty indices size")

    result = take_r64(source, [3_int64], axis0=1_int32, status=status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_SHAPE, &
      "take invalid index status")

    result = take_r64(source, [0_int64], axis0=2_int32, status=status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_AXIS, &
      "take invalid axis status")
  end subroutine test_take_subset_and_status_paths

  subroutine test_stack_c_order_inputs()
    type(frumpy_status) :: status
    type(ndarray_r64) :: lhs
    type(ndarray_r64) :: rhs
    type(ndarray_r64) :: result

    lhs = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      status=status)
    call assert_status_ok(status, "stack C lhs constructor")

    rhs = asarray_r64([7.0_real64, 8.0_real64, 9.0_real64, &
        10.0_real64, 11.0_real64, 12.0_real64], [2_int64, 3_int64], &
      status=status)
    call assert_status_ok(status, "stack C rhs constructor")

    result = stack_r64([lhs, rhs], axis0=0_int32, status=status)
    call assert_status_ok(status, "stack axis0 status")
    call assert_equal_int64_vector(result%shape, [2_int64, 2_int64, 3_int64], &
      "stack axis0 shape")
    call assert_true(result%is_c_contiguous, "stack axis0 C flag")
    call assert_close_vector(result%data, &
      [1.0_real64, 2.0_real64, 3.0_real64, 4.0_real64, 5.0_real64, &
        6.0_real64, 7.0_real64, 8.0_real64, 9.0_real64, 10.0_real64, &
        11.0_real64, 12.0_real64], "stack axis0 data")

    result = stack_r64([lhs, rhs], axis0=1_int32, status=status)
    call assert_status_ok(status, "stack axis1 status")
    call assert_equal_int64_vector(result%shape, [2_int64, 2_int64, 3_int64], &
      "stack axis1 shape")
    call assert_close_vector(result%data, &
      [1.0_real64, 2.0_real64, 3.0_real64, 7.0_real64, 8.0_real64, &
        9.0_real64, 4.0_real64, 5.0_real64, 6.0_real64, 10.0_real64, &
        11.0_real64, 12.0_real64], "stack axis1 data")
  end subroutine test_stack_c_order_inputs

  subroutine test_stack_status_paths()
    type(frumpy_status) :: status
    type(ndarray_r64) :: lhs
    type(ndarray_r64) :: rhs
    type(ndarray_r64) :: result

    lhs = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "stack F lhs constructor")

    rhs = asarray_r64([7.0_real64, 8.0_real64, 9.0_real64, &
        10.0_real64, 11.0_real64, 12.0_real64], [2_int64, 3_int64], &
      FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "stack F rhs constructor")

    result = stack_r64([lhs, rhs], status=status)
    call assert_status_ok(status, "stack F status")

    result = concatenate_r64([lhs, rhs], axis0=2_int32, status=status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_AXIS, &
      "concatenate invalid axis status")
  end subroutine test_stack_status_paths

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

    if (any(abs(actual - expected) > 1.0e-12_real64)) then
      write (*, '(a)') "FAIL: " // message
      write (*, '(a,*(1x,es16.8))') "actual:", actual
      write (*, '(a,*(1x,es16.8))') "expected:", expected
      error stop 1
    end if
  end subroutine assert_close_vector

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
end program test_selection_r64
