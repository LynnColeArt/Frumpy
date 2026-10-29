program benchmark_sort_dtypes
  use iso_fortran_env, only: int8, int32, int64, real32, real64
  use frumpy, only: ndarray_bool, ndarray_i32, ndarray_i64, ndarray_r32, ndarray_r64, &
    owned_descriptor_bool, owned_descriptor_i32, owned_descriptor_i64, &
    owned_descriptor_r32, owned_descriptor_r64, view_descriptor_bool, view_descriptor_i32, &
    view_descriptor_i64, view_descriptor_r32, view_descriptor_r64, sort, argsort, frumpy_status
  implicit none
  integer :: case1,operation
  do operation=0,1
    do case1=1,8
      call bench_bool(operation,case1)
      call bench_i32(operation,case1)
      call bench_i64(operation,case1)
      call bench_r32(operation,case1)
      call bench_r64(operation,case1)
    end do
  end do
contains
  subroutine bench_bool(operation,case1)
    integer, intent(in) :: operation,case1
    type(ndarray_bool) :: owner,a,values
    type(ndarray_i64) :: indices
    type(frumpy_status) :: status
    integer(int64) :: n,step,i,j,key,position
    integer(int64), allocatable :: expected(:)
    integer(int8), allocatable :: logical_values(:)
    integer :: sample1,repeat1,repeats
    real(real64) :: start,finish

    n=8192_int64
    if (case1==1) n=32_int64
    step=1_int64
    if (case1==6) step=2_int64
    owner=owned_descriptor_bool([n*step])
    do i=0_int64,n*step-1_int64
      key=modulo(i*37_int64,257_int64)-128_int64
      if (case1==5 .or. case1==8) key=modulo(i,5_int64)-2_int64
      key=modulo(i,2_int64)
      position=i+1_int64
      if (case1==7) position=1_int64+i/128_int64+modulo(i,128_int64)*64_int64
      owner%data(position)=int(key,int8)
    end do
    if (case1==3 .or. case1==4) then
      do i=2_int64,n
        key=int(owner%data(i),int64)
        j=i-1_int64
        do while (j>=1_int64)
          if (owner%data(j)<=int(key,int8)) exit
          owner%data(j+1_int64)=owner%data(j)
          j=j-1_int64
        end do
        owner%data(j+1_int64)=int(key,int8)
      end do
      if (case1==4) owner%data=owner%data(n:1:-1)
    end if
    a=view_descriptor_bool(owner,[n],[step],1_int64)
    if (case1==7) a=view_descriptor_bool(owner,[64_int64,128_int64], &
      [1_int64,64_int64],1_int64)
    if (case1==8) a=view_descriptor_bool(owner,[64_int64,128_int64], &
      [128_int64,-1_int64],128_int64)
    ! Establish a stable expected first slice independently with insertion sort.
    allocate(logical_values(a%shape(a%rank)),expected(a%shape(a%rank)))
    do i=1_int64,size(expected,kind=int64)
      logical_values(i)=owner%data(a%offset+(i-1_int64)*a%strides(a%rank))
      expected(i)=i-1_int64
    end do
    do i=2_int64,size(expected,kind=int64)
      key=expected(i)
      j=i-1_int64
      do while (j>=1_int64)
        if (logical_values(expected(j)+1_int64)<=logical_values(key+1_int64)) exit
        expected(j+1_int64)=expected(j)
        j=j-1_int64
      end do
      expected(j+1_int64)=key
    end do
    repeats=20
    if (n==32_int64) repeats=1000
    do sample1=1,7
      call cpu_time(start)
      do repeat1=1,repeats
        if (operation==0) then
          values=sort(a,status=status)
          if (status%is_failure()) error stop 'sort status'
          if (values%data(1)/=logical_values(expected(1)+1_int64)) error stop 'sort value'
          call values%release()
        else
          indices=argsort(a,status=status)
          if (status%is_failure()) error stop 'argsort status'
          if (indices%data(1)/=expected(1)) error stop 'argsort index'
          call indices%release()
        end if
      end do
      call cpu_time(finish)
      write(*,'(4(i0,1x),es24.16)') 1,operation,case1,sample1,(finish-start)/repeats
    end do
  end subroutine bench_bool
  subroutine bench_i32(operation,case1)
    integer, intent(in) :: operation,case1
    type(ndarray_i32) :: owner,a,values
    type(ndarray_i64) :: indices
    type(frumpy_status) :: status
    integer(int64) :: n,step,i,j,key,position
    integer(int64), allocatable :: expected(:)
    integer(int32), allocatable :: logical_values(:)
    integer :: sample1,repeat1,repeats
    real(real64) :: start,finish

    n=8192_int64
    if (case1==1) n=32_int64
    step=1_int64
    if (case1==6) step=2_int64
    owner=owned_descriptor_i32([n*step])
    do i=0_int64,n*step-1_int64
      key=modulo(i*37_int64,257_int64)-128_int64
      if (case1==5 .or. case1==8) key=modulo(i,5_int64)-2_int64
      position=i+1_int64
      if (case1==7) position=1_int64+i/128_int64+modulo(i,128_int64)*64_int64
      owner%data(position)=int(key,int32)
    end do
    if (case1==3 .or. case1==4) then
      do i=2_int64,n
        key=int(owner%data(i),int64)
        j=i-1_int64
        do while (j>=1_int64)
          if (owner%data(j)<=int(key,int32)) exit
          owner%data(j+1_int64)=owner%data(j)
          j=j-1_int64
        end do
        owner%data(j+1_int64)=int(key,int32)
      end do
      if (case1==4) owner%data=owner%data(n:1:-1)
    end if
    a=view_descriptor_i32(owner,[n],[step],1_int64)
    if (case1==7) a=view_descriptor_i32(owner,[64_int64,128_int64], &
      [1_int64,64_int64],1_int64)
    if (case1==8) a=view_descriptor_i32(owner,[64_int64,128_int64], &
      [128_int64,-1_int64],128_int64)
    ! Establish a stable expected first slice independently with insertion sort.
    allocate(logical_values(a%shape(a%rank)),expected(a%shape(a%rank)))
    do i=1_int64,size(expected,kind=int64)
      logical_values(i)=owner%data(a%offset+(i-1_int64)*a%strides(a%rank))
      expected(i)=i-1_int64
    end do
    do i=2_int64,size(expected,kind=int64)
      key=expected(i)
      j=i-1_int64
      do while (j>=1_int64)
        if (logical_values(expected(j)+1_int64)<=logical_values(key+1_int64)) exit
        expected(j+1_int64)=expected(j)
        j=j-1_int64
      end do
      expected(j+1_int64)=key
    end do
    repeats=20
    if (n==32_int64) repeats=1000
    do sample1=1,7
      call cpu_time(start)
      do repeat1=1,repeats
        if (operation==0) then
          values=sort(a,status=status)
          if (status%is_failure()) error stop 'sort status'
          if (values%data(1)/=logical_values(expected(1)+1_int64)) error stop 'sort value'
          call values%release()
        else
          indices=argsort(a,status=status)
          if (status%is_failure()) error stop 'argsort status'
          if (indices%data(1)/=expected(1)) error stop 'argsort index'
          call indices%release()
        end if
      end do
      call cpu_time(finish)
      write(*,'(4(i0,1x),es24.16)') 2,operation,case1,sample1,(finish-start)/repeats
    end do
  end subroutine bench_i32
  subroutine bench_i64(operation,case1)
    integer, intent(in) :: operation,case1
    type(ndarray_i64) :: owner,a,values
    type(ndarray_i64) :: indices
    type(frumpy_status) :: status
    integer(int64) :: n,step,i,j,key,position
    integer(int64), allocatable :: expected(:)
    integer(int64), allocatable :: logical_values(:)
    integer :: sample1,repeat1,repeats
    real(real64) :: start,finish

    n=8192_int64
    if (case1==1) n=32_int64
    step=1_int64
    if (case1==6) step=2_int64
    owner=owned_descriptor_i64([n*step])
    do i=0_int64,n*step-1_int64
      key=modulo(i*37_int64,257_int64)-128_int64
      if (case1==5 .or. case1==8) key=modulo(i,5_int64)-2_int64
      position=i+1_int64
      if (case1==7) position=1_int64+i/128_int64+modulo(i,128_int64)*64_int64
      owner%data(position)=int(key,int64)
    end do
    if (case1==3 .or. case1==4) then
      do i=2_int64,n
        key=int(owner%data(i),int64)
        j=i-1_int64
        do while (j>=1_int64)
          if (owner%data(j)<=int(key,int64)) exit
          owner%data(j+1_int64)=owner%data(j)
          j=j-1_int64
        end do
        owner%data(j+1_int64)=int(key,int64)
      end do
      if (case1==4) owner%data=owner%data(n:1:-1)
    end if
    a=view_descriptor_i64(owner,[n],[step],1_int64)
    if (case1==7) a=view_descriptor_i64(owner,[64_int64,128_int64], &
      [1_int64,64_int64],1_int64)
    if (case1==8) a=view_descriptor_i64(owner,[64_int64,128_int64], &
      [128_int64,-1_int64],128_int64)
    ! Establish a stable expected first slice independently with insertion sort.
    allocate(logical_values(a%shape(a%rank)),expected(a%shape(a%rank)))
    do i=1_int64,size(expected,kind=int64)
      logical_values(i)=owner%data(a%offset+(i-1_int64)*a%strides(a%rank))
      expected(i)=i-1_int64
    end do
    do i=2_int64,size(expected,kind=int64)
      key=expected(i)
      j=i-1_int64
      do while (j>=1_int64)
        if (logical_values(expected(j)+1_int64)<=logical_values(key+1_int64)) exit
        expected(j+1_int64)=expected(j)
        j=j-1_int64
      end do
      expected(j+1_int64)=key
    end do
    repeats=20
    if (n==32_int64) repeats=1000
    do sample1=1,7
      call cpu_time(start)
      do repeat1=1,repeats
        if (operation==0) then
          values=sort(a,status=status)
          if (status%is_failure()) error stop 'sort status'
          if (values%data(1)/=logical_values(expected(1)+1_int64)) error stop 'sort value'
          call values%release()
        else
          indices=argsort(a,status=status)
          if (status%is_failure()) error stop 'argsort status'
          if (indices%data(1)/=expected(1)) error stop 'argsort index'
          call indices%release()
        end if
      end do
      call cpu_time(finish)
      write(*,'(4(i0,1x),es24.16)') 3,operation,case1,sample1,(finish-start)/repeats
    end do
  end subroutine bench_i64
  subroutine bench_r32(operation,case1)
    integer, intent(in) :: operation,case1
    type(ndarray_r32) :: owner,a,values
    type(ndarray_i64) :: indices
    type(frumpy_status) :: status
    integer(int64) :: n,step,i,j,key,position
    integer(int64), allocatable :: expected(:)
    real(real32), allocatable :: logical_values(:)
    integer :: sample1,repeat1,repeats
    real(real64) :: start,finish

    n=8192_int64
    if (case1==1) n=32_int64
    step=1_int64
    if (case1==6) step=2_int64
    owner=owned_descriptor_r32([n*step])
    do i=0_int64,n*step-1_int64
      key=modulo(i*37_int64,257_int64)-128_int64
      if (case1==5 .or. case1==8) key=modulo(i,5_int64)-2_int64
      position=i+1_int64
      if (case1==7) position=1_int64+i/128_int64+modulo(i,128_int64)*64_int64
      owner%data(position)=real(key,real32)
    end do
    if (case1==3 .or. case1==4) then
      do i=2_int64,n
        key=int(owner%data(i),int64)
        j=i-1_int64
        do while (j>=1_int64)
          if (owner%data(j)<=real(key,real32)) exit
          owner%data(j+1_int64)=owner%data(j)
          j=j-1_int64
        end do
        owner%data(j+1_int64)=real(key,real32)
      end do
      if (case1==4) owner%data=owner%data(n:1:-1)
    end if
    a=view_descriptor_r32(owner,[n],[step],1_int64)
    if (case1==7) a=view_descriptor_r32(owner,[64_int64,128_int64], &
      [1_int64,64_int64],1_int64)
    if (case1==8) a=view_descriptor_r32(owner,[64_int64,128_int64], &
      [128_int64,-1_int64],128_int64)
    ! Establish a stable expected first slice independently with insertion sort.
    allocate(logical_values(a%shape(a%rank)),expected(a%shape(a%rank)))
    do i=1_int64,size(expected,kind=int64)
      logical_values(i)=owner%data(a%offset+(i-1_int64)*a%strides(a%rank))
      expected(i)=i-1_int64
    end do
    do i=2_int64,size(expected,kind=int64)
      key=expected(i)
      j=i-1_int64
      do while (j>=1_int64)
        if (logical_values(expected(j)+1_int64)<=logical_values(key+1_int64)) exit
        expected(j+1_int64)=expected(j)
        j=j-1_int64
      end do
      expected(j+1_int64)=key
    end do
    repeats=20
    if (n==32_int64) repeats=1000
    do sample1=1,7
      call cpu_time(start)
      do repeat1=1,repeats
        if (operation==0) then
          values=sort(a,status=status)
          if (status%is_failure()) error stop 'sort status'
          if (values%data(1)/=logical_values(expected(1)+1_int64)) error stop 'sort value'
          call values%release()
        else
          indices=argsort(a,status=status)
          if (status%is_failure()) error stop 'argsort status'
          if (indices%data(1)/=expected(1)) error stop 'argsort index'
          call indices%release()
        end if
      end do
      call cpu_time(finish)
      write(*,'(4(i0,1x),es24.16)') 4,operation,case1,sample1,(finish-start)/repeats
    end do
  end subroutine bench_r32
  subroutine bench_r64(operation,case1)
    integer, intent(in) :: operation,case1
    type(ndarray_r64) :: owner,a,values
    type(ndarray_i64) :: indices
    type(frumpy_status) :: status
    integer(int64) :: n,step,i,j,key,position
    integer(int64), allocatable :: expected(:)
    real(real64), allocatable :: logical_values(:)
    integer :: sample1,repeat1,repeats
    real(real64) :: start,finish

    n=8192_int64
    if (case1==1) n=32_int64
    step=1_int64
    if (case1==6) step=2_int64
    owner=owned_descriptor_r64([n*step])
    do i=0_int64,n*step-1_int64
      key=modulo(i*37_int64,257_int64)-128_int64
      if (case1==5 .or. case1==8) key=modulo(i,5_int64)-2_int64
      position=i+1_int64
      if (case1==7) position=1_int64+i/128_int64+modulo(i,128_int64)*64_int64
      owner%data(position)=real(key,real64)
    end do
    if (case1==3 .or. case1==4) then
      do i=2_int64,n
        key=int(owner%data(i),int64)
        j=i-1_int64
        do while (j>=1_int64)
          if (owner%data(j)<=real(key,real64)) exit
          owner%data(j+1_int64)=owner%data(j)
          j=j-1_int64
        end do
        owner%data(j+1_int64)=real(key,real64)
      end do
      if (case1==4) owner%data=owner%data(n:1:-1)
    end if
    a=view_descriptor_r64(owner,[n],[step],1_int64)
    if (case1==7) a=view_descriptor_r64(owner,[64_int64,128_int64], &
      [1_int64,64_int64],1_int64)
    if (case1==8) a=view_descriptor_r64(owner,[64_int64,128_int64], &
      [128_int64,-1_int64],128_int64)
    ! Establish a stable expected first slice independently with insertion sort.
    allocate(logical_values(a%shape(a%rank)),expected(a%shape(a%rank)))
    do i=1_int64,size(expected,kind=int64)
      logical_values(i)=owner%data(a%offset+(i-1_int64)*a%strides(a%rank))
      expected(i)=i-1_int64
    end do
    do i=2_int64,size(expected,kind=int64)
      key=expected(i)
      j=i-1_int64
      do while (j>=1_int64)
        if (logical_values(expected(j)+1_int64)<=logical_values(key+1_int64)) exit
        expected(j+1_int64)=expected(j)
        j=j-1_int64
      end do
      expected(j+1_int64)=key
    end do
    repeats=20
    if (n==32_int64) repeats=1000
    do sample1=1,7
      call cpu_time(start)
      do repeat1=1,repeats
        if (operation==0) then
          values=sort(a,status=status)
          if (status%is_failure()) error stop 'sort status'
          if (values%data(1)/=logical_values(expected(1)+1_int64)) error stop 'sort value'
          call values%release()
        else
          indices=argsort(a,status=status)
          if (status%is_failure()) error stop 'argsort status'
          if (indices%data(1)/=expected(1)) error stop 'argsort index'
          call indices%release()
        end if
      end do
      call cpu_time(finish)
      write(*,'(4(i0,1x),es24.16)') 5,operation,case1,sample1,(finish-start)/repeats
    end do
  end subroutine bench_r64
end program benchmark_sort_dtypes
