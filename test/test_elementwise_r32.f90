!> Float32 arithmetic must preserve dtype, strides, independent results and status paths.
program test_elementwise_r32
  use iso_fortran_env, only: int32, int64, real32
  use frumpy, only: ndarray_r32, owned_descriptor_r32, view_descriptor_r32, &
    metadata_descriptor_r32, add_r32, subtract_r32, multiply_r32, divide_r32, &
    frumpy_status, FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR
  implicit none

  call exercise()

contains

  subroutine exercise()
    type(ndarray_r32) :: lhs, rhs, result, reversed, invalid
    type(frumpy_status) :: status

    lhs = owned_descriptor_r32([2_int64, 3_int64])
    lhs%data = [1.0_real32, 2.0_real32, 3.0_real32, 4.0_real32, 5.0_real32, 6.0_real32]
    rhs = owned_descriptor_r32([3_int64])
    rhs%data = [10.0_real32, 20.0_real32, 30.0_real32]
    result = add_r32(lhs, rhs, status)
    call require(status%is_ok(), 'broadcast add')
    call require(all(result%shape == [2_int64, 3_int64]), 'broadcast shape')
    call require(result%is_c_contiguous .and. result%owns_data, 'owned C-order result')
    call require(storage_size(result%data) == 32, 'float32 payload')
    call require(.not. associated(result%data, lhs%data), 'independent lhs storage')
    call require(.not. associated(result%data, rhs%data), 'independent rhs storage')
    call require(all(abs(result%data - &
      [11.0_real32, 22.0_real32, 33.0_real32, 14.0_real32, 25.0_real32, 36.0_real32]) &
      < epsilon(1.0_real32)), 'add values')
    result = subtract_r32(lhs, rhs, status)
    call require(status%is_ok(), 'subtract')
    call require(abs(result%data(6) + 24.0_real32) < epsilon(1.0_real32), 'subtract value')
    result = multiply_r32(lhs, rhs, status)
    call require(status%is_ok(), 'multiply')
    call require(abs(result%data(6) - 180.0_real32) < epsilon(1.0_real32), 'multiply value')
    result = divide_r32(lhs, rhs, status)
    call require(status%is_ok(), 'divide')
    call require(abs(result%data(6) - 0.2_real32) < epsilon(1.0_real32), 'divide value')
    reversed = view_descriptor_r32(rhs, [3_int64], [-1_int64], 3_int64)
    result = add_r32(reversed, rhs, status)
    call require(status%is_ok(), 'reverse add')
    call rhs%release()
    call reversed%release()
    call require(all(abs(result%data - 40.0_real32) < epsilon(1.0_real32)), 'result survives')

    result = add_r32(invalid, lhs, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'missing storage')
    invalid = metadata_descriptor_r32([2_int64], [huge(1_int64)], 1_int64)
    invalid%data => lhs%data
    result = add_r32(invalid, lhs, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'overflowing storage bounds')
    call require(.not. result%has_storage(), 'invalid input creates no output')
    invalid = view_descriptor_r32(lhs, [2_int64], [1_int64], 1_int64)
    invalid%rank = 2_int32
    result = add_r32(invalid, lhs, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'rank mismatch')
    invalid%rank = 1_int32
    result = add_r32(invalid, lhs, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'incompatible broadcast')
  end subroutine exercise

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_elementwise_r32
