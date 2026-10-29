program benchmark_arg_reductions
  use iso_fortran_env, only: int8, int32, int64, real32, real64
  use frumpy, only: ndarray_bool, ndarray_i32, ndarray_i64, ndarray_r32, ndarray_r64, &
    owned_descriptor_bool, owned_descriptor_i32, owned_descriptor_i64, &
    owned_descriptor_r32, owned_descriptor_r64, view_descriptor_bool, view_descriptor_i32, &
    view_descriptor_i64, view_descriptor_r32, view_descriptor_r64, argmin, argmax, frumpy_status
  implicit none
  integer :: k, layout, operation
  integer, parameter :: sizes(2)=[16,65536]
  do operation=8,9
    do k=1,2
      do layout=1,4
        call bench_bool(sizes(k),layout,operation)
        call bench_i32(sizes(k),layout,operation)
        call bench_i64(sizes(k),layout,operation)
        call bench_r32(sizes(k),layout,operation)
        call bench_r64(sizes(k),layout,operation)
      end do
    end do
  end do
contains
  subroutine bench_bool(n,layout,operation)
    integer, intent(in) :: n,layout,operation
    type(ndarray_bool) :: owner,a
    type(ndarray_i64) :: result
    type(frumpy_status) :: status
    integer(int64) :: i,step,offset,expected
    integer :: sample1,j,repeats,side
    real(real64) :: start,finish

    step=1_int64
    if (layout==2) step=2_int64
    owner=owned_descriptor_bool([int(n,int64)*step])
    side=int(sqrt(real(n,real64)))
    do i=1_int64,size(owner%data,kind=int64)
      if (layout==4) then
        owner%data(1_int64+(i-1_int64)/side+modulo(i-1_int64,int(side,int64))*side) = &
          int(modulo(i,2_int64),int8)
      else
        owner%data(i)=int(modulo(i,2_int64),int8)
      end if
    end do
    offset=1_int64
    if (layout==3) then
      step=-1_int64
      offset=int(n,int64)
    end if
    a=view_descriptor_bool(owner,[int(n,int64)],[step],offset)
    if (layout==4) a=view_descriptor_bool(owner,[int(side,int64),int(side,int64)], &
      [1_int64,int(side,int64)],1_int64)
    if (operation==8) then
      expected=int(minloc(owner%data(offset:offset+(n-1)*step:step),dim=1),int64)-1_int64
    else
      expected=int(maxloc(owner%data(offset:offset+(n-1)*step:step),dim=1),int64)-1_int64
    end if
    if (layout==4) then
      if (operation==8) then
        expected=int(minloc(owner%data([(1+j/side+modulo(j,side)*side,j=0,n-1)]),dim=1),int64)-1
      else
        expected=int(maxloc(owner%data([(1+j/side+modulo(j,side)*side,j=0,n-1)]),dim=1),int64)-1
      end if
    end if
    repeats=100
    if (n==16) repeats=10000
    do sample1=1,7
      call cpu_time(start)
      do j=1,repeats
        if (operation==8) then
          result=argmin(a,status=status)
        else
          result=argmax(a,status=status)
        end if
        if (status%is_failure()) error stop 'arg status'
        if (result%data(1)/=expected) error stop 'arg value'
        call result%release()
      end do
      call cpu_time(finish)
      write(*,'(5(i0,1x),es24.16)') 1,operation,n,layout,sample1,(finish-start)/repeats
    end do
  end subroutine bench_bool
  subroutine bench_i32(n,layout,operation)
    integer, intent(in) :: n,layout,operation
    type(ndarray_i32) :: owner,a
    type(ndarray_i64) :: result
    type(frumpy_status) :: status
    integer(int64) :: i,step,offset,expected
    integer :: sample1,j,repeats,side
    real(real64) :: start,finish

    step=1_int64
    if (layout==2) step=2_int64
    owner=owned_descriptor_i32([int(n,int64)*step])
    side=int(sqrt(real(n,real64)))
    do i=1_int64,size(owner%data,kind=int64)
      if (layout==4) then
        owner%data(1_int64+(i-1_int64)/side+modulo(i-1_int64,int(side,int64))*side) = &
          int(modulo(i*37_int64,257_int64)-128_int64,int32)
      else
        owner%data(i)=int(modulo(i*37_int64,257_int64)-128_int64,int32)
      end if
    end do
    offset=1_int64
    if (layout==3) then
      step=-1_int64
      offset=int(n,int64)
    end if
    a=view_descriptor_i32(owner,[int(n,int64)],[step],offset)
    if (layout==4) a=view_descriptor_i32(owner,[int(side,int64),int(side,int64)], &
      [1_int64,int(side,int64)],1_int64)
    if (operation==8) then
      expected=int(minloc(owner%data(offset:offset+(n-1)*step:step),dim=1),int64)-1_int64
    else
      expected=int(maxloc(owner%data(offset:offset+(n-1)*step:step),dim=1),int64)-1_int64
    end if
    if (layout==4) then
      if (operation==8) then
        expected=int(minloc(owner%data([(1+j/side+modulo(j,side)*side,j=0,n-1)]),dim=1),int64)-1
      else
        expected=int(maxloc(owner%data([(1+j/side+modulo(j,side)*side,j=0,n-1)]),dim=1),int64)-1
      end if
    end if
    repeats=100
    if (n==16) repeats=10000
    do sample1=1,7
      call cpu_time(start)
      do j=1,repeats
        if (operation==8) then
          result=argmin(a,status=status)
        else
          result=argmax(a,status=status)
        end if
        if (status%is_failure()) error stop 'arg status'
        if (result%data(1)/=expected) error stop 'arg value'
        call result%release()
      end do
      call cpu_time(finish)
      write(*,'(5(i0,1x),es24.16)') 2,operation,n,layout,sample1,(finish-start)/repeats
    end do
  end subroutine bench_i32
  subroutine bench_i64(n,layout,operation)
    integer, intent(in) :: n,layout,operation
    type(ndarray_i64) :: owner,a
    type(ndarray_i64) :: result
    type(frumpy_status) :: status
    integer(int64) :: i,step,offset,expected
    integer :: sample1,j,repeats,side
    real(real64) :: start,finish

    step=1_int64
    if (layout==2) step=2_int64
    owner=owned_descriptor_i64([int(n,int64)*step])
    side=int(sqrt(real(n,real64)))
    do i=1_int64,size(owner%data,kind=int64)
      if (layout==4) then
        owner%data(1_int64+(i-1_int64)/side+modulo(i-1_int64,int(side,int64))*side) = &
          int(modulo(i*37_int64,257_int64)-128_int64,int64)
      else
        owner%data(i)=int(modulo(i*37_int64,257_int64)-128_int64,int64)
      end if
    end do
    offset=1_int64
    if (layout==3) then
      step=-1_int64
      offset=int(n,int64)
    end if
    a=view_descriptor_i64(owner,[int(n,int64)],[step],offset)
    if (layout==4) a=view_descriptor_i64(owner,[int(side,int64),int(side,int64)], &
      [1_int64,int(side,int64)],1_int64)
    if (operation==8) then
      expected=int(minloc(owner%data(offset:offset+(n-1)*step:step),dim=1),int64)-1_int64
    else
      expected=int(maxloc(owner%data(offset:offset+(n-1)*step:step),dim=1),int64)-1_int64
    end if
    if (layout==4) then
      if (operation==8) then
        expected=int(minloc(owner%data([(1+j/side+modulo(j,side)*side,j=0,n-1)]),dim=1),int64)-1
      else
        expected=int(maxloc(owner%data([(1+j/side+modulo(j,side)*side,j=0,n-1)]),dim=1),int64)-1
      end if
    end if
    repeats=100
    if (n==16) repeats=10000
    do sample1=1,7
      call cpu_time(start)
      do j=1,repeats
        if (operation==8) then
          result=argmin(a,status=status)
        else
          result=argmax(a,status=status)
        end if
        if (status%is_failure()) error stop 'arg status'
        if (result%data(1)/=expected) error stop 'arg value'
        call result%release()
      end do
      call cpu_time(finish)
      write(*,'(5(i0,1x),es24.16)') 3,operation,n,layout,sample1,(finish-start)/repeats
    end do
  end subroutine bench_i64
  subroutine bench_r32(n,layout,operation)
    integer, intent(in) :: n,layout,operation
    type(ndarray_r32) :: owner,a
    type(ndarray_i64) :: result
    type(frumpy_status) :: status
    integer(int64) :: i,step,offset,expected
    integer :: sample1,j,repeats,side
    real(real64) :: start,finish

    step=1_int64
    if (layout==2) step=2_int64
    owner=owned_descriptor_r32([int(n,int64)*step])
    side=int(sqrt(real(n,real64)))
    do i=1_int64,size(owner%data,kind=int64)
      if (layout==4) then
        owner%data(1_int64+(i-1_int64)/side+modulo(i-1_int64,int(side,int64))*side) = &
          real(modulo(i*37_int64,257_int64)-128_int64,real32)
      else
        owner%data(i)=real(modulo(i*37_int64,257_int64)-128_int64,real32)
      end if
    end do
    offset=1_int64
    if (layout==3) then
      step=-1_int64
      offset=int(n,int64)
    end if
    a=view_descriptor_r32(owner,[int(n,int64)],[step],offset)
    if (layout==4) a=view_descriptor_r32(owner,[int(side,int64),int(side,int64)], &
      [1_int64,int(side,int64)],1_int64)
    if (operation==8) then
      expected=int(minloc(owner%data(offset:offset+(n-1)*step:step),dim=1),int64)-1_int64
    else
      expected=int(maxloc(owner%data(offset:offset+(n-1)*step:step),dim=1),int64)-1_int64
    end if
    if (layout==4) then
      if (operation==8) then
        expected=int(minloc(owner%data([(1+j/side+modulo(j,side)*side,j=0,n-1)]),dim=1),int64)-1
      else
        expected=int(maxloc(owner%data([(1+j/side+modulo(j,side)*side,j=0,n-1)]),dim=1),int64)-1
      end if
    end if
    repeats=100
    if (n==16) repeats=10000
    do sample1=1,7
      call cpu_time(start)
      do j=1,repeats
        if (operation==8) then
          result=argmin(a,status=status)
        else
          result=argmax(a,status=status)
        end if
        if (status%is_failure()) error stop 'arg status'
        if (result%data(1)/=expected) error stop 'arg value'
        call result%release()
      end do
      call cpu_time(finish)
      write(*,'(5(i0,1x),es24.16)') 4,operation,n,layout,sample1,(finish-start)/repeats
    end do
  end subroutine bench_r32
  subroutine bench_r64(n,layout,operation)
    integer, intent(in) :: n,layout,operation
    type(ndarray_r64) :: owner,a
    type(ndarray_i64) :: result
    type(frumpy_status) :: status
    integer(int64) :: i,step,offset,expected
    integer :: sample1,j,repeats,side
    real(real64) :: start,finish

    step=1_int64
    if (layout==2) step=2_int64
    owner=owned_descriptor_r64([int(n,int64)*step])
    side=int(sqrt(real(n,real64)))
    do i=1_int64,size(owner%data,kind=int64)
      if (layout==4) then
        owner%data(1_int64+(i-1_int64)/side+modulo(i-1_int64,int(side,int64))*side) = &
          real(modulo(i*37_int64,257_int64)-128_int64,real64)
      else
        owner%data(i)=real(modulo(i*37_int64,257_int64)-128_int64,real64)
      end if
    end do
    offset=1_int64
    if (layout==3) then
      step=-1_int64
      offset=int(n,int64)
    end if
    a=view_descriptor_r64(owner,[int(n,int64)],[step],offset)
    if (layout==4) a=view_descriptor_r64(owner,[int(side,int64),int(side,int64)], &
      [1_int64,int(side,int64)],1_int64)
    if (operation==8) then
      expected=int(minloc(owner%data(offset:offset+(n-1)*step:step),dim=1),int64)-1_int64
    else
      expected=int(maxloc(owner%data(offset:offset+(n-1)*step:step),dim=1),int64)-1_int64
    end if
    if (layout==4) then
      if (operation==8) then
        expected=int(minloc(owner%data([(1+j/side+modulo(j,side)*side,j=0,n-1)]),dim=1),int64)-1
      else
        expected=int(maxloc(owner%data([(1+j/side+modulo(j,side)*side,j=0,n-1)]),dim=1),int64)-1
      end if
    end if
    repeats=100
    if (n==16) repeats=10000
    do sample1=1,7
      call cpu_time(start)
      do j=1,repeats
        if (operation==8) then
          result=argmin(a,status=status)
        else
          result=argmax(a,status=status)
        end if
        if (status%is_failure()) error stop 'arg status'
        if (result%data(1)/=expected) error stop 'arg value'
        call result%release()
      end do
      call cpu_time(finish)
      write(*,'(5(i0,1x),es24.16)') 5,operation,n,layout,sample1,(finish-start)/repeats
    end do
  end subroutine bench_r64
end program benchmark_arg_reductions
