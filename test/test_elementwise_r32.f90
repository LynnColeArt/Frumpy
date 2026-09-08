!> Float32 arithmetic must preserve dtype, strides, independent results and status paths.
program test_elementwise_r32
  use iso_fortran_env, only: int32, int64, real32
  use frumpy, only: ndarray_r32, owned_descriptor_r32, view_descriptor_r32, &
    metadata_descriptor_r32, add_r32, subtract_r32, multiply_r32, divide_r32, &
    negate_r32, sqrt_r32, &
    frumpy_status, FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR
  implicit none

  call exercise()
  call exercise_unary()

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

  subroutine exercise_unary()
    type(ndarray_r32) :: source, reversed, result, invalid
    type(frumpy_status) :: status

    source = owned_descriptor_r32([6_int64])
    source%data = [1.0_real32, 4.0_real32, 9.0_real32, &
      16.0_real32, 25.0_real32, 36.0_real32]
    reversed = view_descriptor_r32(source, [2_int64, 3_int64], [-3_int64, -1_int64], 6_int64)
    result = sqrt_r32(reversed, status)
    call require(status%is_ok(), 'unary reverse view')
    call require(all(result%shape == [2_int64, 3_int64]), 'unary shape')
    call require(all(result%strides == [3_int64, 1_int64]), 'unary C strides')
    call require(result%offset == 1_int64, 'unary result offset')
    call require(result%owns_data .and. result%is_c_contiguous, 'unary owned C-order result')
    call require(storage_size(result%data) == 32, 'unary float32 payload')
    call require(.not. associated(result%data, source%data), 'unary independent result')
    call source%release()
    call reversed%release()
    call require(all(abs(result%data - [6.0_real32, 5.0_real32, 4.0_real32, &
      3.0_real32, 2.0_real32, 1.0_real32]) < epsilon(1.0_real32)), 'unary result survives')
    source = negate_r32(result)
    call require(all(abs(source%data + result%data) < epsilon(1.0_real32)), 'optional status')

    result = negate_r32(invalid, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'unary missing storage')
    call require(.not. result%has_storage(), 'failed unary has no result')
    invalid = metadata_descriptor_r32([2_int64], [huge(1_int64)], 1_int64)
    invalid%data => source%data
    result = sqrt_r32(invalid, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'unary overflowing bounds')
    invalid = view_descriptor_r32(source, [2_int64], [-1_int64], 1_int64)
    result = negate_r32(invalid, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'unary negative out-of-bounds')
    invalid = view_descriptor_r32(source, [2_int64], [1_int64], 1_int64)
    invalid%rank = 2_int32
    result = sqrt_r32(invalid, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'unary rank mismatch')
    invalid%rank = 1_int32
    deallocate(invalid%strides)
    result = negate_r32(invalid, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'unary missing strides')
    result = negate_r32(invalid)
    call require(.not. result%has_storage(), 'invalid unary without status has no result')
  end subroutine exercise_unary

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_elementwise_r32
