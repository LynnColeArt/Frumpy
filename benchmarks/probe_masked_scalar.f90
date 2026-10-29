!> Focused recheck of the noisy int32 stepped masked-scalar case.
program probe_masked_scalar
  use iso_fortran_env, only: int8, int32, int64, real64
  use frumpy, only: ndarray_i32, ndarray_bool, owned_descriptor_i32, owned_descriptor_bool, &
    view_descriptor_i32, mask_assign, frumpy_status
  implicit none
  type(ndarray_i32) :: owner, target, scalar
  type(ndarray_bool) :: mask
  type(frumpy_status) :: status
  integer(int32) :: sample, run
  integer(int64) :: begin, finish, rate, i

  owner = owned_descriptor_i32([131072_int64])
  target = view_descriptor_i32(owner, [65536_int64], [2_int64], 1_int64)
  scalar = owned_descriptor_i32([integer(int64)::])
  scalar%data = 1_int32
  mask = owned_descriptor_bool([65536_int64])
  do i=1_int64,65536_int64
    mask%data(i)=int(modulo(i,2_int64),int8)
  end do
  call system_clock(count_rate=rate)
  do sample=0,14
    call system_clock(begin)
    do run=1,100
      call mask_assign(target,mask,scalar,status)
      if(status%is_failure()) error stop 'assignment failed'
    end do
    call system_clock(finish)
    if(sample>0) print '(f14.6)',real(finish-begin,real64)/real(rate,real64)*1.e4_real64
  end do
end program probe_masked_scalar
