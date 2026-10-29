program test_products_r32
  use iso_fortran_env, only: int32, int64, real32
  use frumpy, only: ndarray_r32, owned_descriptor_r32, view_descriptor_r32, &
    dot_r32, outer_r32, frumpy_status, FRUMPY_STATUS_INVALID_SHAPE, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
    FRUMPY_STATUS_OVERFLOW, FRUMPY_DTYPE_I32
  implicit none
  call exercise_outer()
  call exercise_dot()
  call exercise_accumulation()
contains
  subroutine exercise_outer()
    type(ndarray_r32) :: source, reversed, result, invalid, huge_view, empty
    type(frumpy_status) :: status

    source = owned_descriptor_r32([2_int64, 2_int64])
    source%data = [1.0_real32, 2.0_real32, 3.0_real32, 4.0_real32]
    reversed = view_descriptor_r32(source, [2_int64], [-2_int64], 4_int64)
    result = outer_r32(reversed, reversed)
    call require(all(result%shape == [2_int64, 2_int64]), 'outer shape')
    call require(all(result%strides == [2_int64, 1_int64]), 'outer strides')
    call require(result%owns_data .and. result%is_c_contiguous, 'outer ownership')
    call require(result%offset == 1_int64, 'outer offset')
    call require(.not. associated(result%data, source%data), 'outer independent')
    call require(all(abs(source%data - [1.0_real32, 2.0_real32, &
      3.0_real32, 4.0_real32]) < 1e-6_real32), 'outer input preserved')
    call source%release()
    call reversed%release()
    call require(all(abs(result%data - [16.0_real32, 8.0_real32, &
      8.0_real32, 4.0_real32]) < 1e-6_real32), 'outer survives inputs')
    source = outer_r32(invalid, result, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'outer missing storage')
    call require(.not. source%has_storage(), 'outer failure has no storage')
    invalid = view_descriptor_r32(result, [2_int64], [huge(1_int64)], 1_int64)
    source = outer_r32(result, invalid, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'outer bad bounds')
    invalid = view_descriptor_r32(result, [2_int64], [1_int64], 1_int64)
    invalid%dtype_id = FRUMPY_DTYPE_I32
    source = outer_r32(invalid, result, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_DTYPE, 'outer forged dtype')
    source = outer_r32(invalid, result)
    call require(.not. source%has_storage(), 'outer omitted failure status')
    huge_view = view_descriptor_r32(result, [shiftr(huge(1_int64), 2)], [0_int64], 1_int64)
    source = outer_r32(huge_view, result, status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'outer byte overflow')
    call require(.not. source%has_storage(), 'outer overflow has no storage')
    huge_view = view_descriptor_r32(result, [huge(1_int64)], [0_int64], 1_int64)
    source = outer_r32(huge_view, result, status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'outer element overflow')
    empty = owned_descriptor_r32([0_int64])
    source = outer_r32(huge_view, empty, status)
    call require(status%is_ok(), 'outer huge empty avoids iteration')
    call require(all(source%shape == [huge(1_int64), 0_int64]), 'outer huge empty shape')
  end subroutine exercise_outer

  subroutine exercise_dot()
    type(ndarray_r32) :: a, b, result, invalid
    type(frumpy_status) :: status
    integer(int64) :: big

    a = owned_descriptor_r32([2_int64, 3_int64])
    a%data = [1.0_real32,2.0_real32,3.0_real32,4.0_real32,5.0_real32,6.0_real32]
    b = view_descriptor_r32(a, [3_int64], [-1_int64], 3_int64)
    result = dot_r32(a,b,status)
    call require(status%is_ok(), 'dot status')
    call require(all(abs(result%data-[10.0_real32,28.0_real32]) < 1e-6_real32), 'dot values')
    call require(result%owns_data .and. result%is_c_contiguous, 'owned C-order result')
    call require(storage_size(result%data) == 32, 'float32 result')
    call require(.not. associated(result%data,a%data), 'independent payload')
    call a%release()
    call b%release()
    call require(abs(result%data(2)-28.0_real32) < 1e-6_real32, 'result survives sources')
    a = dot_r32(invalid,result,status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, 'missing storage')
    invalid = view_descriptor_r32(result,[2_int64],[huge(1_int64)],1_int64)
    a = dot_r32(invalid,result,status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'invalid bounds')
    invalid = view_descriptor_r32(result,[2_int64],[1_int64],1_int64)
    invalid%dtype_id = FRUMPY_DTYPE_I32
    a = dot_r32(invalid,result,status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_DTYPE, 'forged dtype')
    a = dot_r32(invalid,result)
    call require(.not. a%has_storage(), 'failure without status')
    big = shiftr(huge(1_int64),2)+1_int64
    a = view_descriptor_r32(result,[big,1_int64],[0_int64,0_int64],1_int64)
    b = view_descriptor_r32(result,[1_int64],[0_int64],1_int64)
    invalid = dot_r32(a,b,status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'output bytes guard')
    call require(.not. invalid%has_storage(), 'overflow has no output')
    a = view_descriptor_r32(result,spread(1_int64,1,32),spread(0_int64,1,32),1_int64)
    b = view_descriptor_r32(result,[1_int64,1_int64,1_int64],[0_int64,0_int64,0_int64],1_int64)
    invalid = dot_r32(a,b,status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'output rank guard')
    call require(.not. invalid%has_storage(), 'rank overflow has no output')
  end subroutine exercise_dot

  subroutine exercise_accumulation()
    type(ndarray_r32) :: a, b, result
    type(frumpy_status) :: status

    a = owned_descriptor_r32([66_int64])
    b = owned_descriptor_r32([66_int64])
    a%data = 1.0_real32
    b%data = 1.0_real32
    a%data(1) = 16777216.0_real32
    a%data(66) = -16777216.0_real32
    result = dot_r32(a,b,status)
    call require(status%is_ok(), 'pairwise cancellation status')
    call require(abs(result%data(1)-48.0_real32) < 1e-6_real32, '32-term leaf pairwise policy')
    a = owned_descriptor_r32([0_int64])
    b = owned_descriptor_r32([0_int64])
    result = dot_r32(a,b,status)
    call require(status%is_ok() .and. result%rank == 0, 'empty scalar dot')
    call require(abs(result%data(1)) < tiny(1.0_real32), 'empty contraction zero')
  end subroutine exercise_accumulation

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_products_r32
