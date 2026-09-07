!> Public descriptors may be malformed; selection must fail without dereferencing them.
program test_selection_validation
  use iso_fortran_env, only: int8, int32, int64
  use frumpy, only: ndarray_r64, ndarray_bool, ndarray_i64, frumpy_status, &
    zeros_r64, owned_descriptor_bool, where_r64, take_r64, stack_r64, &
    concatenate_r64, sort_r64, argsort_r64, searchsorted_r64, nonzero_bool, &
    FRUMPY_STATUS_INVALID_SHAPE
  implicit none

  type(ndarray_r64) :: source, malformed, output
  type(ndarray_i64) :: indices
  type(ndarray_bool) :: condition, malformed_condition
  type(frumpy_status) :: status
  integer(int32) :: case_id

  source = zeros_r64([2_int64], status=status)
  if (status%is_failure()) error stop 'source setup failed'
  condition = owned_descriptor_bool([2_int64], status=status)
  if (status%is_failure()) error stop 'condition setup failed'
  condition%data = 1_int8

  do case_id = 1_int32, 8_int32
    malformed = source
    malformed_condition = condition
    select case (case_id)
    case (1)
      malformed%offset = 3_int64
      malformed_condition%offset = 3_int64
    case (2)
      malformed%strides = -1_int64
      malformed_condition%strides = -1_int64
    case (3)
      malformed%shape = 3_int64
      malformed%strides = huge(1_int64)
      malformed_condition%shape = 3_int64
      malformed_condition%strides = huge(1_int64)
    case (4)
      malformed%shape = -1_int64
      malformed_condition%shape = -1_int64
    case (5)
      deallocate(malformed%shape)
      deallocate(malformed_condition%shape)
    case (6)
      malformed%rank = 2_int32
      malformed_condition%rank = 2_int32
    case (7)
      malformed%strides = -huge(1_int64) - 1_int64
      malformed_condition%strides = -huge(1_int64) - 1_int64
    case (8)
      malformed%shape = [huge(1_int64), 2_int64]
      malformed%strides = [0_int64, 0_int64]
      malformed%rank = 2_int32
      malformed_condition%shape = malformed%shape
      malformed_condition%strides = malformed%strides
      malformed_condition%rank = 2_int32
    end select

    output = where_r64(condition, malformed, source, status)
    call expect_invalid('where lhs')
    output = where_r64(condition, source, malformed, status)
    call expect_invalid('where rhs')
    output = where_r64(malformed_condition, source, source, status)
    call expect_invalid('where condition')
    output = take_r64(malformed, [0_int64], status=status)
    call expect_invalid('take')
    output = concatenate_r64([malformed, source], status=status)
    call expect_invalid('concatenate first')
    output = concatenate_r64([source, malformed], status=status)
    call expect_invalid('concatenate second')
    output = stack_r64([malformed, source], status=status)
    call expect_invalid('stack first')
    output = stack_r64([source, malformed], status=status)
    call expect_invalid('stack second')
    output = sort_r64(malformed, status=status)
    call expect_invalid('sort')
    indices = argsort_r64(malformed, status=status)
    call expect_invalid('argsort')
    indices = searchsorted_r64(malformed, source, status=status)
    call expect_invalid('search source')
    indices = searchsorted_r64(source, malformed, status=status)
    call expect_invalid('search values')
    indices = nonzero_bool(malformed_condition, status=status)
    call expect_invalid('nonzero')
  end do

contains

  subroutine expect_invalid(operation)
    character(len=*), intent(in) :: operation

    if (status%code /= FRUMPY_STATUS_INVALID_SHAPE) then
      write (*, '(a,1x,i0,1x,a,1x,i0)') operation, case_id, 'status', status%code
      error stop 'malformed descriptor was not rejected'
    end if
  end subroutine expect_invalid
end program test_selection_validation
