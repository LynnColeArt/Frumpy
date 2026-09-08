!> Integer kernels preserve storage, metadata and recoverable failure invariants.
program test_elementwise_integer
  use iso_fortran_env, only: int32, int64, real64
  use frumpy, only: frumpy_status, FRUMPY_STATUS_INVALID_SHAPE, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, ndarray_r64
  use frumpy, only: ndarray_i32, owned_descriptor_i32, metadata_descriptor_i32, &
    view_descriptor_i32, add_i32, subtract_i32, multiply_i32, divide_i32
  use frumpy, only: ndarray_i64, owned_descriptor_i64, metadata_descriptor_i64, &
    view_descriptor_i64, add_i64, subtract_i64, multiply_i64, divide_i64
  implicit none

  call exercise_i32()
  call exercise_i64()

contains

  subroutine exercise_i32()
    type(ndarray_i32) :: source, rhs, reversed, result, invalid
    type(ndarray_r64) :: quotient
    type(frumpy_status) :: status

    source = owned_descriptor_i32([6_int64])
    source%data = [1_int32, 2_int32, 3_int32, 4_int32, 5_int32, 6_int32]
    rhs = owned_descriptor_i32([3_int64])
    rhs%data = [10_int32, 20_int32, 30_int32]
    reversed = view_descriptor_i32(source, [2_int64, 3_int64], [-3_int64, -1_int64], 6_int64)
    result = add_i32(reversed, rhs, status)
    call require(status%is_ok(), 'integer reverse broadcast')
    call require(all(result%shape == [2_int64, 3_int64]), 'integer broadcast shape')
    call require(all(result%strides == [3_int64, 1_int64]), 'integer C strides')
    call require(result%offset == 1_int64, 'integer result offset')
    call require(result%owns_data .and. result%is_c_contiguous, 'integer owned result')
    call require(storage_size(result%data) == 32, 'integer payload width')
    call require(.not. associated(result%data, source%data), 'independent lhs')
    call require(.not. associated(result%data, rhs%data), 'independent rhs')
    call require(all(source%data == [1_int32, 2_int32, 3_int32, &
      4_int32, 5_int32, 6_int32]), 'source unchanged')
    quotient = divide_i32(reversed, rhs, status)
    call require(status%is_ok(), 'integer true division')
    call require(storage_size(quotient%data) == 64, 'division float64 payload')
    call require(quotient%owns_data .and. quotient%is_c_contiguous, 'owned division result')
    call require(all(quotient%shape == [2_int64, 3_int64]), 'division broadcast shape')
    call source%release()
    call reversed%release()
    call require(all(result%data == [16_int32, 25_int32, 34_int32, &
      13_int32, 22_int32, 31_int32]), 'integer result survives source release')
    call require(abs(quotient%data(1) - 0.6_real64) < epsilon(1.0_real64), 'division survives')
    source = subtract_i32(result, rhs)
    call require(all(source%data == [6_int32, 5_int32, 4_int32, &
      3_int32, 2_int32, 1_int32]), 'integer optional status')

    result = multiply_i32(invalid, rhs, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'integer missing storage')
    call require(.not. result%has_storage(), 'integer failed result')
    quotient = divide_i32(rhs, invalid, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'division missing rhs')
    call require(.not. quotient%has_storage(), 'division failed result')
    invalid = metadata_descriptor_i32([2_int64], [huge(1_int64)], 1_int64)
    invalid%data => source%data
    result = add_i32(invalid, rhs, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'integer bounds overflow')
    invalid = view_descriptor_i32(source, [2_int64], [-1_int64], 1_int64)
    quotient = divide_i32(invalid, rhs, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'division negative bounds')
    invalid = view_descriptor_i32(source, [2_int64], [1_int64], 1_int64)
    invalid%rank = 2_int32
    result = subtract_i32(rhs, invalid, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'integer rank mismatch')
    invalid%rank = 1_int32
    deallocate(invalid%shape)
    result = multiply_i32(invalid, rhs, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'integer missing shape')
    quotient = divide_i32(invalid, rhs)
    call require(.not. quotient%has_storage(), 'invalid division without status')
  end subroutine exercise_i32

  subroutine exercise_i64()
    type(ndarray_i64) :: source, rhs, reversed, result, invalid
    type(ndarray_r64) :: quotient
    type(frumpy_status) :: status

    source = owned_descriptor_i64([6_int64])
    source%data = [1_int64, 2_int64, 3_int64, 4_int64, 5_int64, 6_int64]
    rhs = owned_descriptor_i64([3_int64])
    rhs%data = [10_int64, 20_int64, 30_int64]
    reversed = view_descriptor_i64(source, [2_int64, 3_int64], [-3_int64, -1_int64], 6_int64)
    result = add_i64(reversed, rhs, status)
    call require(status%is_ok(), 'integer reverse broadcast')
    call require(all(result%shape == [2_int64, 3_int64]), 'integer broadcast shape')
    call require(all(result%strides == [3_int64, 1_int64]), 'integer C strides')
    call require(result%offset == 1_int64, 'integer result offset')
    call require(result%owns_data .and. result%is_c_contiguous, 'integer owned result')
    call require(storage_size(result%data) == 64, 'integer payload width')
    call require(.not. associated(result%data, source%data), 'independent lhs')
    call require(.not. associated(result%data, rhs%data), 'independent rhs')
    call require(all(source%data == [1_int64, 2_int64, 3_int64, &
      4_int64, 5_int64, 6_int64]), 'source unchanged')
    quotient = divide_i64(reversed, rhs, status)
    call require(status%is_ok(), 'integer true division')
    call require(storage_size(quotient%data) == 64, 'division float64 payload')
    call require(quotient%owns_data .and. quotient%is_c_contiguous, 'owned division result')
    call require(all(quotient%shape == [2_int64, 3_int64]), 'division broadcast shape')
    call source%release()
    call reversed%release()
    call require(all(result%data == [16_int64, 25_int64, 34_int64, &
      13_int64, 22_int64, 31_int64]), 'integer result survives source release')
    call require(abs(quotient%data(1) - 0.6_real64) < epsilon(1.0_real64), 'division survives')
    source = subtract_i64(result, rhs)
    call require(all(source%data == [6_int64, 5_int64, 4_int64, &
      3_int64, 2_int64, 1_int64]), 'integer optional status')

    result = multiply_i64(invalid, rhs, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'integer missing storage')
    call require(.not. result%has_storage(), 'integer failed result')
    quotient = divide_i64(rhs, invalid, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'division missing rhs')
    call require(.not. quotient%has_storage(), 'division failed result')
    invalid = metadata_descriptor_i64([2_int64], [huge(1_int64)], 1_int64)
    invalid%data => source%data
    result = add_i64(invalid, rhs, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'integer bounds overflow')
    invalid = view_descriptor_i64(source, [2_int64], [-1_int64], 1_int64)
    quotient = divide_i64(invalid, rhs, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'division negative bounds')
    invalid = view_descriptor_i64(source, [2_int64], [1_int64], 1_int64)
    invalid%rank = 2_int32
    result = subtract_i64(rhs, invalid, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'integer rank mismatch')
    invalid%rank = 1_int32
    deallocate(invalid%shape)
    result = multiply_i64(invalid, rhs, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'integer missing shape')
    quotient = divide_i64(invalid, rhs)
    call require(.not. quotient%has_storage(), 'invalid division without status')
  end subroutine exercise_i64

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_elementwise_integer
