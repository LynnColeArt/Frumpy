!> Linear algebra preserves inputs and storage lifetime, and guards backend ABI limits.
program test_linalg_r64
  use iso_fortran_env, only: int32, int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use frumpy, only: ndarray_r64, owned_descriptor_r64, view_descriptor_r64, &
    matmul_r64, solve_r64, outer_r64, dot_r64, frumpy_status, FRUMPY_STATUS_INVALID_SHAPE, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
    FRUMPY_STATUS_OVERFLOW, FRUMPY_STATUS_SINGULAR_MATRIX, FRUMPY_DTYPE_I32
  use frumpy, only: vector_norm_r64, matrix_norm_r64, FRUMPY_STATUS_INVALID_AXIS
  implicit none

  call exercise()
  call exercise_outer()
  call exercise_numerical()

contains

  subroutine exercise()
    type(ndarray_r64) :: a, b, rhs, result, solution, reversed, invalid, other
    type(frumpy_status) :: status
    integer(int64) :: oversized, byte_limit

    a = owned_descriptor_r64([2_int64, 2_int64])
    a%data = [2.0_real64, 1.0_real64, 1.0_real64, 3.0_real64]
    b = owned_descriptor_r64([2_int64, 2_int64])
    b%data = [1.0_real64, 2.0_real64, 3.0_real64, 4.0_real64]
    rhs = owned_descriptor_r64([2_int64])
    rhs%data = [5.0_real64, 10.0_real64]
    solution = solve_r64(a, rhs, status)
    call require(status%is_ok(), 'solve status')
    call require(all(abs(solution%data - [1.0_real64, 3.0_real64]) < 1e-14_real64), 'solve values')
    call require(all(solution%shape == [2_int64]), 'vector solve shape')
    call require(storage_size(solution%data) == 64, 'float64 solution')
    call require(.not. associated(solution%data, rhs%data), 'independent solution')
    call require(all(abs(rhs%data - [5.0_real64, 10.0_real64]) < 1e-14_real64), 'rhs preserved')
    reversed = view_descriptor_r64(a, [2_int64, 2_int64], [-2_int64, 1_int64], 3_int64)
    result = matmul_r64(reversed, b)
    call require(all(abs(result%data - [10.0_real64, 14.0_real64, &
      5.0_real64, 8.0_real64]) < 1e-14_real64), 'strided matmul without status')
    call require(all(result%shape == [2_int64, 2_int64]), 'matmul shape')
    call require(all(result%strides == [2_int64, 1_int64]), 'matmul C strides')
    call require(result%offset == 1_int64, 'matmul offset')
    call require(result%owns_data .and. result%is_c_contiguous, 'owned matmul')
    call require(solution%owns_data .and. solution%is_c_contiguous, 'owned solve')
    call require(.not. associated(result%data, a%data), 'independent matmul lhs')
    call require(.not. associated(result%data, b%data), 'independent matmul rhs')
    call require(all(abs(a%data - [2.0_real64, 1.0_real64, &
      1.0_real64, 3.0_real64]) < 1e-14_real64), 'coefficient matrix preserved')
    call a%release()
    call reversed%release()
    call b%release()
    call rhs%release()
    call require(abs(solution%data(2) - 3.0_real64) < 1e-14_real64, 'solution survives')
    call require(abs(result%data(4) - 8.0_real64) < 1e-14_real64, 'product survives')

    a = owned_descriptor_r64([2_int64, 2_int64])
    a%data = 0.0_real64
    rhs = owned_descriptor_r64([2_int64])
    rhs%data = 1.0_real64
    solution = solve_r64(a, rhs, status)
    call require(status%code == FRUMPY_STATUS_SINGULAR_MATRIX, 'singular solve status')
    call require(.not. solution%has_storage(), 'singular solve has no result')
    solution = solve_r64(a, rhs)
    call require(.not. solution%has_storage(), 'singular without status')
    result = matmul_r64(invalid, a, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'missing storage')
    invalid = view_descriptor_r64(a, [2_int64], [huge(1_int64)], 1_int64)
    result = matmul_r64(invalid, rhs, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'bad reachable bounds')
    invalid = view_descriptor_r64(a, [2_int64], [1_int64], 1_int64)
    invalid%rank = 2_int32
    solution = solve_r64(a, invalid, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'bad rank')
    invalid%rank = 1_int32
    deallocate(invalid%shape)
    result = matmul_r64(a, invalid, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'missing metadata')
    a%dtype_id = FRUMPY_DTYPE_I32
    solution = solve_r64(a, rhs, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_DTYPE, 'forged dtype')
    a%dtype_id = rhs%dtype_id

    oversized = int(huge(1_int32), int64) + 1_int64
    invalid = view_descriptor_r64(a, [1_int64, oversized], [0_int64, 0_int64], 1_int64)
    other = view_descriptor_r64(a, [oversized, 1_int64], [0_int64, 0_int64], 1_int64)
    result = matmul_r64(invalid, other, status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'matmul LP64 guard')
    call require(.not. result%has_storage(), 'LP64 rejection without allocation')
    oversized = int(huge(1_int32), int64)
    invalid = view_descriptor_r64(a, [oversized, oversized], [0_int64, 0_int64], 1_int64)
    other = view_descriptor_r64(a, [oversized], [0_int64], 1_int64)
    solution = solve_r64(invalid, other, status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'solve workspace byte guard')
    call require(.not. solution%has_storage(), 'workspace rejection without result')
    byte_limit = shiftr(huge(1_int64), 3) + 1_int64
    invalid = view_descriptor_r64(a, [byte_limit, 1_int64, 1_int64], &
      [0_int64, 0_int64, 0_int64], 1_int64)
    other = view_descriptor_r64(a, [1_int64], [0_int64], 1_int64)
    result = matmul_r64(invalid, other, status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'output byte guard')
    call require(.not. result%has_storage(), 'output byte rejection without result')

    a%data = 1.0_real64
    a%data(1) = ieee_value(0.0_real64, ieee_quiet_nan)
    result = matmul_r64(a, rhs, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'nonfinite matmul')
    call require(.not. result%has_storage(), 'nonfinite output released')
    solution = solve_r64(a, rhs, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'nonfinite solve')
    call require(.not. solution%has_storage(), 'nonfinite solve no result')
  end subroutine exercise

  subroutine exercise_outer()
    type(ndarray_r64) :: source, reversed, result, invalid, huge_view, empty
    type(frumpy_status) :: status

    source = owned_descriptor_r64([2_int64, 2_int64])
    source%data = [1.0_real64, 2.0_real64, 3.0_real64, 4.0_real64]
    reversed = view_descriptor_r64(source, [2_int64], [-2_int64], 4_int64)
    result = outer_r64(reversed, reversed)
    call require(all(result%shape == [2_int64, 2_int64]), 'outer shape')
    call require(all(result%strides == [2_int64, 1_int64]), 'outer strides')
    call require(result%owns_data .and. result%is_c_contiguous, 'outer ownership')
    call require(result%offset == 1_int64, 'outer offset')
    call require(.not. associated(result%data, source%data), 'outer independent')
    call require(all(abs(source%data - [1.0_real64, 2.0_real64, &
      3.0_real64, 4.0_real64]) < 1e-14_real64), 'outer input preserved')
    call source%release()
    call reversed%release()
    call require(all(abs(result%data - [16.0_real64, 8.0_real64, &
      8.0_real64, 4.0_real64]) < 1e-14_real64), 'outer survives inputs')
    source = outer_r64(invalid, result, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'outer missing storage')
    call require(.not. source%has_storage(), 'outer failure has no storage')
    invalid = view_descriptor_r64(result, [2_int64], [huge(1_int64)], 1_int64)
    source = outer_r64(result, invalid, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'outer bad bounds')
    invalid = view_descriptor_r64(result, [2_int64], [1_int64], 1_int64)
    invalid%dtype_id = FRUMPY_DTYPE_I32
    source = outer_r64(invalid, result, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_DTYPE, 'outer forged dtype')
    source = outer_r64(invalid, result)
    call require(.not. source%has_storage(), 'outer omitted failure status')
    huge_view = view_descriptor_r64(result, [shiftr(huge(1_int64), 3)], [0_int64], 1_int64)
    source = outer_r64(huge_view, result, status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'outer byte overflow')
    call require(.not. source%has_storage(), 'outer overflow has no storage')
    huge_view = view_descriptor_r64(result, [huge(1_int64)], [0_int64], 1_int64)
    source = outer_r64(huge_view, result, status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'outer element overflow')
    empty = owned_descriptor_r64([0_int64])
    source = outer_r64(huge_view, empty, status)
    call require(status%is_ok(), 'outer huge empty avoids iteration')
    call require(all(source%shape == [huge(1_int64), 0_int64]), 'outer huge empty shape')
  end subroutine exercise_outer

  subroutine exercise_numerical()
    type(ndarray_r64) :: a, b, result, invalid, vector, matrix
    type(frumpy_status) :: status
    integer(int64) :: big

    a = owned_descriptor_r64([2_int64, 2_int64])
    a%data = [1.0_real64, 2.0_real64, 3.0_real64, 4.0_real64]
    b = view_descriptor_r64(a, [2_int64], [-1_int64], 2_int64)
    result = dot_r64(a, b, status)
    call require(status%is_ok(), 'dot status')
    call require(all(abs(result%data - [4.0_real64, 10.0_real64]) < 1e-14_real64), 'dot values')
    call require(result%owns_data .and. result%is_c_contiguous, 'dot owns C result')
    vector = vector_norm_r64(a, axis0=0_int32, status=status)
    call require(status%is_ok(), 'vector norm status')
    call require(all(abs(vector%data - sqrt([10.0_real64, 20.0_real64])) < 1e-14_real64), &
      'vector norm axis')
    matrix = matrix_norm_r64(a, axes0=[1_int32, 0_int32], keepdims=.true., status=status)
    call require(status%is_ok(), 'matrix norm axes status')
    call require(all(matrix%shape == [1_int64, 1_int64]), 'matrix norm keepdims')
    call require(abs(matrix%data(1) - sqrt(30.0_real64)) < 1e-14_real64, 'matrix norm value')
    call a%release()
    call b%release()
    call require(abs(result%data(2) - 10.0_real64) < 1e-14_real64, 'dot lifetime')
    call require(vector%has_storage() .and. matrix%has_storage(), 'norm lifetime')
    result = matrix_norm_r64(matrix, axes0=[0_int32, 0_int32], status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_AXIS, 'norm duplicate axes')
    call require(.not. result%has_storage(), 'norm error has no storage')
    result = dot_r64(invalid, vector, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'dot absent source')
    result = vector_norm_r64(invalid, status=status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'norm absent source')
    invalid = view_descriptor_r64(vector, [2_int64], [huge(1_int64)], 1_int64)
    result = dot_r64(vector, invalid, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'dot bounds')
    result = vector_norm_r64(invalid, status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'norm bounds')
    big = shiftr(huge(1_int64), 3) + 1_int64
    a = view_descriptor_r64(vector, [big, 1_int64], [0_int64, 0_int64], 1_int64)
    b = view_descriptor_r64(vector, [1_int64], [0_int64], 1_int64)
    result = dot_r64(a, b, status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'dot output bytes')
    result = vector_norm_r64(a, axis0=1_int32, status=status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'norm output bytes')
    a = view_descriptor_r64(vector, [big, 1_int64, 1_int64], &
      [0_int64, 0_int64, 0_int64], 1_int64)
    result = solve_r64(a, b, status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'batched solve output bytes')
    a = owned_descriptor_r64([2_int64, 2_int64, 2_int64])
    a%data = [1.0_real64, 0.0_real64, 0.0_real64, 1.0_real64, &
      0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64]
    b = owned_descriptor_r64([2_int64])
    b%data = 1.0_real64
    result = solve_r64(a, b, status)
    call require(status%code == FRUMPY_STATUS_SINGULAR_MATRIX, 'later batch singular')
    call require(.not. result%has_storage(), 'partial solve result released')
    a%data(5) = ieee_value(0.0_real64, ieee_quiet_nan)
    result = solve_r64(a, b, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'later batch nonfinite')
    call require(.not. result%has_storage(), 'partial nonfinite result released')
  end subroutine exercise_numerical

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_linalg_r64
