!> Ownership, axis and malformed-storage invariants for float32 reductions.
program test_reductions_r32
  use iso_fortran_env, only: int32, int64, real32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
  use frumpy, only: ndarray_r32, owned_descriptor_r32, view_descriptor_r32, &
    sum_r32, prod_r32, mean_r32, min_r32, max_r32, frumpy_status, &
    FRUMPY_STATUS_INVALID_AXIS, FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    FRUMPY_STATUS_OVERFLOW
  implicit none

  call exercise()

contains

  subroutine exercise()
    type(ndarray_r32) :: source, result, view, invalid
    type(frumpy_status) :: status

    source = owned_descriptor_r32([2_int64, 3_int64])
    source%data = [1.0_real32, 2.0_real32, 3.0_real32, 4.0_real32, 5.0_real32, 6.0_real32]
    result = sum_r32(source, axis0=-1_int32, keepdims=.true., status=status)
    call require(status%is_ok(), 'negative axis')
    call require(all(result%shape == [2_int64, 1_int64]), 'keepdims shape')
    call require(all(abs(result%data - [6.0_real32, 15.0_real32]) < epsilon(1.0_real32)), 'sum')
    call require(storage_size(result%data) == 32, 'float32 output')
    call require(result%owns_data .and. result%is_c_contiguous, 'owned C-order result')
    call require(.not. associated(result%data, source%data), 'independent result storage')
    result = prod_r32(source, status=status)
    call require(status%is_ok() .and. result%rank == 0, 'all axes scalar product')
    call require(abs(result%data(1) - 720.0_real32) < epsilon(1.0_real32), 'product')
    result = mean_r32(source, status=status)
    call require(status%is_ok(), 'mean')
    call require(abs(result%data(1) - 3.5_real32) < epsilon(1.0_real32), 'mean value')
    view = view_descriptor_r32(source, [6_int64], [-1_int64], 6_int64)
    result = min_r32(view, status=status)
    call require(status%is_ok(), 'reversed minimum')
    call require(abs(result%data(1) - 1.0_real32) < epsilon(1.0_real32), 'minimum')
    result = max_r32(view, status=status)
    call require(status%is_ok(), 'reversed maximum')
    call source%release()
    call view%release()
    call require(abs(result%data(1) - 6.0_real32) < epsilon(1.0_real32), 'result survives source')

    source = owned_descriptor_r32([0_int64, 0_int64])
    result = min_r32(source, axis0=0_int32, status=status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'empty axis minimum fails')
    call require(.not. result%has_storage(), 'failure creates no output')
    result = mean_r32(source, status=status)
    call require(status%is_ok() .and. ieee_is_nan(result%data(1)), 'empty mean')
    result = sum_r32(source, axis0=-3_int32, status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_AXIS, 'out of range negative axis')

    result = sum_r32(invalid, status=status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'missing storage')
    source = owned_descriptor_r32([2_int64])
    source%data = 1.0_real32
    invalid = view_descriptor_r32(source, [2_int64], [huge(1_int64)], 1_int64)
    result = sum_r32(invalid, status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'overflowing reachable bounds')
    invalid%strides = 1_int64
    invalid%shape = -1_int64
    result = mean_r32(invalid, status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'negative extent')
    invalid%shape = 2_int64
    invalid%rank = 2_int32
    result = prod_r32(invalid, status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'rank mismatch')
    invalid%rank = 1_int32
    deallocate(invalid%strides)
    result = max_r32(invalid, status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'missing strides')
    source = owned_descriptor_r32([0_int64])
    invalid = view_descriptor_r32(source, [huge(1_int64), 2_int64, 0_int64], &
      [0_int64, 0_int64, 0_int64], 1_int64)
    result = sum_r32(invalid, axis0=2_int32, status=status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'output element count overflow')
    call require(.not. result%has_storage(), 'overflow creates no output')
  end subroutine exercise

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_reductions_r32
