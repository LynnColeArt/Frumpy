program benchmark_arg_bool
  use iso_fortran_env, only: int8, int64, real64
  use frumpy, only: ndarray_bool, ndarray_i64, owned_descriptor_bool, view_descriptor_bool, &
    argmin, argmax, frumpy_status
  implicit none
  integer :: operation,layout,distribution
  do operation=8,9
    do layout=1,4
      do distribution=0,3
        call bench(operation,layout,distribution)
      end do
    end do
  end do
contains
  subroutine bench(operation,layout,distribution)
    integer, intent(in) :: operation,layout,distribution
    type(ndarray_bool) :: owner,a
    type(ndarray_i64) :: result
    type(frumpy_status) :: status
    integer(int64) :: step,offset,expected,position
    integer :: sample1,j
    real(real64) :: start,finish

    step=1_int64
    if (layout==2) step=2_int64
    owner=owned_descriptor_bool([65536_int64*step])
    owner%data=int(9-operation,int8)
    offset=1_int64
    if (layout==3) then
      step=-1_int64
      offset=65536_int64
    end if
    a=view_descriptor_bool(owner,[65536_int64],[step],offset)
    if (layout==4) a=view_descriptor_bool(owner,[256_int64,256_int64], &
      [1_int64,256_int64],1_int64)
    expected=0_int64
    if (distribution==1) expected=32768_int64
    if (distribution==2) expected=65535_int64
    if (distribution/=3) then
      position=offset+expected*step
      if (layout==4) position=1_int64+expected/256_int64+modulo(expected,256_int64)*256_int64
      owner%data(position)=int(operation-8,int8)
    end if
    do sample1=1,7
      call cpu_time(start)
      do j=1,1000
        if (operation==8) then
          result=argmin(a,status=status)
        else
          result=argmax(a,status=status)
        end if
        if (status%is_failure()) error stop 'bool arg status'
        if (result%data(1)/=expected) error stop 'bool arg index'
        call result%release()
      end do
      call cpu_time(finish)
      write(*,'(4(i0,1x),es24.16)') operation,layout,distribution,sample1,(finish-start)/1000
    end do
  end subroutine bench
end program benchmark_arg_bool
