!> Coordinate order, descriptor-container ownership and failure atomicity.
program test_coordinates
  use iso_fortran_env, only: int8,int32,int64,real32,real64
  use frumpy, only: argwhere, nonzero, release_nonzero, frumpy_status
  use frumpy_ndarray_bool, only: ndarray_bool, owned_descriptor_bool
  use frumpy_ndarray_i32, only: ndarray_i32, owned_descriptor_i32
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64
  use frumpy_ndarray_r32, only: ndarray_r32, owned_descriptor_r32
  use frumpy_ndarray_r64, only: ndarray_r64, owned_descriptor_r64
  implicit none
  call test_bool()
  call test_i32()
  call test_i64()
  call test_r32()
  call test_r64()
contains
  subroutine test_bool()
    type(ndarray_bool) :: source, invalid
    type(ndarray_i64) :: result, held
    type(ndarray_i64), allocatable :: axes(:)
    type(frumpy_status) :: status

    source=owned_descriptor_bool([2_int64,3_int64])
    source%data=[0_int8,1_int8,0_int8,1_int8,0_int8,1_int8]
    result=argwhere(source,status)
    call require(status%is_ok(), 'argwhere status')
    call require(all(result%shape==[3_int64,2_int64]), 'argwhere shape')
    call require(all(result%data==[0_int64,1_int64,1_int64,0_int64,1_int64,2_int64]), 'C coordinate order')
    call nonzero(source,axes,status)
    call require(status%is_ok() .and. size(axes)==2, 'nonzero tuple')
    call require(all(axes(1)%data(axes(1)%offset:axes(1)%offset+2)==[0_int64,1_int64,1_int64]), 'axis zero')
    call require(all(axes(2)%data(axes(2)%offset:axes(2)%offset+2)==[1_int64,0_int64,2_int64]), 'axis one')
    invalid=owned_descriptor_bool([1_int64])
    invalid%offset=2_int64
    call nonzero(invalid,axes,status)
    call require(status%is_failure() .and. size(axes)==2, 'failure preserves old tuple')
    call held%share_from(axes(2),status)
    call source%release()
    call release_nonzero(axes)
    call require(.not. allocated(axes), 'explicit tuple release')
    call require(all(held%data(held%offset:held%offset+2)==[1_int64,0_int64,2_int64]), 'retained axis lifetime')
    source=owned_descriptor_bool([2_int64,0_int64,3_int64])
    call nonzero(source,axes,status)
    call require(status%is_ok() .and. size(axes)==3, 'empty tuple rank')
    call require(axes(1)%size()==0 .and. axes(3)%size()==0, 'empty axes')
    source=owned_descriptor_bool([integer(int64)::])
    source%data=1_int8
    result=argwhere(source,status)
    call require(status%is_ok() .and. all(result%shape==[1_int64,0_int64]), 'true scalar argwhere')
    call nonzero(source,axes,status)
    call require(status%code==1 .and. size(axes)==3, 'scalar nonzero failure preserves tuple')
    source%data=0_int8
    result=argwhere(source,status)
    call require(status%is_ok() .and. all(result%shape==[0_int64,0_int64]), 'false scalar argwhere')
    call release_nonzero(axes)
    call release_nonzero(axes)
  end subroutine test_bool

  subroutine test_i32()
    type(ndarray_i32) :: source, invalid
    type(ndarray_i64) :: result, held
    type(ndarray_i64), allocatable :: axes(:)
    type(frumpy_status) :: status

    source=owned_descriptor_i32([2_int64,3_int64])
    source%data=[0_int32,1_int32,0_int32,1_int32,0_int32,1_int32]
    result=argwhere(source,status)
    call require(status%is_ok(), 'argwhere status')
    call require(all(result%shape==[3_int64,2_int64]), 'argwhere shape')
    call require(all(result%data==[0_int64,1_int64,1_int64,0_int64,1_int64,2_int64]), 'C coordinate order')
    call nonzero(source,axes,status)
    call require(status%is_ok() .and. size(axes)==2, 'nonzero tuple')
    call require(all(axes(1)%data(axes(1)%offset:axes(1)%offset+2)==[0_int64,1_int64,1_int64]), 'axis zero')
    call require(all(axes(2)%data(axes(2)%offset:axes(2)%offset+2)==[1_int64,0_int64,2_int64]), 'axis one')
    invalid=owned_descriptor_i32([1_int64])
    invalid%offset=2_int64
    call nonzero(invalid,axes,status)
    call require(status%is_failure() .and. size(axes)==2, 'failure preserves old tuple')
    call held%share_from(axes(2),status)
    call source%release()
    call release_nonzero(axes)
    call require(.not. allocated(axes), 'explicit tuple release')
    call require(all(held%data(held%offset:held%offset+2)==[1_int64,0_int64,2_int64]), 'retained axis lifetime')
    source=owned_descriptor_i32([2_int64,0_int64,3_int64])
    call nonzero(source,axes,status)
    call require(status%is_ok() .and. size(axes)==3, 'empty tuple rank')
    call require(axes(1)%size()==0 .and. axes(3)%size()==0, 'empty axes')
    source=owned_descriptor_i32([integer(int64)::])
    source%data=1_int32
    result=argwhere(source,status)
    call require(status%is_ok() .and. all(result%shape==[1_int64,0_int64]), 'true scalar argwhere')
    call nonzero(source,axes,status)
    call require(status%code==1 .and. size(axes)==3, 'scalar nonzero failure preserves tuple')
    source%data=0_int32
    result=argwhere(source,status)
    call require(status%is_ok() .and. all(result%shape==[0_int64,0_int64]), 'false scalar argwhere')
    call release_nonzero(axes)
    call release_nonzero(axes)
  end subroutine test_i32

  subroutine test_i64()
    type(ndarray_i64) :: source, invalid
    type(ndarray_i64) :: result, held
    type(ndarray_i64), allocatable :: axes(:)
    type(frumpy_status) :: status

    source=owned_descriptor_i64([2_int64,3_int64])
    source%data=[0_int64,1_int64,0_int64,1_int64,0_int64,1_int64]
    result=argwhere(source,status)
    call require(status%is_ok(), 'argwhere status')
    call require(all(result%shape==[3_int64,2_int64]), 'argwhere shape')
    call require(all(result%data==[0_int64,1_int64,1_int64,0_int64,1_int64,2_int64]), 'C coordinate order')
    call nonzero(source,axes,status)
    call require(status%is_ok() .and. size(axes)==2, 'nonzero tuple')
    call require(all(axes(1)%data(axes(1)%offset:axes(1)%offset+2)==[0_int64,1_int64,1_int64]), 'axis zero')
    call require(all(axes(2)%data(axes(2)%offset:axes(2)%offset+2)==[1_int64,0_int64,2_int64]), 'axis one')
    invalid=owned_descriptor_i64([1_int64])
    invalid%offset=2_int64
    call nonzero(invalid,axes,status)
    call require(status%is_failure() .and. size(axes)==2, 'failure preserves old tuple')
    call held%share_from(axes(2),status)
    call source%release()
    call release_nonzero(axes)
    call require(.not. allocated(axes), 'explicit tuple release')
    call require(all(held%data(held%offset:held%offset+2)==[1_int64,0_int64,2_int64]), 'retained axis lifetime')
    source=owned_descriptor_i64([2_int64,0_int64,3_int64])
    call nonzero(source,axes,status)
    call require(status%is_ok() .and. size(axes)==3, 'empty tuple rank')
    call require(axes(1)%size()==0 .and. axes(3)%size()==0, 'empty axes')
    source=owned_descriptor_i64([integer(int64)::])
    source%data=1_int64
    result=argwhere(source,status)
    call require(status%is_ok() .and. all(result%shape==[1_int64,0_int64]), 'true scalar argwhere')
    call nonzero(source,axes,status)
    call require(status%code==1 .and. size(axes)==3, 'scalar nonzero failure preserves tuple')
    source%data=0_int64
    result=argwhere(source,status)
    call require(status%is_ok() .and. all(result%shape==[0_int64,0_int64]), 'false scalar argwhere')
    call release_nonzero(axes)
    call release_nonzero(axes)
  end subroutine test_i64

  subroutine test_r32()
    type(ndarray_r32) :: source, invalid
    type(ndarray_i64) :: result, held
    type(ndarray_i64), allocatable :: axes(:)
    type(frumpy_status) :: status

    source=owned_descriptor_r32([2_int64,3_int64])
    source%data=[0.0_real32,1.0_real32,0.0_real32,1.0_real32,0.0_real32,1.0_real32]
    result=argwhere(source,status)
    call require(status%is_ok(), 'argwhere status')
    call require(all(result%shape==[3_int64,2_int64]), 'argwhere shape')
    call require(all(result%data==[0_int64,1_int64,1_int64,0_int64,1_int64,2_int64]), 'C coordinate order')
    call nonzero(source,axes,status)
    call require(status%is_ok() .and. size(axes)==2, 'nonzero tuple')
    call require(all(axes(1)%data(axes(1)%offset:axes(1)%offset+2)==[0_int64,1_int64,1_int64]), 'axis zero')
    call require(all(axes(2)%data(axes(2)%offset:axes(2)%offset+2)==[1_int64,0_int64,2_int64]), 'axis one')
    invalid=owned_descriptor_r32([1_int64])
    invalid%offset=2_int64
    call nonzero(invalid,axes,status)
    call require(status%is_failure() .and. size(axes)==2, 'failure preserves old tuple')
    call held%share_from(axes(2),status)
    call source%release()
    call release_nonzero(axes)
    call require(.not. allocated(axes), 'explicit tuple release')
    call require(all(held%data(held%offset:held%offset+2)==[1_int64,0_int64,2_int64]), 'retained axis lifetime')
    source=owned_descriptor_r32([2_int64,0_int64,3_int64])
    call nonzero(source,axes,status)
    call require(status%is_ok() .and. size(axes)==3, 'empty tuple rank')
    call require(axes(1)%size()==0 .and. axes(3)%size()==0, 'empty axes')
    source=owned_descriptor_r32([integer(int64)::])
    source%data=1.0_real32
    result=argwhere(source,status)
    call require(status%is_ok() .and. all(result%shape==[1_int64,0_int64]), 'true scalar argwhere')
    call nonzero(source,axes,status)
    call require(status%code==1 .and. size(axes)==3, 'scalar nonzero failure preserves tuple')
    source%data=0.0_real32
    result=argwhere(source,status)
    call require(status%is_ok() .and. all(result%shape==[0_int64,0_int64]), 'false scalar argwhere')
    call release_nonzero(axes)
    call release_nonzero(axes)
  end subroutine test_r32

  subroutine test_r64()
    type(ndarray_r64) :: source, invalid
    type(ndarray_i64) :: result, held
    type(ndarray_i64), allocatable :: axes(:)
    type(frumpy_status) :: status

    source=owned_descriptor_r64([2_int64,3_int64])
    source%data=[0.0_real64,1.0_real64,0.0_real64,1.0_real64,0.0_real64,1.0_real64]
    result=argwhere(source,status)
    call require(status%is_ok(), 'argwhere status')
    call require(all(result%shape==[3_int64,2_int64]), 'argwhere shape')
    call require(all(result%data==[0_int64,1_int64,1_int64,0_int64,1_int64,2_int64]), 'C coordinate order')
    call nonzero(source,axes,status)
    call require(status%is_ok() .and. size(axes)==2, 'nonzero tuple')
    call require(all(axes(1)%data(axes(1)%offset:axes(1)%offset+2)==[0_int64,1_int64,1_int64]), 'axis zero')
    call require(all(axes(2)%data(axes(2)%offset:axes(2)%offset+2)==[1_int64,0_int64,2_int64]), 'axis one')
    invalid=owned_descriptor_r64([1_int64])
    invalid%offset=2_int64
    call nonzero(invalid,axes,status)
    call require(status%is_failure() .and. size(axes)==2, 'failure preserves old tuple')
    call held%share_from(axes(2),status)
    call source%release()
    call release_nonzero(axes)
    call require(.not. allocated(axes), 'explicit tuple release')
    call require(all(held%data(held%offset:held%offset+2)==[1_int64,0_int64,2_int64]), 'retained axis lifetime')
    source=owned_descriptor_r64([2_int64,0_int64,3_int64])
    call nonzero(source,axes,status)
    call require(status%is_ok() .and. size(axes)==3, 'empty tuple rank')
    call require(axes(1)%size()==0 .and. axes(3)%size()==0, 'empty axes')
    source=owned_descriptor_r64([integer(int64)::])
    source%data=1.0_real64
    result=argwhere(source,status)
    call require(status%is_ok() .and. all(result%shape==[1_int64,0_int64]), 'true scalar argwhere')
    call nonzero(source,axes,status)
    call require(status%code==1 .and. size(axes)==3, 'scalar nonzero failure preserves tuple')
    source%data=0.0_real64
    result=argwhere(source,status)
    call require(status%is_ok() .and. all(result%shape==[0_int64,0_int64]), 'false scalar argwhere')
    call release_nonzero(axes)
    call release_nonzero(axes)
  end subroutine test_r64

  subroutine require(condition,message)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: message
    if (.not. condition) then
      print *,message
      error stop 1
    end if
  end subroutine require
end program test_coordinates
