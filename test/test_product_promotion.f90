program test_product_promotion
  use iso_fortran_env, only: int32, int64, real32, real64
  use frumpy, only: ndarray_i32, ndarray_r32, ndarray_r64, owned_descriptor_i32, &
    owned_descriptor_r32, owned_descriptor_r64, view_descriptor_r32, &
    dot, outer, matmul, frumpy_status, FRUMPY_STATUS_UNSUPPORTED_DTYPE
  implicit none
  type(ndarray_i32) :: integers
  type(ndarray_r32) :: single, reversed, wrong
  type(ndarray_r64) :: result
  type(frumpy_status) :: status

  integers = owned_descriptor_i32([2_int64])
  integers%data = [1073741824_int32, 1073741824_int32]
  single = owned_descriptor_r32([2_int64])
  single%data = [4.0_real32, 8.0_real32]
  reversed = view_descriptor_r32(single, [2_int64], [-1_int64], 2_int64)
  result = owned_descriptor_r64([1_int64])
  result%data = -7.0_real64
  call dot(integers, reversed, result, status)
  call require(status%is_ok(), 'mixed dot')
  call require(result%rank == 0, 'dot scalar shape')
  call require(abs(result%data(1)-12884901888.0_real64)<1e-9_real64, 'cast before compute')
  call outer(integers, reversed, result, status)
  call require(status%is_ok(), 'mixed outer')
  call require(all(result%shape == [2_int64,2_int64]), 'outer shape')
  wrong = owned_descriptor_r32([1_int64])
  wrong%data = -3.0_real32
  call dot(integers, reversed, wrong, status)
  call require(status%code == FRUMPY_STATUS_UNSUPPORTED_DTYPE, 'wrong destination')
  call require(abs(wrong%data(1)+3.0_real32)<1e-6_real32, 'failure preserves output')
  call dot(integers, integers, result, status)
  call require(status%code == FRUMPY_STATUS_UNSUPPORTED_DTYPE, 'integral unsupported')
  call require(result%rank == 2, 'unsupported preserves previous result')
  reversed%dtype_id = 3_int32
  call dot(integers, reversed, result, status)
  call require(status%code == FRUMPY_STATUS_UNSUPPORTED_DTYPE, 'forged dtype rejected')
  reversed%dtype_id = 4_int32
  reversed%offset = 99_int64
  call matmul(integers, reversed, result, status)
  call require(status%is_failure(), 'invalid bounds rejected')
  call require(result%rank == 2, 'invalid source preserves result')
  reversed%offset = 2_int64
  call matmul(integers, reversed, result, status)
  call require(status%is_ok(), 'mixed matmul')
  call integers%release()
  call reversed%release()
  call single%release()
  call require(abs(result%data(1)-12884901888.0_real64)<1e-9_real64, 'result survives inputs')

contains
  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_product_promotion
