!> Linear algebra preserves inputs and storage lifetime, and guards backend ABI limits.
program test_linalg_r32
  use iso_fortran_env, only: int32, int64, real32
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use frumpy, only: ndarray_r32, owned_descriptor_r32, view_descriptor_r32, &
    matmul_r32, solve_r32, frumpy_status, FRUMPY_STATUS_INVALID_SHAPE, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
    FRUMPY_STATUS_OVERFLOW, FRUMPY_STATUS_SINGULAR_MATRIX, FRUMPY_DTYPE_I32
  use frumpy, only: vector_norm_r32, matrix_norm_r32, FRUMPY_STATUS_INVALID_AXIS
  implicit none

  call exercise_norms()
  call exercise_empty_rhs()
  call exercise()

contains

  subroutine exercise_norms()
    type(ndarray_r32) :: a, vector, matrix, result, invalid
    type(frumpy_status) :: status
    integer(int64) :: big

    a = owned_descriptor_r32([2_int64,2_int64])
    a%data = [1.0_real32,2.0_real32,3.0_real32,4.0_real32]
    invalid = view_descriptor_r32(a, [4_int64], [-1_int64], 4_int64)
    invalid%is_c_contiguous = .true.
    result = vector_norm_r32(invalid, status=status)
    call require(status%is_ok(), 'norm negative linear stride')
    call require(abs(result%data(1)-sqrt(30.0_real32))<1e-6_real32, 'norm reverse value')
    invalid = view_descriptor_r32(a, [1_int64,2_int64,1_int64], &
      [huge(1_int64),1_int64,-huge(1_int64)], 2_int64)
    result = vector_norm_r32(invalid, status=status)
    call require(status%is_ok(), 'norm arbitrary singleton strides')
    call require(abs(result%data(1)-sqrt(13.0_real32))<1e-6_real32, 'norm offset value')
    call invalid%release()
    vector = vector_norm_r32(a, axis0=0_int32, status=status)
    call require(status%is_ok(), 'norm status')
    call require(all(abs(vector%data-sqrt([10.0_real32,20.0_real32]))<1e-6_real32), 'axis norm')
    call require(.not. associated(vector%data,a%data), 'norm independent')
    matrix = matrix_norm_r32(a, axes0=[1_int32,0_int32], keepdims=.true., status=status)
    call require(status%is_ok(), 'matrix norm status')
    call require(all(matrix%shape==[1_int64,1_int64]), 'norm keepdims')
    call a%release()
    call require(abs(matrix%data(1)-sqrt(30.0_real32))<1e-6_real32, 'norm lifetime')
    result = matrix_norm_r32(matrix, axes0=[0_int32,0_int32], status=status)
    call require(status%code==FRUMPY_STATUS_INVALID_AXIS, 'duplicate norm axes')
    call require(.not. result%has_storage(), 'norm failure has no storage')
    result = vector_norm_r32(invalid, status=status)
    call require(status%code==FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'norm absent storage')
    invalid = view_descriptor_r32(vector, [2_int64], [huge(1_int64)], 1_int64)
    result = vector_norm_r32(invalid, status=status)
    call require(status%code==FRUMPY_STATUS_INVALID_SHAPE, 'norm invalid bounds')
    invalid = view_descriptor_r32(vector, [2_int64], [1_int64], 1_int64)
    invalid%dtype_id = FRUMPY_DTYPE_I32
    result = vector_norm_r32(invalid, status=status)
    call require(status%code==FRUMPY_STATUS_UNSUPPORTED_DTYPE, 'norm forged dtype')
    result = vector_norm_r32(invalid)
    call require(.not. result%has_storage(), 'norm optional failure status')
    big = shiftr(huge(1_int64),2)+1_int64
    a = view_descriptor_r32(vector, [big,1_int64], [0_int64,0_int64], 1_int64)
    result = vector_norm_r32(a, axis0=1_int32, status=status)
    call require(status%code==FRUMPY_STATUS_OVERFLOW, 'norm output bytes')
  end subroutine exercise_norms


  subroutine exercise_empty_rhs()
    type(ndarray_r32) :: a, b, result
    type(frumpy_status) :: status

    a = owned_descriptor_r32([2_int64, 2_int64])
    b = owned_descriptor_r32([2_int64, 0_int64])
    a%data = [1.0_real32, 0.0_real32, 0.0_real32, 1.0_real32]
    result = solve_r32(a, b, status)
    call require(status%is_ok(), 'nonsingular empty RHS')
    call require(result%size() == 0_int64, 'empty RHS result remains empty')
    a%data = 0.0_real32
    result = solve_r32(a, b, status)
    call require(status%code == FRUMPY_STATUS_SINGULAR_MATRIX, 'singular empty RHS')
    call require(.not. result%has_storage(), 'singular empty RHS has no result')
  end subroutine exercise_empty_rhs

  subroutine exercise()
    type(ndarray_r32) :: a, b, rhs, result, solution, reversed, invalid, other
    type(frumpy_status) :: status
    integer(int64) :: oversized, byte_limit

    a = owned_descriptor_r32([2_int64, 2_int64])
    a%data = [2.0_real32, 1.0_real32, 1.0_real32, 3.0_real32]
    b = owned_descriptor_r32([2_int64, 2_int64])
    b%data = [1.0_real32, 2.0_real32, 3.0_real32, 4.0_real32]
    rhs = owned_descriptor_r32([2_int64])
    rhs%data = [5.0_real32, 10.0_real32]
    solution = solve_r32(a, rhs, status)
    call require(status%is_ok(), 'solve status')
    call require(all(abs(solution%data - [1.0_real32, 3.0_real32]) < 2e-5_real32), 'solve values')
    call require(all(solution%shape == [2_int64]), 'vector solve shape')
    call require(storage_size(solution%data) == 32, 'float32 solution')
    call require(.not. associated(solution%data, rhs%data), 'independent solution')
    call require(all(abs(rhs%data - [5.0_real32, 10.0_real32]) < 2e-5_real32), 'rhs preserved')
    reversed = view_descriptor_r32(a, [2_int64, 2_int64], [-2_int64, 1_int64], 3_int64)
    result = matmul_r32(reversed, b)
    call require(all(abs(result%data - [10.0_real32, 14.0_real32, &
      5.0_real32, 8.0_real32]) < 2e-5_real32), 'strided matmul without status')
    call require(all(result%shape == [2_int64, 2_int64]), 'matmul shape')
    call require(all(result%strides == [2_int64, 1_int64]), 'matmul C strides')
    call require(result%offset == 1_int64, 'matmul offset')
    call require(result%owns_data .and. result%is_c_contiguous, 'owned matmul')
    call require(solution%owns_data .and. solution%is_c_contiguous, 'owned solve')
    call require(.not. associated(result%data, a%data), 'independent matmul lhs')
    call require(.not. associated(result%data, b%data), 'independent matmul rhs')
    call require(all(abs(a%data - [2.0_real32, 1.0_real32, &
      1.0_real32, 3.0_real32]) < 2e-5_real32), 'coefficient matrix preserved')
    call a%release()
    call reversed%release()
    call b%release()
    call rhs%release()
    call require(abs(solution%data(2) - 3.0_real32) < 2e-5_real32, 'solution survives')
    call require(abs(result%data(4) - 8.0_real32) < 2e-5_real32, 'product survives')

    a = owned_descriptor_r32([2_int64, 2_int64])
    a%data = 0.0_real32
    rhs = owned_descriptor_r32([2_int64])
    rhs%data = 1.0_real32
    solution = solve_r32(a, rhs, status)
    call require(status%code == FRUMPY_STATUS_SINGULAR_MATRIX, 'singular solve status')
    call require(.not. solution%has_storage(), 'singular solve has no result')
    solution = solve_r32(a, rhs)
    call require(.not. solution%has_storage(), 'singular without status')
    result = matmul_r32(invalid, a, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'missing storage')
    invalid = view_descriptor_r32(a, [2_int64], [huge(1_int64)], 1_int64)
    result = matmul_r32(invalid, rhs, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'bad reachable bounds')
    invalid = view_descriptor_r32(a, [2_int64], [1_int64], 1_int64)
    invalid%rank = 2_int32
    solution = solve_r32(a, invalid, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'bad rank')
    invalid%rank = 1_int32
    deallocate(invalid%shape)
    result = matmul_r32(a, invalid, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'missing metadata')
    a%dtype_id = FRUMPY_DTYPE_I32
    solution = solve_r32(a, rhs, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_DTYPE, 'forged dtype')
    a%dtype_id = rhs%dtype_id

    oversized = int(huge(1_int32), int64) + 1_int64
    invalid = view_descriptor_r32(a, [1_int64, oversized], [0_int64, 0_int64], 1_int64)
    other = view_descriptor_r32(a, [oversized, 1_int64], [0_int64, 0_int64], 1_int64)
    result = matmul_r32(invalid, other, status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'matmul LP64 guard')
    call require(.not. result%has_storage(), 'LP64 rejection without allocation')
    oversized = int(huge(1_int32), int64)
    invalid = view_descriptor_r32(a, [oversized, oversized], [0_int64, 0_int64], 1_int64)
    other = view_descriptor_r32(a, [oversized], [0_int64], 1_int64)
    solution = solve_r32(invalid, other, status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'solve workspace byte guard')
    call require(.not. solution%has_storage(), 'workspace rejection without result')
    byte_limit = shiftr(huge(1_int64), 2) + 1_int64
    invalid = view_descriptor_r32(a, [byte_limit, 1_int64, 1_int64], &
      [0_int64, 0_int64, 0_int64], 1_int64)
    other = view_descriptor_r32(a, [1_int64], [0_int64], 1_int64)
    result = matmul_r32(invalid, other, status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'output byte guard')
    call require(.not. result%has_storage(), 'output byte rejection without result')

    a%data = 1.0_real32
    a%data(1) = ieee_value(0.0_real32, ieee_quiet_nan)
    result = matmul_r32(a, rhs, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'nonfinite matmul')
    call require(.not. result%has_storage(), 'nonfinite output released')
    solution = solve_r32(a, rhs, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'nonfinite solve')
    call require(.not. solution%has_storage(), 'nonfinite solve no result')
  end subroutine exercise

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_linalg_r32
