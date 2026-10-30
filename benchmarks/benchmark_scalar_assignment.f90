!> Same harness links independently against before/after optimized cores.
program benchmark_scalar_assignment
  use iso_fortran_env, only: int8, int32, int64, real32, real64
  use frumpy, only: assign, mask_assign, frumpy_status
  use frumpy_ndarray_bool, only: ndarray_bool, owned_descriptor_bool, view_descriptor_bool
  use frumpy_ndarray_i32, only: ndarray_i32, owned_descriptor_i32, view_descriptor_i32
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64, view_descriptor_i64
  use frumpy_ndarray_r32, only: ndarray_r32, owned_descriptor_r32, view_descriptor_r32
  use frumpy_ndarray_r64, only: ndarray_r64, owned_descriptor_r64, view_descriptor_r64
  implicit none
  integer(int32) :: n, layout, masked, sample, run, repeats, side, size_id
  integer(int64) :: begin, finish, rate
  real(real64) :: elapsed
  type(frumpy_status) :: status
  call system_clock(count_rate=rate)
  do size_id=1,2
    n=16
    if (size_id==2) n=65536
    side=int(sqrt(real(n,real64)),int32)
    repeats=1000
    if (size_id==2) repeats=10
    do layout=1,5
      do masked=0,1
        call bench_bool()
        call bench_i32()
        call bench_i64()
        call bench_r32()
        call bench_r64()
      end do
    end do
  end do
contains
  subroutine bench_bool()
    type(ndarray_bool) :: owner, target, scalar
    type(ndarray_bool) :: mask
    integer(int64) :: i

    owner=owned_descriptor_bool([2_int64*n])
    scalar=owned_descriptor_bool([integer(int64)::])
    scalar%data=1_int8
    select case(layout)
    case(1)
      target=view_descriptor_bool(owner,[int(n,int64)],[1_int64],1_int64)
    case(2)
      target=view_descriptor_bool(owner,[int(n,int64)],[2_int64],1_int64)
    case(3)
      target=view_descriptor_bool(owner,[int(n,int64)],[-1_int64],int(n,int64))
    case(4)
      target=view_descriptor_bool(owner,[int(side,int64),int(side,int64)], &
        [1_int64,int(side,int64)],1_int64)
    case(5)
      target=view_descriptor_bool(owner,[int(side,int64),int(side,int64)], &
        [2_int64*side,-1_int64],int(side,int64))
    end select
    mask=owned_descriptor_bool(target%shape)
    do i=1_int64,mask%size()
      mask%data(i)=int(modulo(i,2_int64),int8)
    end do
    do sample=0,7
      call system_clock(begin)
      do run=1,repeats
        if(masked==1) then
          call mask_assign(target,mask,scalar,status)
        else
          call assign(target,scalar,status)
        end if
        if(status%is_failure()) error stop 'assignment failed'
      end do
      call system_clock(finish)
      elapsed=real(finish-begin,real64)/real(rate,real64)*1.e6_real64/repeats
      if(sample>0) print '(a,4(1x,i0),1x,f14.6)', 'bool',n,layout,masked,sample,elapsed
    end do
  end subroutine bench_bool

  subroutine bench_i32()
    type(ndarray_i32) :: owner, target, scalar
    type(ndarray_bool) :: mask
    integer(int64) :: i

    owner=owned_descriptor_i32([2_int64*n])
    scalar=owned_descriptor_i32([integer(int64)::])
    scalar%data=1_int32
    select case(layout)
    case(1)
      target=view_descriptor_i32(owner,[int(n,int64)],[1_int64],1_int64)
    case(2)
      target=view_descriptor_i32(owner,[int(n,int64)],[2_int64],1_int64)
    case(3)
      target=view_descriptor_i32(owner,[int(n,int64)],[-1_int64],int(n,int64))
    case(4)
      target=view_descriptor_i32(owner,[int(side,int64),int(side,int64)], &
        [1_int64,int(side,int64)],1_int64)
    case(5)
      target=view_descriptor_i32(owner,[int(side,int64),int(side,int64)], &
        [2_int64*side,-1_int64],int(side,int64))
    end select
    mask=owned_descriptor_bool(target%shape)
    do i=1_int64,mask%size()
      mask%data(i)=int(modulo(i,2_int64),int8)
    end do
    do sample=0,7
      call system_clock(begin)
      do run=1,repeats
        if(masked==1) then
          call mask_assign(target,mask,scalar,status)
        else
          call assign(target,scalar,status)
        end if
        if(status%is_failure()) error stop 'assignment failed'
      end do
      call system_clock(finish)
      elapsed=real(finish-begin,real64)/real(rate,real64)*1.e6_real64/repeats
      if(sample>0) print '(a,4(1x,i0),1x,f14.6)', 'i32',n,layout,masked,sample,elapsed
    end do
  end subroutine bench_i32

  subroutine bench_i64()
    type(ndarray_i64) :: owner, target, scalar
    type(ndarray_bool) :: mask
    integer(int64) :: i

    owner=owned_descriptor_i64([2_int64*n])
    scalar=owned_descriptor_i64([integer(int64)::])
    scalar%data=1_int64
    select case(layout)
    case(1)
      target=view_descriptor_i64(owner,[int(n,int64)],[1_int64],1_int64)
    case(2)
      target=view_descriptor_i64(owner,[int(n,int64)],[2_int64],1_int64)
    case(3)
      target=view_descriptor_i64(owner,[int(n,int64)],[-1_int64],int(n,int64))
    case(4)
      target=view_descriptor_i64(owner,[int(side,int64),int(side,int64)], &
        [1_int64,int(side,int64)],1_int64)
    case(5)
      target=view_descriptor_i64(owner,[int(side,int64),int(side,int64)], &
        [2_int64*side,-1_int64],int(side,int64))
    end select
    mask=owned_descriptor_bool(target%shape)
    do i=1_int64,mask%size()
      mask%data(i)=int(modulo(i,2_int64),int8)
    end do
    do sample=0,7
      call system_clock(begin)
      do run=1,repeats
        if(masked==1) then
          call mask_assign(target,mask,scalar,status)
        else
          call assign(target,scalar,status)
        end if
        if(status%is_failure()) error stop 'assignment failed'
      end do
      call system_clock(finish)
      elapsed=real(finish-begin,real64)/real(rate,real64)*1.e6_real64/repeats
      if(sample>0) print '(a,4(1x,i0),1x,f14.6)', 'i64',n,layout,masked,sample,elapsed
    end do
  end subroutine bench_i64

  subroutine bench_r32()
    type(ndarray_r32) :: owner, target, scalar
    type(ndarray_bool) :: mask
    integer(int64) :: i

    owner=owned_descriptor_r32([2_int64*n])
    scalar=owned_descriptor_r32([integer(int64)::])
    scalar%data=1.0_real32
    select case(layout)
    case(1)
      target=view_descriptor_r32(owner,[int(n,int64)],[1_int64],1_int64)
    case(2)
      target=view_descriptor_r32(owner,[int(n,int64)],[2_int64],1_int64)
    case(3)
      target=view_descriptor_r32(owner,[int(n,int64)],[-1_int64],int(n,int64))
    case(4)
      target=view_descriptor_r32(owner,[int(side,int64),int(side,int64)], &
        [1_int64,int(side,int64)],1_int64)
    case(5)
      target=view_descriptor_r32(owner,[int(side,int64),int(side,int64)], &
        [2_int64*side,-1_int64],int(side,int64))
    end select
    mask=owned_descriptor_bool(target%shape)
    do i=1_int64,mask%size()
      mask%data(i)=int(modulo(i,2_int64),int8)
    end do
    do sample=0,7
      call system_clock(begin)
      do run=1,repeats
        if(masked==1) then
          call mask_assign(target,mask,scalar,status)
        else
          call assign(target,scalar,status)
        end if
        if(status%is_failure()) error stop 'assignment failed'
      end do
      call system_clock(finish)
      elapsed=real(finish-begin,real64)/real(rate,real64)*1.e6_real64/repeats
      if(sample>0) print '(a,4(1x,i0),1x,f14.6)', 'r32',n,layout,masked,sample,elapsed
    end do
  end subroutine bench_r32

  subroutine bench_r64()
    type(ndarray_r64) :: owner, target, scalar
    type(ndarray_bool) :: mask
    integer(int64) :: i

    owner=owned_descriptor_r64([2_int64*n])
    scalar=owned_descriptor_r64([integer(int64)::])
    scalar%data=1.0_real64
    select case(layout)
    case(1)
      target=view_descriptor_r64(owner,[int(n,int64)],[1_int64],1_int64)
    case(2)
      target=view_descriptor_r64(owner,[int(n,int64)],[2_int64],1_int64)
    case(3)
      target=view_descriptor_r64(owner,[int(n,int64)],[-1_int64],int(n,int64))
    case(4)
      target=view_descriptor_r64(owner,[int(side,int64),int(side,int64)], &
        [1_int64,int(side,int64)],1_int64)
    case(5)
      target=view_descriptor_r64(owner,[int(side,int64),int(side,int64)], &
        [2_int64*side,-1_int64],int(side,int64))
    end select
    mask=owned_descriptor_bool(target%shape)
    do i=1_int64,mask%size()
      mask%data(i)=int(modulo(i,2_int64),int8)
    end do
    do sample=0,7
      call system_clock(begin)
      do run=1,repeats
        if(masked==1) then
          call mask_assign(target,mask,scalar,status)
        else
          call assign(target,scalar,status)
        end if
        if(status%is_failure()) error stop 'assignment failed'
      end do
      call system_clock(finish)
      elapsed=real(finish-begin,real64)/real(rate,real64)*1.e6_real64/repeats
      if(sample>0) print '(a,4(1x,i0),1x,f14.6)', 'r64',n,layout,masked,sample,elapsed
    end do
  end subroutine bench_r64

end program benchmark_scalar_assignment
