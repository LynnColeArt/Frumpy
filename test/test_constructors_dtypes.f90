!> Convenience constructors preserve dtype, order, values and independent storage.
program test_constructors_dtypes
  use iso_fortran_env, only: int8, int32, int64, real32
  use frumpy, only: frumpy_status, FRUMPY_ORDER_F, FRUMPY_STATUS_INVALID_SHAPE, &
    ndarray_r32, view_descriptor_r32, empty_r32, zeros_r32, ones_r32, full_r32, &
      asarray_r32, copy_r32, ascontiguousarray_r32, &
    ndarray_i32, view_descriptor_i32, empty_i32, zeros_i32, ones_i32, full_i32, &
      asarray_i32, copy_i32, ascontiguousarray_i32, &
    ndarray_i64, view_descriptor_i64, empty_i64, zeros_i64, ones_i64, full_i64, &
      asarray_i64, copy_i64, ascontiguousarray_i64, &
    ndarray_bool, view_descriptor_bool, empty_bool, zeros_bool, ones_bool, full_bool, &
      asarray_bool, copy_bool, ascontiguousarray_bool
  implicit none
  call exercise_r32()
  call exercise_i32()
  call exercise_i64()
  call exercise_bool()
contains
  subroutine exercise_r32()
    type(ndarray_r32) :: source, view, result, invalid
    type(frumpy_status) :: status
    real(real32) :: values(6) = [1.0_real32,2.0_real32,3.0_real32,4.0_real32,5.0_real32,6.0_real32]

    source = asarray_r32(values, [2_int64, 3_int64], FRUMPY_ORDER_F, status)
    call require(status%is_ok(), 'r32 asarray')
    call require(all(source%strides == [1_int64, 2_int64]), 'r32 F strides')
    view = view_descriptor_r32(source, [2_int64, 3_int64], [-1_int64, 2_int64], 2_int64)
    result = copy_r32(view, status=status)
    call require(status%is_ok(), 'r32 strided copy')
    call require(all(abs(result%data - [4.0_real32,5.0_real32,6.0_real32,1.0_real32, &
      2.0_real32,3.0_real32]) < 1e-6_real32), 'r32 copy values')
    call require(.not. associated(result%data, source%data), 'r32 independent copy')
    call source%release()
    call view%release()
    call require(all(abs(result%data - [4.0_real32,5.0_real32,6.0_real32,1.0_real32, &
      2.0_real32,3.0_real32]) < 1e-6_real32), 'r32 copy survives')
    source = ascontiguousarray_r32(result, status)
    call require(status%is_ok() .and. source%is_c_contiguous, 'r32 contiguous copy')
    call require(.not. associated(source%data, result%data), 'r32 contiguous explicit copy')
    result = zeros_r32([2_int64], status=status)
    call require(status%is_ok(), 'r32 zeros')
    call require(all(abs(real(result%data, real32)) < 1e-6_real32), 'r32 zero values')
    result = ones_r32([2_int64], status=status)
    call require(status%is_ok() .and. all(result%data > 0.5_real32), 'r32 ones')
    result = full_r32([integer(int64) ::], 1.0_real32, status=status)
    call require(status%is_ok() .and. result%rank == 0, 'r32 scalar full')
    result = empty_r32([2_int64, 0_int64], status=status)
    call require(status%is_ok() .and. result%size() == 0, 'r32 empty')
    result = asarray_r32(values, [7_int64], status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'r32 shape mismatch')
    call require(.not. result%has_storage(), 'r32 mismatch no output')
    invalid = view_descriptor_r32(source, [2_int64], [huge(1_int64)], 1_int64)
    result = copy_r32(invalid, status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'r32 unreachable copy')
    call require(.not. result%has_storage(), 'r32 bad copy no output')
    result = full_r32([-1_int64], 0.0_real32, status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'r32 negative shape')
  end subroutine exercise_r32

  subroutine exercise_i32()
    type(ndarray_i32) :: source, view, result, invalid
    type(frumpy_status) :: status
    integer(int32) :: values(6) = [1_int32,2_int32,3_int32,4_int32,5_int32,6_int32]

    source = asarray_i32(values, [2_int64, 3_int64], FRUMPY_ORDER_F, status)
    call require(status%is_ok(), 'i32 asarray')
    call require(all(source%strides == [1_int64, 2_int64]), 'i32 F strides')
    view = view_descriptor_i32(source, [2_int64, 3_int64], [-1_int64, 2_int64], 2_int64)
    result = copy_i32(view, status=status)
    call require(status%is_ok(), 'i32 strided copy')
    call require(all(result%data == [4_int32,5_int32,6_int32,1_int32,2_int32,3_int32]), &
      'i32 copy values')
    call require(.not. associated(result%data, source%data), 'i32 independent copy')
    call source%release()
    call view%release()
    call require(all(result%data == [4_int32,5_int32,6_int32,1_int32,2_int32,3_int32]), &
      'i32 copy survives')
    source = ascontiguousarray_i32(result, status)
    call require(status%is_ok() .and. source%is_c_contiguous, 'i32 contiguous copy')
    call require(.not. associated(source%data, result%data), 'i32 contiguous explicit copy')
    result = zeros_i32([2_int64], status=status)
    call require(status%is_ok(), 'i32 zeros')
    call require(all(abs(real(result%data, real32)) < 1e-6_real32), 'i32 zero values')
    result = ones_i32([2_int64], status=status)
    call require(status%is_ok() .and. all(result%data > 0), 'i32 ones')
    result = full_i32([integer(int64) ::], 1_int32, status=status)
    call require(status%is_ok() .and. result%rank == 0, 'i32 scalar full')
    result = empty_i32([2_int64, 0_int64], status=status)
    call require(status%is_ok() .and. result%size() == 0, 'i32 empty')
    result = asarray_i32(values, [7_int64], status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'i32 shape mismatch')
    call require(.not. result%has_storage(), 'i32 mismatch no output')
    invalid = view_descriptor_i32(source, [2_int64], [huge(1_int64)], 1_int64)
    result = copy_i32(invalid, status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'i32 unreachable copy')
    call require(.not. result%has_storage(), 'i32 bad copy no output')
    result = full_i32([-1_int64], 0_int32, status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'i32 negative shape')
  end subroutine exercise_i32

  subroutine exercise_i64()
    type(ndarray_i64) :: source, view, result, invalid
    type(frumpy_status) :: status
    integer(int64) :: values(6) = [1_int64,2_int64,3_int64,4_int64,5_int64,6_int64]

    source = asarray_i64(values, [2_int64, 3_int64], FRUMPY_ORDER_F, status)
    call require(status%is_ok(), 'i64 asarray')
    call require(all(source%strides == [1_int64, 2_int64]), 'i64 F strides')
    view = view_descriptor_i64(source, [2_int64, 3_int64], [-1_int64, 2_int64], 2_int64)
    result = copy_i64(view, status=status)
    call require(status%is_ok(), 'i64 strided copy')
    call require(all(result%data == [4_int64,5_int64,6_int64,1_int64,2_int64,3_int64]), &
      'i64 copy values')
    call require(.not. associated(result%data, source%data), 'i64 independent copy')
    call source%release()
    call view%release()
    call require(all(result%data == [4_int64,5_int64,6_int64,1_int64,2_int64,3_int64]), &
      'i64 copy survives')
    source = ascontiguousarray_i64(result, status)
    call require(status%is_ok() .and. source%is_c_contiguous, 'i64 contiguous copy')
    call require(.not. associated(source%data, result%data), 'i64 contiguous explicit copy')
    result = zeros_i64([2_int64], status=status)
    call require(status%is_ok(), 'i64 zeros')
    call require(all(abs(real(result%data, real32)) < 1e-6_real32), 'i64 zero values')
    result = ones_i64([2_int64], status=status)
    call require(status%is_ok() .and. all(result%data > 0), 'i64 ones')
    result = full_i64([integer(int64) ::], 1_int64, status=status)
    call require(status%is_ok() .and. result%rank == 0, 'i64 scalar full')
    result = empty_i64([2_int64, 0_int64], status=status)
    call require(status%is_ok() .and. result%size() == 0, 'i64 empty')
    result = asarray_i64(values, [7_int64], status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'i64 shape mismatch')
    call require(.not. result%has_storage(), 'i64 mismatch no output')
    invalid = view_descriptor_i64(source, [2_int64], [huge(1_int64)], 1_int64)
    result = copy_i64(invalid, status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'i64 unreachable copy')
    call require(.not. result%has_storage(), 'i64 bad copy no output')
    result = full_i64([-1_int64], 0_int64, status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'i64 negative shape')
  end subroutine exercise_i64

  subroutine exercise_bool()
    type(ndarray_bool) :: source, view, result, invalid
    type(frumpy_status) :: status
    logical :: values(6) = [.true., .false., .true., .false., .true., .false.]

    source = asarray_bool(values, [2_int64, 3_int64], FRUMPY_ORDER_F, status)
    call require(status%is_ok(), 'bool asarray')
    call require(all(source%strides == [1_int64, 2_int64]), 'bool F strides')
    view = view_descriptor_bool(source, [2_int64, 3_int64], [-1_int64, 2_int64], 2_int64)
    result = copy_bool(view, status=status)
    call require(status%is_ok(), 'bool strided copy')
    call require(all(result%data == [0_int8,1_int8,0_int8,1_int8,0_int8,1_int8]), &
      'bool copy values')
    call require(.not. associated(result%data, source%data), 'bool independent copy')
    call source%release()
    call view%release()
    call require(all(result%data == [0_int8,1_int8,0_int8,1_int8,0_int8,1_int8]), &
      'bool copy survives')
    source = ascontiguousarray_bool(result, status)
    call require(status%is_ok() .and. source%is_c_contiguous, 'bool contiguous copy')
    call require(.not. associated(source%data, result%data), 'bool contiguous explicit copy')
    result = zeros_bool([2_int64], status=status)
    call require(status%is_ok(), 'bool zeros')
    call require(all(abs(real(result%data, real32)) < 1e-6_real32), 'bool zero values')
    result = ones_bool([2_int64], status=status)
    call require(status%is_ok() .and. all(result%data > 0), 'bool ones')
    result = full_bool([integer(int64) ::], .true., status=status)
    call require(status%is_ok() .and. result%rank == 0, 'bool scalar full')
    result = empty_bool([2_int64, 0_int64], status=status)
    call require(status%is_ok() .and. result%size() == 0, 'bool empty')
    result = asarray_bool(values, [7_int64], status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'bool shape mismatch')
    call require(.not. result%has_storage(), 'bool mismatch no output')
    invalid = view_descriptor_bool(source, [2_int64], [huge(1_int64)], 1_int64)
    result = copy_bool(invalid, status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'bool unreachable copy')
    call require(.not. result%has_storage(), 'bool bad copy no output')
    result = full_bool([-1_int64], .false., status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'bool negative shape')
  end subroutine exercise_bool

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_constructors_dtypes
