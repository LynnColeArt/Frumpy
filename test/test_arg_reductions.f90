program test_arg_reductions
  use iso_fortran_env, only: int32, int64, real32
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use frumpy, only: ndarray_r32, ndarray_i64, owned_descriptor_r32, owned_descriptor_i64, &
    view_descriptor_r32, argmin, argmax, frumpy_status, FRUMPY_STATUS_INVALID_AXIS, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OVERFLOW
  implicit none
  call exercise()
contains
  subroutine exercise()
    type(ndarray_r32) :: source, view, invalid
    type(ndarray_i64) :: wide, result
    type(frumpy_status) :: status

    wide = owned_descriptor_i64([3_int64])
    wide%data = [huge(1_int64), huge(1_int64)-1_int64, huge(1_int64)-1_int64]
    result = argmin(wide, status=status)
    call require(status%is_ok() .and. result%data(1)==1_int64, 'exact integer first tie')
    source = owned_descriptor_r32([2_int64, 3_int64])
    source%data = [3.0_real32, 1.0_real32, 1.0_real32, 2.0_real32, 0.0_real32, 4.0_real32]
    result = argmin(source, axis0=-1_int32, keepdims=.true., status=status)
    call require(status%is_ok(), 'negative axis')
    call require(all(result%shape==[2_int64,1_int64]), 'keepdims')
    call require(all(result%data==[1_int64,1_int64]), 'axis positions')
    call require(result%owns_data .and. result%is_c_contiguous, 'owned C-order result')
    view = view_descriptor_r32(source, [6_int64], [-1_int64], 6_int64)
    result = argmax(view, status=status)
    call require(status%is_ok() .and. result%data(1)==0_int64, 'reverse logical index')
    source%data(2:3) = ieee_value(0.0_real32,ieee_quiet_nan)
    result = argmin(source, status=status)
    call require(status%is_ok() .and. result%data(1)==1_int64, 'first NaN minimum')
    result = argmax(source, status=status)
    call require(status%is_ok() .and. result%data(1)==1_int64, 'first NaN maximum')
    call source%release()
    call view%release()
    call require(result%data(1)==1_int64, 'independent lifetime')
    result = argmin(invalid, status=status)
    call require(status%is_failure() .and. .not. result%has_storage(), 'missing storage')
    source = owned_descriptor_r32([0_int64,0_int64])
    result = argmin(source, axis0=0_int32, status=status)
    call require(status%code==FRUMPY_STATUS_INVALID_SHAPE, 'empty reduction with empty output')
    result = argmax(source)
    call require(.not. result%has_storage(), 'optional status failure')
    result = argmax(source, axis0=-3_int32, status=status)
    call require(status%code==FRUMPY_STATUS_INVALID_AXIS, 'negative axis validated once')
    source = owned_descriptor_r32([0_int64,3_int64])
    result = argmax(source, axis0=1_int32, status=status)
    call require(status%is_ok() .and. result%size()==0_int64, 'valid empty batch')
    source = owned_descriptor_r32([1_int64])
    source%data = 1.0_real32
    invalid = view_descriptor_r32(source, [2_int64], [huge(1_int64)], 1_int64)
    result = argmin(invalid, status=status)
    call require(status%code==FRUMPY_STATUS_INVALID_SHAPE, 'bad reachable bounds')
    invalid = view_descriptor_r32(source, [shiftr(huge(1_int64),3)+1_int64,1_int64], &
      [0_int64,0_int64], 1_int64)
    result = argmin(invalid, axis0=1_int32, status=status)
    call require(status%code==FRUMPY_STATUS_OVERFLOW, 'result byte overflow')
    call require(.not. result%has_storage(), 'overflow has no output')
  end subroutine exercise
  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_arg_reductions
