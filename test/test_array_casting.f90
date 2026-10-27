!> Array casting is transactional and distinct from exact scalar casting.
program test_array_casting
  use iso_fortran_env, only: int8, int32, int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use frumpy, only: ndarray_r64, ndarray_i32, ndarray_i64, ndarray_bool, frumpy_status, &
    owned_descriptor_r64, owned_descriptor_i32, owned_descriptor_i64, owned_descriptor_bool, &
    view_descriptor_i64, &
    astype, FRUMPY_CASTING_SAFE, FRUMPY_CASTING_UNSAFE, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, FRUMPY_STATUS_OVERFLOW
  implicit none
  call exercise()
  call exercise_contiguous()
contains
  subroutine exercise()
    type(ndarray_r64) :: source, real_result
    type(ndarray_i32) :: result
    type(ndarray_i64) :: wide
    type(ndarray_bool) :: truth
    type(frumpy_status) :: status

    source = owned_descriptor_r64([3_int64])
    source%data = [1.9_real64, -2.9_real64, -0.0_real64]
    call astype(source, result, status=status)
    call require(status%is_ok(), 'unsafe default array cast')
    call require(all(result%data == [1_int32, -2_int32, 0_int32]), 'fractional truncation')
    call require(result%owns_data .and. result%is_c_contiguous, 'cast owns output')
    call astype(source, result, FRUMPY_CASTING_SAFE, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'safe policy rejects')
    call require(all(result%data == [1_int32, -2_int32, 0_int32]), 'policy failure preserves output')
    source%data(2) = ieee_value(0.0_real64, ieee_quiet_nan)
    call astype(source, result, FRUMPY_CASTING_UNSAFE, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'NaN to integer rejected')
    call require(all(result%data == [1_int32, -2_int32, 0_int32]), 'late failure preserves output')
    call astype(source, truth, status=status)
    call require(status%is_ok(), 'NaN truth conversion allowed')
    call require(all(truth%data == [1_int8, 1_int8, 0_int8]), 'truth normalization')
    wide = owned_descriptor_i64([2_int64])
    wide%data = [huge(1_int64), -huge(1_int64)-1_int64]
    call astype(wide, result, status=status)
    call require(status%is_ok(), 'integer narrowing wraps')
    call require(all(result%data == [-1_int32, 0_int32]), 'integer low bits')
    call astype(wide, real_result, FRUMPY_CASTING_SAFE, status)
    call require(status%is_ok(), 'dtype safe permits integer rounding')
    call require(abs(real_result%data(1) - 2.0_real64**63) < 1.0_real64, 'int64 rounds to real64')
    source%data = 2.0_real64**63
    call astype(source, wide, status=status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'real integer boundary rejected')
    call require(wide%data(1) == huge(1_int64), 'overflow preserves destination')
    call source%release()
    call require(truth%data(2) == 1_int8, 'cast survives source')
  end subroutine exercise

  subroutine exercise_contiguous()
    type(ndarray_i64) :: owner, source
    type(ndarray_r64) :: result
    type(frumpy_status) :: status

    owner = owned_descriptor_i64([6_int64])
    owner%data = [1_int64,2_int64,3_int64,4_int64,5_int64,6_int64]
    source = view_descriptor_i64(owner, [1_int64,3_int64], [-99_int64,1_int64], 2_int64)
    source%is_c_contiguous = .false.
    call astype(source, result, status=status)
    call require(status%is_ok(), 'offset singleton contiguous cast')
    call require(all(abs(result%data-[2.0_real64,3.0_real64,4.0_real64])<1e-9_real64), &
      'contiguous offset values')
    source = view_descriptor_i64(owner, [3_int64], [2_int64], 1_int64)
    source%is_c_contiguous = .true.
    call astype(source, result, status=status)
    call require(status%is_ok(), 'forged contiguous flag ignored')
    call require(all(abs(result%data-[1.0_real64,3.0_real64,5.0_real64])<1e-9_real64), &
      'strided fallback values')
    source%offset = 99_int64
    call astype(source, result, status=status)
    call require(status%is_failure(), 'bounds checked before fast path')
    call require(abs(result%data(1)-1.0_real64)<1e-9_real64, 'failure preserves result')
    call owner%release()
    call source%release()
    call require(abs(result%data(3)-5.0_real64)<1e-9_real64, 'cast owns independent storage')
  end subroutine exercise_contiguous

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_array_casting
