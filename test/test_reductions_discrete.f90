program test_reductions_discrete
  use iso_fortran_env, only: int8, int32, int64, real64
  use frumpy, only: ndarray_i32, ndarray_i64, ndarray_r64, ndarray_bool, &
    owned_descriptor_i32, owned_descriptor_i64, owned_descriptor_bool, &
    view_descriptor_i32, view_descriptor_i64, sum_i32, sum_i64, prod_i64, min_i32, mean_i32, &
    all_bool, any_bool, frumpy_status, FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OVERFLOW
  implicit none
  call exercise()
contains
  subroutine exercise()
    type(ndarray_i32) :: source, invalid, smallest
    type(ndarray_i64) :: wide, result, reversed
    type(ndarray_r64) :: average
    type(ndarray_bool) :: bits, truth
    type(frumpy_status) :: status

    source = owned_descriptor_i32([2_int64])
    source%data = [huge(1_int32), 1_int32]
    result = sum_i32(source, status=status)
    call require(status%is_ok(), 'sum i32 status')
    call require(result%data(1) == int(huge(1_int32),int64)+1_int64, 'i32 sum widens')
    smallest = min_i32(source, status=status)
    call require(status%is_ok() .and. smallest%data(1) == 1_int32, 'i32 min retains dtype')
    average = mean_i32(source, status=status)
    call require(status%is_ok(), 'integer mean status')
    call require(abs(average%data(1)-1073741824.0_real64) < 1e-12_real64, 'integer mean value')
    call source%release()
    call require(result%data(1) > 0_int64, 'reduction survives source')
    wide = owned_descriptor_i64([2_int64])
    wide%data = [huge(1_int64), 1_int64]
    result = sum_i64(wide, status=status)
    call require(status%is_ok(), 'int64 modular sum status')
    call require(result%data(1) == -huge(1_int64)-1_int64, 'int64 sum wraps')
    wide%data = [huge(1_int64), 2_int64]
    reversed = view_descriptor_i64(wide, [2_int64], [-1_int64], 2_int64)
    result = prod_i64(reversed, status=status)
    call require(status%is_ok() .and. result%data(1) == -2_int64, 'strided product wraps')
    bits = owned_descriptor_bool([2_int64])
    bits%data = [-2_int8, 1_int8]
    truth = all_bool(bits, status=status)
    call require(status%is_ok() .and. truth%data(1) == 1_int8, 'all normalizes truth')
    bits = owned_descriptor_bool([0_int64])
    truth = all_bool(bits, status=status)
    call require(status%is_ok() .and. truth%data(1) == 1_int8, 'empty all identity')
    truth = any_bool(bits, status=status)
    call require(status%is_ok() .and. truth%data(1) == 0_int8, 'empty any identity')
    source = owned_descriptor_i32([1_int64])
    invalid = view_descriptor_i32(source, [2_int64], [1_int64], 1_int64)
    result = sum_i32(invalid, status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'bad source bounds')
    call require(.not. result%has_storage(), 'bad reduction no output')
    invalid = view_descriptor_i32(source, [shiftr(huge(1_int64),3)+1_int64, 0_int64], &
      [0_int64,0_int64], 1_int64)
    result = sum_i32(invalid, axis0=1_int32, status=status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'reduction bytes overflow')
  end subroutine exercise

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_reductions_discrete
