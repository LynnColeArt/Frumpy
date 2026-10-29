!> Mixed arithmetic preserves typed results, input views, and failure atomicity.
program test_arithmetic
  use iso_fortran_env, only: int8, int32, int64, real32, real64
  use frumpy, only: ndarray_bool, ndarray_i32, ndarray_i64, ndarray_r32, ndarray_r64, &
    owned_descriptor_bool, owned_descriptor_i32, owned_descriptor_i64, owned_descriptor_r32, &
    owned_descriptor_r64, view_descriptor_i64, frumpy_status, add, subtract, multiply, divide, &
    binary_result_dtype, FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_I32, FRUMPY_DTYPE_I64, &
    FRUMPY_DTYPE_R32, FRUMPY_DTYPE_R64, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, FRUMPY_STATUS_INVALID_SHAPE
  implicit none

  call exercise()

contains

  subroutine exercise()
    type(ndarray_bool) :: flags, logical_result
    type(ndarray_i32) :: small, narrow_result
    type(ndarray_i64) :: large, reversed, wide_result, invalid
    type(ndarray_r32) :: single, single_result
    type(ndarray_r64) :: double_result, snapshot
    type(frumpy_status) :: status
    integer(int32) :: dtype_id, iteration
    integer(int64) :: sentinel

    flags = owned_descriptor_bool([3_int64])
    flags%data = [0_int8, 1_int8, 2_int8]
    small = owned_descriptor_i32([integer(int64) ::])
    small%data = 1_int32
    large = owned_descriptor_i64([3_int64])
    large%data = [1_int64, 9007199254740993_int64, huge(1_int64)]
    reversed = view_descriptor_i64(large, [3_int64], [-1_int64], 3_int64)
    call add(small, reversed, wide_result, status)
    call require(status%is_ok(), 'mixed integer addition')
    call require(all(wide_result%data == [-huge(1_int64) - 1_int64, &
      9007199254740994_int64, 2_int64]), 'exact int64 promotion and wrapping')
    call require(wide_result%owns_data .and. wide_result%is_c_contiguous, 'owned C-order result')
    call require(all(wide_result%strides == [1_int64]), 'independent C strides')
    call require(wide_result%offset == 1_int64, 'independent offset')
    call require(.not. associated(wide_result%data, large%data), 'independent input storage')
    call require(large%data(2) == 9007199254740993_int64, 'source unchanged')
    call large%release()
    call reversed%release()
    call require(wide_result%data(3) == 2_int64, 'result survives input release')

    call add(flags, small, narrow_result, status)
    call require(status%is_ok(), 'boolean int32 promotion')
    call require(all(narrow_result%data == [1_int32, 2_int32, 2_int32]), 'boolean normalization')
    call multiply(flags, flags, logical_result, status)
    call require(status%is_ok(), 'boolean multiplication')
    call require(all(logical_result%data == [0_int8, 1_int8, 1_int8]), 'boolean result bytes')
    call subtract(flags, flags, logical_result, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'boolean subtraction rejected')
    call require(all(logical_result%data == [0_int8, 1_int8, 1_int8]), 'boolean failure preserves')

    single = owned_descriptor_r32([3_int64])
    single%data = [0.5_real32, 2.0_real32, 4.0_real32]
    call multiply(single, flags, single_result)
    call require(all(abs(single_result%data - [0.0_real32, 2.0_real32, 4.0_real32]) &
      < epsilon(1.0_real32)), 'float32 and bool stay float32 without status')
    call divide(single, small, double_result, status)
    call require(status%is_ok(), 'int32 and float32 promote to float64')
    call require(storage_size(double_result%data) == 64, 'promoted real width')
    call require(all(abs(double_result%data - [0.5_real64, 2.0_real64, 4.0_real64]) &
      < epsilon(1.0_real64)), 'promoted divide values')
    snapshot = double_result
    call add(single, small, double_result, status)
    call require(status%is_ok(), 'replace an existing result')
    call require(.not. associated(snapshot%data, double_result%data), 'replacement detaches alias')
    call require(abs(snapshot%data(1) - 0.5_real64) < epsilon(1.0_real64), 'old alias survives')
    do iteration = 1_int32, 100_int32
      call subtract(single, small, double_result, status)
      call require(status%is_ok(), 'repeated transactional replacement')
    end do

    sentinel = wide_result%data(2)
    call add(single, small, wide_result, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_DTYPE, 'wrong output dtype rejected')
    call require(wide_result%data(2) == sentinel, 'wrong type preserves output')
    call add(42_int32, small, wide_result, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_DTYPE, 'raw scalar rejected')
    call add(small, invalid, wide_result, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'missing storage rejected')
    call require(wide_result%data(2) == sentinel, 'missing storage preserves output')
    invalid = view_descriptor_i64(wide_result, [2_int64], [huge(1_int64)], 1_int64)
    call multiply(small, invalid, wide_result, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'overflowing reach rejected')
    call require(wide_result%data(2) == sentinel, 'bad bounds preserve output')
    invalid = view_descriptor_i64(wide_result, [2_int64], [1_int64], 1_int64)
    invalid%rank = 2_int32
    call add(small, invalid, wide_result, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'bad rank rejected')
    invalid%rank = 1_int32
    deallocate(invalid%strides)
    call add(small, invalid, wide_result, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'missing strides rejected')
    call add(small, invalid, wide_result)
    call require(wide_result%data(2) == sentinel, 'failure without status preserves output')
    small%dtype_id = FRUMPY_DTYPE_R32
    call add(small, flags, narrow_result, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_DTYPE, 'forged dtype rejected')
    small%dtype_id = FRUMPY_DTYPE_I32
    call divide(small, small,  iteration, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_DTYPE, 'raw output rejected')

    dtype_id = binary_result_dtype(FRUMPY_DTYPE_I32, FRUMPY_DTYPE_R32, 'add', status)
    call require(status%is_ok() .and. dtype_id == FRUMPY_DTYPE_R64, 'result dtype query')
    dtype_id = binary_result_dtype(FRUMPY_DTYPE_I64, FRUMPY_DTYPE_BOOL, 'divide', status)
    call require(status%is_ok() .and. dtype_id == FRUMPY_DTYPE_R64, 'division dtype override')
    dtype_id = binary_result_dtype(FRUMPY_DTYPE_I32, FRUMPY_DTYPE_I32, 'unknown', status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'unknown operation rejected')
    dtype_id = binary_result_dtype(-99_int32, FRUMPY_DTYPE_I32, 'add', status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_DTYPE, 'unknown dtype rejected')
  end subroutine exercise

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_arithmetic
