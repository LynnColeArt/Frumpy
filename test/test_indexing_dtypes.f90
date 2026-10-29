!> Typed lifetime, aliasing, repeated-position and failure invariants.
program test_indexing_dtypes
  use iso_fortran_env, only: int8, int32, int64, real32, real64
  use frumpy, only: mask_select, assign, mask_assign, frumpy_status
  use frumpy_ndarray_bool, only: ndarray_bool, owned_descriptor_bool, view_descriptor_bool
  use frumpy_ndarray_i32, only: ndarray_i32, owned_descriptor_i32, view_descriptor_i32
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64, view_descriptor_i64
  use frumpy_ndarray_r32, only: ndarray_r32, owned_descriptor_r32, view_descriptor_r32
  use frumpy_ndarray_r64, only: ndarray_r64, owned_descriptor_r64, view_descriptor_r64
  implicit none
  call test_bool()
  call test_i32()
  call test_i64()
  call test_r32()
  call test_r64()
contains
  subroutine test_bool()
    type(ndarray_bool) :: source, rhs, result, repeated, invalid
    type(ndarray_bool) :: mask, mask_view
    type(frumpy_status) :: status

    source = owned_descriptor_bool([4_int64], status=status)
    source%data = [0_int8, 1_int8, 0_int8, 1_int8]
    mask = owned_descriptor_bool([4_int64], status=status)
    mask%data = [1_int8, 0_int8, -7_int8, 1_int8]
    result = mask_select(source, mask, status)
    call require(status%is_ok(), 'extract status')
    call require(all(int(result%data, int64) == [0_int64, 0_int64, 1_int64]), 'extract values')
    call source%release()
    call require(all(int(result%data, int64) == [0_int64, 0_int64, 1_int64]), 'extract lifetime')
    source = owned_descriptor_bool([4_int64], status=status)
    source%data = [0_int8, 1_int8, 0_int8, 1_int8]
    rhs = view_descriptor_bool(source, [4_int64], [-1_int64], 4_int64, status)
    call assign(source, rhs, status)
    call require(status%is_ok(), 'overlap assign status')
    call require(all(int(source%data,int64) == [1_int64,0_int64,1_int64,0_int64]), 'overlap staged')
    mask%data = 1_int8
    call mask_assign(source, mask, rhs, status)
    call require(status%is_ok(), 'overlap masked status')
    call require(all(int(source%data,int64) == [0_int64,1_int64,0_int64,1_int64]), 'masked staged')
    call assign(source, source, status)
    call require(status%is_ok(), 'identical descriptor supported')
    invalid = owned_descriptor_bool([2_int64], status=status)
    call mask_assign(source, mask, invalid, status)
    call require(status%code == 1, 'shape error')
    call require(all(int(source%data,int64) == [0_int64,1_int64,0_int64,1_int64]), 'failure atomic')
    invalid%offset = 3_int64
    call assign(source, invalid, status)
    call require(status%is_failure(), 'invalid storage rejected')
    repeated = view_descriptor_bool(source, [4_int64], [0_int64], 1_int64, status)
    call mask_assign(repeated, mask, rhs, status)
    call require(status%is_ok(), 'repeated target status')
    call require(int(source%data(1),int64) == 0_int64, 'last selected write wins')
    mask_view = view_descriptor_bool(mask, [4_int64], [-1_int64], 4_int64, status)
    result = mask_select(source, mask_view, status)
    call require(status%is_ok(), 'reversed mask')
    call require(size(result%data) == 4, 'mask count')
    invalid = owned_descriptor_bool([integer(int64)::], status=status)
    invalid%data = -3_int8
    call assign(source, invalid, status)
    call require(status%is_ok() .and. all(source%data == 1_int8), 'scalar bool normalization')
  end subroutine test_bool

  subroutine test_i32()
    type(ndarray_i32) :: source, rhs, result, repeated, invalid
    type(ndarray_bool) :: mask, mask_view
    type(frumpy_status) :: status

    source = owned_descriptor_i32([4_int64], status=status)
    source%data = [0_int32, 1_int32, 0_int32, 1_int32]
    mask = owned_descriptor_bool([4_int64], status=status)
    mask%data = [1_int8, 0_int8, -7_int8, 1_int8]
    result = mask_select(source, mask, status)
    call require(status%is_ok(), 'extract status')
    call require(all(int(result%data, int64) == [0_int64, 0_int64, 1_int64]), 'extract values')
    call source%release()
    call require(all(int(result%data, int64) == [0_int64, 0_int64, 1_int64]), 'extract lifetime')
    source = owned_descriptor_i32([4_int64], status=status)
    source%data = [0_int32, 1_int32, 0_int32, 1_int32]
    rhs = view_descriptor_i32(source, [4_int64], [-1_int64], 4_int64, status)
    call assign(source, rhs, status)
    call require(status%is_ok(), 'overlap assign status')
    call require(all(int(source%data,int64) == [1_int64,0_int64,1_int64,0_int64]), 'overlap staged')
    mask%data = 1_int8
    call mask_assign(source, mask, rhs, status)
    call require(status%is_ok(), 'overlap masked status')
    call require(all(int(source%data,int64) == [0_int64,1_int64,0_int64,1_int64]), 'masked staged')
    call assign(source, source, status)
    call require(status%is_ok(), 'identical descriptor supported')
    invalid = owned_descriptor_i32([2_int64], status=status)
    call mask_assign(source, mask, invalid, status)
    call require(status%code == 1, 'shape error')
    call require(all(int(source%data,int64) == [0_int64,1_int64,0_int64,1_int64]), 'failure atomic')
    invalid%offset = 3_int64
    call assign(source, invalid, status)
    call require(status%is_failure(), 'invalid storage rejected')
    repeated = view_descriptor_i32(source, [4_int64], [0_int64], 1_int64, status)
    call mask_assign(repeated, mask, rhs, status)
    call require(status%is_ok(), 'repeated target status')
    call require(int(source%data(1),int64) == 0_int64, 'last selected write wins')
    mask_view = view_descriptor_bool(mask, [4_int64], [-1_int64], 4_int64, status)
    result = mask_select(source, mask_view, status)
    call require(status%is_ok(), 'reversed mask')
    call require(size(result%data) == 4, 'mask count')
  end subroutine test_i32

  subroutine test_i64()
    type(ndarray_i64) :: source, rhs, result, repeated, invalid
    type(ndarray_bool) :: mask, mask_view
    type(frumpy_status) :: status

    source = owned_descriptor_i64([4_int64], status=status)
    source%data = [0_int64, 1_int64, 0_int64, 1_int64]
    mask = owned_descriptor_bool([4_int64], status=status)
    mask%data = [1_int8, 0_int8, -7_int8, 1_int8]
    result = mask_select(source, mask, status)
    call require(status%is_ok(), 'extract status')
    call require(all(int(result%data, int64) == [0_int64, 0_int64, 1_int64]), 'extract values')
    call source%release()
    call require(all(int(result%data, int64) == [0_int64, 0_int64, 1_int64]), 'extract lifetime')
    source = owned_descriptor_i64([4_int64], status=status)
    source%data = [0_int64, 1_int64, 0_int64, 1_int64]
    rhs = view_descriptor_i64(source, [4_int64], [-1_int64], 4_int64, status)
    call assign(source, rhs, status)
    call require(status%is_ok(), 'overlap assign status')
    call require(all(int(source%data,int64) == [1_int64,0_int64,1_int64,0_int64]), 'overlap staged')
    mask%data = 1_int8
    call mask_assign(source, mask, rhs, status)
    call require(status%is_ok(), 'overlap masked status')
    call require(all(int(source%data,int64) == [0_int64,1_int64,0_int64,1_int64]), 'masked staged')
    call assign(source, source, status)
    call require(status%is_ok(), 'identical descriptor supported')
    invalid = owned_descriptor_i64([2_int64], status=status)
    call mask_assign(source, mask, invalid, status)
    call require(status%code == 1, 'shape error')
    call require(all(int(source%data,int64) == [0_int64,1_int64,0_int64,1_int64]), 'failure atomic')
    invalid%offset = 3_int64
    call assign(source, invalid, status)
    call require(status%is_failure(), 'invalid storage rejected')
    repeated = view_descriptor_i64(source, [4_int64], [0_int64], 1_int64, status)
    call mask_assign(repeated, mask, rhs, status)
    call require(status%is_ok(), 'repeated target status')
    call require(int(source%data(1),int64) == 0_int64, 'last selected write wins')
    repeated = view_descriptor_i64(source, [shiftr(huge(1_int64), 3) + 1_int64], &
      [0_int64], 1_int64, status)
    invalid = owned_descriptor_i64([1_int64], status=status)
    invalid%data = 9_int64
    call assign(repeated, invalid, status)
    call require(status%is_ok(), 'huge zero-stride scalar fill without staging')
    call require(int(source%data(1),int64) == 9_int64, 'huge constant fill writes once')
    call assign(repeated, repeated, status)
    call require(status%code == 4, 'nonscalar staging byte overflow still rejected')
    call require(int(source%data(1),int64) == 9_int64, 'overflow preserves target')
    mask_view = view_descriptor_bool(mask, [4_int64], [-1_int64], 4_int64, status)
    result = mask_select(source, mask_view, status)
    call require(status%is_ok(), 'reversed mask')
    call require(size(result%data) == 4, 'mask count')
  end subroutine test_i64

  subroutine test_r32()
    type(ndarray_r32) :: source, rhs, result, repeated, invalid
    type(ndarray_bool) :: mask, mask_view
    type(frumpy_status) :: status

    source = owned_descriptor_r32([4_int64], status=status)
    source%data = [0.0_real32, 1.0_real32, 0.0_real32, 1.0_real32]
    mask = owned_descriptor_bool([4_int64], status=status)
    mask%data = [1_int8, 0_int8, -7_int8, 1_int8]
    result = mask_select(source, mask, status)
    call require(status%is_ok(), 'extract status')
    call require(all(int(result%data, int64) == [0_int64, 0_int64, 1_int64]), 'extract values')
    call source%release()
    call require(all(int(result%data, int64) == [0_int64, 0_int64, 1_int64]), 'extract lifetime')
    source = owned_descriptor_r32([4_int64], status=status)
    source%data = [0.0_real32, 1.0_real32, 0.0_real32, 1.0_real32]
    rhs = view_descriptor_r32(source, [4_int64], [-1_int64], 4_int64, status)
    call assign(source, rhs, status)
    call require(status%is_ok(), 'overlap assign status')
    call require(all(int(source%data,int64) == [1_int64,0_int64,1_int64,0_int64]), 'overlap staged')
    mask%data = 1_int8
    call mask_assign(source, mask, rhs, status)
    call require(status%is_ok(), 'overlap masked status')
    call require(all(int(source%data,int64) == [0_int64,1_int64,0_int64,1_int64]), 'masked staged')
    call assign(source, source, status)
    call require(status%is_ok(), 'identical descriptor supported')
    invalid = owned_descriptor_r32([2_int64], status=status)
    call mask_assign(source, mask, invalid, status)
    call require(status%code == 1, 'shape error')
    call require(all(int(source%data,int64) == [0_int64,1_int64,0_int64,1_int64]), 'failure atomic')
    invalid%offset = 3_int64
    call assign(source, invalid, status)
    call require(status%is_failure(), 'invalid storage rejected')
    repeated = view_descriptor_r32(source, [4_int64], [0_int64], 1_int64, status)
    call mask_assign(repeated, mask, rhs, status)
    call require(status%is_ok(), 'repeated target status')
    call require(int(source%data(1),int64) == 0_int64, 'last selected write wins')
    mask_view = view_descriptor_bool(mask, [4_int64], [-1_int64], 4_int64, status)
    result = mask_select(source, mask_view, status)
    call require(status%is_ok(), 'reversed mask')
    call require(size(result%data) == 4, 'mask count')
  end subroutine test_r32

  subroutine test_r64()
    type(ndarray_r64) :: source, rhs, result, repeated, invalid
    type(ndarray_bool) :: mask, mask_view
    type(frumpy_status) :: status

    source = owned_descriptor_r64([4_int64], status=status)
    source%data = [0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64]
    mask = owned_descriptor_bool([4_int64], status=status)
    mask%data = [1_int8, 0_int8, -7_int8, 1_int8]
    result = mask_select(source, mask, status)
    call require(status%is_ok(), 'extract status')
    call require(all(int(result%data, int64) == [0_int64, 0_int64, 1_int64]), 'extract values')
    call source%release()
    call require(all(int(result%data, int64) == [0_int64, 0_int64, 1_int64]), 'extract lifetime')
    source = owned_descriptor_r64([4_int64], status=status)
    source%data = [0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64]
    rhs = view_descriptor_r64(source, [4_int64], [-1_int64], 4_int64, status)
    call assign(source, rhs, status)
    call require(status%is_ok(), 'overlap assign status')
    call require(all(int(source%data,int64) == [1_int64,0_int64,1_int64,0_int64]), 'overlap staged')
    mask%data = 1_int8
    call mask_assign(source, mask, rhs, status)
    call require(status%is_ok(), 'overlap masked status')
    call require(all(int(source%data,int64) == [0_int64,1_int64,0_int64,1_int64]), 'masked staged')
    call assign(source, source, status)
    call require(status%is_ok(), 'identical descriptor supported')
    invalid = owned_descriptor_r64([2_int64], status=status)
    call mask_assign(source, mask, invalid, status)
    call require(status%code == 1, 'shape error')
    call require(all(int(source%data,int64) == [0_int64,1_int64,0_int64,1_int64]), 'failure atomic')
    invalid%offset = 3_int64
    call assign(source, invalid, status)
    call require(status%is_failure(), 'invalid storage rejected')
    repeated = view_descriptor_r64(source, [4_int64], [0_int64], 1_int64, status)
    call mask_assign(repeated, mask, rhs, status)
    call require(status%is_ok(), 'repeated target status')
    call require(int(source%data(1),int64) == 0_int64, 'last selected write wins')
    mask_view = view_descriptor_bool(mask, [4_int64], [-1_int64], 4_int64, status)
    result = mask_select(source, mask_view, status)
    call require(status%is_ok(), 'reversed mask')
    call require(size(result%data) == 4, 'mask count')
  end subroutine test_r64

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_indexing_dtypes
