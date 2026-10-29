!> Allocating native linalg calls, dense C-order inputs, setup outside timing.
program benchmark_linalg_precision
  use iso_fortran_env, only: int32, int64, real32, real64
  use frumpy, only: ndarray_r32, ndarray_r64, owned_descriptor_r32, owned_descriptor_r64, &
    matmul_r32, matmul_r64, solve_r32, solve_r64, frumpy_status
  implicit none
  integer :: n, size1
  integer, parameter :: sizes(3) = [16, 128, 512]
  do size1 = 1, size(sizes)
    n = sizes(size1)
    call bench32(n)
    call bench64(n)
  end do
contains
  subroutine bench32(n)
    integer, intent(in) :: n
    type(ndarray_r32) :: a, b, result
    type(frumpy_status) :: status
    integer :: i, operation, repeat1, sample1, repeats
    real(real64) :: start, finish
    real(real32) :: expected

    a = owned_descriptor_r32([int(n,int64), int(n,int64)])
    b = owned_descriptor_r32([int(n,int64), int(n,int64)])
    a%data = 0.01_real32
    b%data = 1.0_real32
    do i = 1, n
      a%data((i-1)*n+i) = a%data((i-1)*n+i) + real(n,real32)
    end do
    repeats = 10
    if (n == 512) repeats = 1
    do operation = 3, 4
      if (operation == 3) then
        result = matmul_r32(a,b,status)
        expected = real(n,real32) * 1.01_real32
      else
        result = solve_r32(a,b,status)
        expected = 1.0_real32 / (real(n,real32) * 1.01_real32)
      end if
      if (status%is_failure()) error stop 'native benchmark warmup failed'
      if (maxval(abs(result%data-expected)) > abs(expected)*1e-4_real32) &
        error stop 'native benchmark result mismatch'
      call result%release()
      do sample1 = 1, 5
        call cpu_time(start)
        do repeat1 = 1, repeats
          if (operation == 3) then
            result = matmul_r32(a,b,status)
          else
            result = solve_r32(a,b,status)
          end if
          if (status%is_failure()) error stop 'native benchmark failed'
          call result%release()
        end do
        call cpu_time(finish)
        write(*,'(i0,1x,i0,1x,i0,1x,es24.16)') 32,operation,n,(finish-start)/repeats
      end do
    end do
  end subroutine bench32
  subroutine bench64(n)
    integer, intent(in) :: n
    type(ndarray_r64) :: a, b, result
    type(frumpy_status) :: status
    integer :: i, operation, repeat1, sample1, repeats
    real(real64) :: start, finish
    real(real64) :: expected

    a = owned_descriptor_r64([int(n,int64), int(n,int64)])
    b = owned_descriptor_r64([int(n,int64), int(n,int64)])
    a%data = 0.01_real64
    b%data = 1.0_real64
    do i = 1, n
      a%data((i-1)*n+i) = a%data((i-1)*n+i) + real(n,real64)
    end do
    repeats = 10
    if (n == 512) repeats = 1
    do operation = 3, 4
      if (operation == 3) then
        result = matmul_r64(a,b,status)
        expected = real(n,real64) * 1.01_real64
      else
        result = solve_r64(a,b,status)
        expected = 1.0_real64 / (real(n,real64) * 1.01_real64)
      end if
      if (status%is_failure()) error stop 'native benchmark warmup failed'
      if (maxval(abs(result%data-expected)) > abs(expected)*1e-4_real64) &
        error stop 'native benchmark result mismatch'
      call result%release()
      do sample1 = 1, 5
        call cpu_time(start)
        do repeat1 = 1, repeats
          if (operation == 3) then
            result = matmul_r64(a,b,status)
          else
            result = solve_r64(a,b,status)
          end if
          if (status%is_failure()) error stop 'native benchmark failed'
          call result%release()
        end do
        call cpu_time(finish)
        write(*,'(i0,1x,i0,1x,i0,1x,es24.16)') 64,operation,n,(finish-start)/repeats
      end do
    end do
  end subroutine bench64
end program benchmark_linalg_precision
