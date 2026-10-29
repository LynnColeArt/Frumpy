program benchmark_search_dtypes
  use iso_fortran_env, only: int8, int32, int64, real32, real64
  use frumpy, only: ndarray_bool, ndarray_i32, ndarray_i64, ndarray_r32, ndarray_r64, &
    owned_descriptor_bool, owned_descriptor_i32, owned_descriptor_i64, &
    owned_descriptor_r32, owned_descriptor_r64, view_descriptor_bool, view_descriptor_i32, &
    view_descriptor_i64, view_descriptor_r32, view_descriptor_r64, searchsorted, frumpy_status
  implicit none
  integer :: case1,side
  do side=0,1
    do case1=1,8
      call bench_bool(side,case1)
      call bench_i32(side,case1)
      call bench_i64(side,case1)
      call bench_r32(side,case1)
      call bench_r64(side,case1)
    end do
  end do
contains
  subroutine bench_bool(side,case1)
    integer, intent(in) :: side,case1
    type(ndarray_bool) :: owner,query_owner,a,q
    type(ndarray_i64) :: result
    type(frumpy_status) :: status
    integer(int64) :: n,count,step,offset,i,j,key,position,expected,source_position,query_position
    integer :: sample1,repeat1,repeats
    real(real64) :: start,finish

    n=8192_int64
    count=4096_int64
    if (case1==1) then
      n=32_int64
      count=16_int64
    end if
    if (case1==2) count=1_int64
    step=1_int64
    if (case1==4) step=2_int64
    owner=owned_descriptor_bool([n*step])
    do i=0_int64,n-1_int64
      key=i/2_int64-n/4_int64
      if (case1==8) key=i/64_int64-n/128_int64
      key=merge(1_int64,0_int64,i>=n/2_int64)
      position=1_int64+i*step
      if (case1==5) position=n-i
      owner%data(position)=int(key,int8)
      if (case1==4) owner%data(position+1_int64)=int(key,int8)
    end do
    offset=1_int64
    if (case1==5) then
      offset=n
      step=-1_int64
    end if
    a=view_descriptor_bool(owner,[n],[step],offset)
    query_owner=owned_descriptor_bool([count])
    do i=0_int64,count-1_int64
      key=modulo(i*37_int64,n+17_int64)-n/2_int64
      key=modulo(i,2_int64)
      position=i+1_int64
      if (case1==6) position=1_int64+i/64_int64+modulo(i,64_int64)*64_int64
      query_owner%data(position)=int(key,int8)
    end do
    q=view_descriptor_bool(query_owner,[count],[1_int64],1_int64)
    if (case1==2) q=view_descriptor_bool(query_owner,[integer(int64)::], &
      [integer(int64)::],1_int64)
    if (case1==6) q=view_descriptor_bool(query_owner,[64_int64,64_int64], &
      [1_int64,64_int64],1_int64)
    if (case1==7) q=view_descriptor_bool(query_owner,[count],[-1_int64],count)
    ! Check every output against an independent linear count before timing.
    result=searchsorted(a,q,side==1,status)
    if (status%is_failure()) error stop 'search status'
    do i=0_int64,count-1_int64
      query_position=i+1_int64
      if (case1==6) query_position=1_int64+i/64_int64+modulo(i,64_int64)*64_int64
      if (case1==7) query_position=count-i
      expected=0_int64
      do j=0_int64,n-1_int64
        source_position=offset+j*step
        if (side==0) then
          if (owner%data(source_position)<query_owner%data(query_position)) expected=expected+1
        else
          if (owner%data(source_position)<=query_owner%data(query_position)) expected=expected+1
        end if
      end do
      if (result%data(i+1_int64)/=expected) error stop 'search result'
    end do
    call result%release()
    repeats=20
    if (count<32_int64) repeats=1000
    do sample1=1,7
      call cpu_time(start)
      do repeat1=1,repeats
        result=searchsorted(a,q,side==1,status)
        if (status%is_failure()) error stop 'search status'
        call result%release()
      end do
      call cpu_time(finish)
      write(*,'(4(i0,1x),es24.16)') 1,side,case1,sample1,(finish-start)/repeats
    end do
  end subroutine bench_bool
  subroutine bench_i32(side,case1)
    integer, intent(in) :: side,case1
    type(ndarray_i32) :: owner,query_owner,a,q
    type(ndarray_i64) :: result
    type(frumpy_status) :: status
    integer(int64) :: n,count,step,offset,i,j,key,position,expected,source_position,query_position
    integer :: sample1,repeat1,repeats
    real(real64) :: start,finish

    n=8192_int64
    count=4096_int64
    if (case1==1) then
      n=32_int64
      count=16_int64
    end if
    if (case1==2) count=1_int64
    step=1_int64
    if (case1==4) step=2_int64
    owner=owned_descriptor_i32([n*step])
    do i=0_int64,n-1_int64
      key=i/2_int64-n/4_int64
      if (case1==8) key=i/64_int64-n/128_int64
      position=1_int64+i*step
      if (case1==5) position=n-i
      owner%data(position)=int(key,int32)
      if (case1==4) owner%data(position+1_int64)=int(key,int32)
    end do
    offset=1_int64
    if (case1==5) then
      offset=n
      step=-1_int64
    end if
    a=view_descriptor_i32(owner,[n],[step],offset)
    query_owner=owned_descriptor_i32([count])
    do i=0_int64,count-1_int64
      key=modulo(i*37_int64,n+17_int64)-n/2_int64
      position=i+1_int64
      if (case1==6) position=1_int64+i/64_int64+modulo(i,64_int64)*64_int64
      query_owner%data(position)=int(key,int32)
    end do
    q=view_descriptor_i32(query_owner,[count],[1_int64],1_int64)
    if (case1==2) q=view_descriptor_i32(query_owner,[integer(int64)::], &
      [integer(int64)::],1_int64)
    if (case1==6) q=view_descriptor_i32(query_owner,[64_int64,64_int64], &
      [1_int64,64_int64],1_int64)
    if (case1==7) q=view_descriptor_i32(query_owner,[count],[-1_int64],count)
    ! Check every output against an independent linear count before timing.
    result=searchsorted(a,q,side==1,status)
    if (status%is_failure()) error stop 'search status'
    do i=0_int64,count-1_int64
      query_position=i+1_int64
      if (case1==6) query_position=1_int64+i/64_int64+modulo(i,64_int64)*64_int64
      if (case1==7) query_position=count-i
      expected=0_int64
      do j=0_int64,n-1_int64
        source_position=offset+j*step
        if (side==0) then
          if (owner%data(source_position)<query_owner%data(query_position)) expected=expected+1
        else
          if (owner%data(source_position)<=query_owner%data(query_position)) expected=expected+1
        end if
      end do
      if (result%data(i+1_int64)/=expected) error stop 'search result'
    end do
    call result%release()
    repeats=20
    if (count<32_int64) repeats=1000
    do sample1=1,7
      call cpu_time(start)
      do repeat1=1,repeats
        result=searchsorted(a,q,side==1,status)
        if (status%is_failure()) error stop 'search status'
        call result%release()
      end do
      call cpu_time(finish)
      write(*,'(4(i0,1x),es24.16)') 2,side,case1,sample1,(finish-start)/repeats
    end do
  end subroutine bench_i32
  subroutine bench_i64(side,case1)
    integer, intent(in) :: side,case1
    type(ndarray_i64) :: owner,query_owner,a,q
    type(ndarray_i64) :: result
    type(frumpy_status) :: status
    integer(int64) :: n,count,step,offset,i,j,key,position,expected,source_position,query_position
    integer :: sample1,repeat1,repeats
    real(real64) :: start,finish

    n=8192_int64
    count=4096_int64
    if (case1==1) then
      n=32_int64
      count=16_int64
    end if
    if (case1==2) count=1_int64
    step=1_int64
    if (case1==4) step=2_int64
    owner=owned_descriptor_i64([n*step])
    do i=0_int64,n-1_int64
      key=i/2_int64-n/4_int64
      if (case1==8) key=i/64_int64-n/128_int64
      key=key+2_int64**60
      position=1_int64+i*step
      if (case1==5) position=n-i
      owner%data(position)=int(key,int64)
      if (case1==4) owner%data(position+1_int64)=int(key,int64)
    end do
    offset=1_int64
    if (case1==5) then
      offset=n
      step=-1_int64
    end if
    a=view_descriptor_i64(owner,[n],[step],offset)
    query_owner=owned_descriptor_i64([count])
    do i=0_int64,count-1_int64
      key=modulo(i*37_int64,n+17_int64)-n/2_int64
      key=key+2_int64**60
      position=i+1_int64
      if (case1==6) position=1_int64+i/64_int64+modulo(i,64_int64)*64_int64
      query_owner%data(position)=int(key,int64)
    end do
    q=view_descriptor_i64(query_owner,[count],[1_int64],1_int64)
    if (case1==2) q=view_descriptor_i64(query_owner,[integer(int64)::], &
      [integer(int64)::],1_int64)
    if (case1==6) q=view_descriptor_i64(query_owner,[64_int64,64_int64], &
      [1_int64,64_int64],1_int64)
    if (case1==7) q=view_descriptor_i64(query_owner,[count],[-1_int64],count)
    ! Check every output against an independent linear count before timing.
    result=searchsorted(a,q,side==1,status)
    if (status%is_failure()) error stop 'search status'
    do i=0_int64,count-1_int64
      query_position=i+1_int64
      if (case1==6) query_position=1_int64+i/64_int64+modulo(i,64_int64)*64_int64
      if (case1==7) query_position=count-i
      expected=0_int64
      do j=0_int64,n-1_int64
        source_position=offset+j*step
        if (side==0) then
          if (owner%data(source_position)<query_owner%data(query_position)) expected=expected+1
        else
          if (owner%data(source_position)<=query_owner%data(query_position)) expected=expected+1
        end if
      end do
      if (result%data(i+1_int64)/=expected) error stop 'search result'
    end do
    call result%release()
    repeats=20
    if (count<32_int64) repeats=1000
    do sample1=1,7
      call cpu_time(start)
      do repeat1=1,repeats
        result=searchsorted(a,q,side==1,status)
        if (status%is_failure()) error stop 'search status'
        call result%release()
      end do
      call cpu_time(finish)
      write(*,'(4(i0,1x),es24.16)') 3,side,case1,sample1,(finish-start)/repeats
    end do
  end subroutine bench_i64
  subroutine bench_r32(side,case1)
    integer, intent(in) :: side,case1
    type(ndarray_r32) :: owner,query_owner,a,q
    type(ndarray_i64) :: result
    type(frumpy_status) :: status
    integer(int64) :: n,count,step,offset,i,j,key,position,expected,source_position,query_position
    integer :: sample1,repeat1,repeats
    real(real64) :: start,finish

    n=8192_int64
    count=4096_int64
    if (case1==1) then
      n=32_int64
      count=16_int64
    end if
    if (case1==2) count=1_int64
    step=1_int64
    if (case1==4) step=2_int64
    owner=owned_descriptor_r32([n*step])
    do i=0_int64,n-1_int64
      key=i/2_int64-n/4_int64
      if (case1==8) key=i/64_int64-n/128_int64
      position=1_int64+i*step
      if (case1==5) position=n-i
      owner%data(position)=real(key,real32)
      if (case1==4) owner%data(position+1_int64)=real(key,real32)
    end do
    offset=1_int64
    if (case1==5) then
      offset=n
      step=-1_int64
    end if
    a=view_descriptor_r32(owner,[n],[step],offset)
    query_owner=owned_descriptor_r32([count])
    do i=0_int64,count-1_int64
      key=modulo(i*37_int64,n+17_int64)-n/2_int64
      position=i+1_int64
      if (case1==6) position=1_int64+i/64_int64+modulo(i,64_int64)*64_int64
      query_owner%data(position)=real(key,real32)
    end do
    q=view_descriptor_r32(query_owner,[count],[1_int64],1_int64)
    if (case1==2) q=view_descriptor_r32(query_owner,[integer(int64)::], &
      [integer(int64)::],1_int64)
    if (case1==6) q=view_descriptor_r32(query_owner,[64_int64,64_int64], &
      [1_int64,64_int64],1_int64)
    if (case1==7) q=view_descriptor_r32(query_owner,[count],[-1_int64],count)
    ! Check every output against an independent linear count before timing.
    result=searchsorted(a,q,side==1,status)
    if (status%is_failure()) error stop 'search status'
    do i=0_int64,count-1_int64
      query_position=i+1_int64
      if (case1==6) query_position=1_int64+i/64_int64+modulo(i,64_int64)*64_int64
      if (case1==7) query_position=count-i
      expected=0_int64
      do j=0_int64,n-1_int64
        source_position=offset+j*step
        if (side==0) then
          if (owner%data(source_position)<query_owner%data(query_position)) expected=expected+1
        else
          if (owner%data(source_position)<=query_owner%data(query_position)) expected=expected+1
        end if
      end do
      if (result%data(i+1_int64)/=expected) error stop 'search result'
    end do
    call result%release()
    repeats=20
    if (count<32_int64) repeats=1000
    do sample1=1,7
      call cpu_time(start)
      do repeat1=1,repeats
        result=searchsorted(a,q,side==1,status)
        if (status%is_failure()) error stop 'search status'
        call result%release()
      end do
      call cpu_time(finish)
      write(*,'(4(i0,1x),es24.16)') 4,side,case1,sample1,(finish-start)/repeats
    end do
  end subroutine bench_r32
  subroutine bench_r64(side,case1)
    integer, intent(in) :: side,case1
    type(ndarray_r64) :: owner,query_owner,a,q
    type(ndarray_i64) :: result
    type(frumpy_status) :: status
    integer(int64) :: n,count,step,offset,i,j,key,position,expected,source_position,query_position
    integer :: sample1,repeat1,repeats
    real(real64) :: start,finish

    n=8192_int64
    count=4096_int64
    if (case1==1) then
      n=32_int64
      count=16_int64
    end if
    if (case1==2) count=1_int64
    step=1_int64
    if (case1==4) step=2_int64
    owner=owned_descriptor_r64([n*step])
    do i=0_int64,n-1_int64
      key=i/2_int64-n/4_int64
      if (case1==8) key=i/64_int64-n/128_int64
      position=1_int64+i*step
      if (case1==5) position=n-i
      owner%data(position)=real(key,real64)
      if (case1==4) owner%data(position+1_int64)=real(key,real64)
    end do
    offset=1_int64
    if (case1==5) then
      offset=n
      step=-1_int64
    end if
    a=view_descriptor_r64(owner,[n],[step],offset)
    query_owner=owned_descriptor_r64([count])
    do i=0_int64,count-1_int64
      key=modulo(i*37_int64,n+17_int64)-n/2_int64
      position=i+1_int64
      if (case1==6) position=1_int64+i/64_int64+modulo(i,64_int64)*64_int64
      query_owner%data(position)=real(key,real64)
    end do
    q=view_descriptor_r64(query_owner,[count],[1_int64],1_int64)
    if (case1==2) q=view_descriptor_r64(query_owner,[integer(int64)::], &
      [integer(int64)::],1_int64)
    if (case1==6) q=view_descriptor_r64(query_owner,[64_int64,64_int64], &
      [1_int64,64_int64],1_int64)
    if (case1==7) q=view_descriptor_r64(query_owner,[count],[-1_int64],count)
    ! Check every output against an independent linear count before timing.
    result=searchsorted(a,q,side==1,status)
    if (status%is_failure()) error stop 'search status'
    do i=0_int64,count-1_int64
      query_position=i+1_int64
      if (case1==6) query_position=1_int64+i/64_int64+modulo(i,64_int64)*64_int64
      if (case1==7) query_position=count-i
      expected=0_int64
      do j=0_int64,n-1_int64
        source_position=offset+j*step
        if (side==0) then
          if (owner%data(source_position)<query_owner%data(query_position)) expected=expected+1
        else
          if (owner%data(source_position)<=query_owner%data(query_position)) expected=expected+1
        end if
      end do
      if (result%data(i+1_int64)/=expected) error stop 'search result'
    end do
    call result%release()
    repeats=20
    if (count<32_int64) repeats=1000
    do sample1=1,7
      call cpu_time(start)
      do repeat1=1,repeats
        result=searchsorted(a,q,side==1,status)
        if (status%is_failure()) error stop 'search status'
        call result%release()
      end do
      call cpu_time(finish)
      write(*,'(4(i0,1x),es24.16)') 5,side,case1,sample1,(finish-start)/repeats
    end do
  end subroutine bench_r64
end program benchmark_search_dtypes
