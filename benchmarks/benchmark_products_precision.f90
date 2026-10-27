!> Allocating native products; inputs are exact dyadic values, setup untimed.
program benchmark_products_precision
  use iso_fortran_env, only: int32, int64, real32, real64
  use frumpy, only: ndarray_r32, ndarray_r64, owned_descriptor_r32, owned_descriptor_r64, &
    dot_r32, dot_r64, outer_r32, outer_r64, frumpy_status
  implicit none
  integer :: operation, n, size1
  integer, parameter :: sizes(3) = [16,1024,1048576]
  do operation = 1,2
    do size1 = 1,3
      n = sizes(size1)
      if (operation == 1 .and. n > 1024) cycle
      call bench32(n,operation)
      call bench64(n,operation)
    end do
  end do
contains
  subroutine bench32(n,operation)
    integer, intent(in) :: n, operation
    type(ndarray_r32) :: a,b,result
    type(frumpy_status) :: status
    integer :: repeat1,sample1,repeats
    real(real64) :: start,finish
    real(real32) :: expected

    a = owned_descriptor_r32([int(n,int64)])
    b = owned_descriptor_r32([int(n,int64)])
    a%data = 0.25_real32
    b%data = 0.5_real32
    if (operation == 1) then
      result = outer_r32(a,b,status)
      expected = 0.125_real32
    else
      result = dot_r32(a,b,status)
      expected = real(n,real32)*0.125_real32
    end if
    if (status%is_failure()) error stop 'native product warmup failed'
    if (maxval(abs(result%data-expected)) > 1e-6_real32) error stop 'native product values'
    call result%release()
    repeats = 100
    if (n >= 1024) repeats = 5
    do sample1 = 1,7
      call cpu_time(start)
      do repeat1 = 1,repeats
        if (operation == 1) then
          result = outer_r32(a,b,status)
        else
          result = dot_r32(a,b,status)
        end if
        if (status%is_failure()) error stop 'native product failed'
        call result%release()
      end do
      call cpu_time(finish)
      write(*,'(i0,1x,i0,1x,i0,1x,es24.16)') 32,operation,n,(finish-start)/repeats
    end do
  end subroutine bench32
  subroutine bench64(n,operation)
    integer, intent(in) :: n, operation
    type(ndarray_r64) :: a,b,result
    type(frumpy_status) :: status
    integer :: repeat1,sample1,repeats
    real(real64) :: start,finish
    real(real64) :: expected

    a = owned_descriptor_r64([int(n,int64)])
    b = owned_descriptor_r64([int(n,int64)])
    a%data = 0.25_real64
    b%data = 0.5_real64
    if (operation == 1) then
      result = outer_r64(a,b,status)
      expected = 0.125_real64
    else
      result = dot_r64(a,b,status)
      expected = real(n,real64)*0.125_real64
    end if
    if (status%is_failure()) error stop 'native product warmup failed'
    if (maxval(abs(result%data-expected)) > 1e-6_real64) error stop 'native product values'
    call result%release()
    repeats = 100
    if (n >= 1024) repeats = 5
    do sample1 = 1,7
      call cpu_time(start)
      do repeat1 = 1,repeats
        if (operation == 1) then
          result = outer_r64(a,b,status)
        else
          result = dot_r64(a,b,status)
        end if
        if (status%is_failure()) error stop 'native product failed'
        call result%release()
      end do
      call cpu_time(finish)
      write(*,'(i0,1x,i0,1x,i0,1x,es24.16)') 64,operation,n,(finish-start)/repeats
    end do
  end subroutine bench64
end program benchmark_products_precision
