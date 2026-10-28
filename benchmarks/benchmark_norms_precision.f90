program benchmark_norms_precision
  use iso_fortran_env, only: int64, real32, real64
  use frumpy, only: ndarray_r32, ndarray_r64, owned_descriptor_r32, owned_descriptor_r64, &
    view_descriptor_r32, view_descriptor_r64, vector_norm_r32, vector_norm_r64, &
    matrix_norm_r32, matrix_norm_r64, frumpy_status
  implicit none
  integer :: n, k, layout, operation
  character(len=16) :: distribution
  logical :: varied
  integer, parameter :: sizes(3) = [16,65536,1048576]
  call get_command_argument(1,distribution)
  varied = trim(distribution) == 'varied'
  do operation = 0,1
    do k = 1,3
      n = sizes(k)
      if (operation == 1 .and. k > 1) cycle
      if (operation == 1) n = 128
      do layout = 1,2
        call bench32(n,layout,operation)
        call bench64(n,layout,operation)
      end do
    end do
  end do
contains
  subroutine bench32(n,layout,operation)
    integer, intent(in) :: n,layout,operation
    type(ndarray_r32) :: owner,a,result
    type(frumpy_status) :: status
    integer(int64), allocatable :: shape(:),strides(:)
    integer :: sample1,repeat1,repeats
    integer(int64) :: i
    real(real64) :: start,finish,expected

    shape = [int(n*layout,int64)]
    if (operation == 1) shape = [int(n,int64),int(n*layout,int64)]
    owner = owned_descriptor_r32(shape)
    owner%data = 0.5_real32
    if (varied) then
      do i = 1_int64, size(owner%data,kind=int64)
        owner%data(i) = real(modulo(i*37_int64,257_int64)-128_int64,real32)/128.0_real32
      end do
    end if
    shape(size(shape)) = int(n,int64)
    strides = owner%strides
    strides(size(strides)) = int(layout,int64)
    a = view_descriptor_r32(owner,shape,strides,1_int64)
    expected = sqrt(real(n,real64))*0.5_real64
    if (operation == 1) expected = real(n,real64)*0.5_real64
    if (varied) expected = sqrt(sum(real(owner%data(1::layout),real64)**2))
    repeats = 20
    if (n < 128) repeats = 1000
    do sample1 = 1,7
      call cpu_time(start)
      do repeat1 = 1,repeats
        if (operation == 0) then
          result = vector_norm_r32(a,status=status)
        else
          result = matrix_norm_r32(a,status=status)
        end if
        if (status%is_failure()) error stop 'norm status'
        if (abs(real(result%data(1),real64)-expected)>2e-7_real64*expected+1e-6_real64) &
          error stop 'norm value'
        call result%release()
      end do
      call cpu_time(finish)
      write(*,'(5(i0,1x),es24.16)') 32,operation,n,layout,sample1,(finish-start)/repeats
    end do
  end subroutine bench32
  subroutine bench64(n,layout,operation)
    integer, intent(in) :: n,layout,operation
    type(ndarray_r64) :: owner,a,result
    type(frumpy_status) :: status
    integer(int64), allocatable :: shape(:),strides(:)
    integer :: sample1,repeat1,repeats
    integer(int64) :: i
    real(real64) :: start,finish,expected

    shape = [int(n*layout,int64)]
    if (operation == 1) shape = [int(n,int64),int(n*layout,int64)]
    owner = owned_descriptor_r64(shape)
    owner%data = 0.5_real64
    if (varied) then
      do i = 1_int64, size(owner%data,kind=int64)
        owner%data(i) = real(modulo(i*37_int64,257_int64)-128_int64,real64)/128.0_real64
      end do
    end if
    shape(size(shape)) = int(n,int64)
    strides = owner%strides
    strides(size(strides)) = int(layout,int64)
    a = view_descriptor_r64(owner,shape,strides,1_int64)
    expected = sqrt(real(n,real64))*0.5_real64
    if (operation == 1) expected = real(n,real64)*0.5_real64
    if (varied) expected = sqrt(sum(real(owner%data(1::layout),real64)**2))
    repeats = 20
    if (n < 128) repeats = 1000
    do sample1 = 1,7
      call cpu_time(start)
      do repeat1 = 1,repeats
        if (operation == 0) then
          result = vector_norm_r64(a,status=status)
        else
          result = matrix_norm_r64(a,status=status)
        end if
        if (status%is_failure()) error stop 'norm status'
        if (abs(real(result%data(1),real64)-expected)>2e-7_real64*expected+1e-6_real64) &
          error stop 'norm value'
        call result%release()
      end do
      call cpu_time(finish)
      write(*,'(5(i0,1x),es24.16)') 64,operation,n,layout,sample1,(finish-start)/repeats
    end do
  end subroutine bench64
end program benchmark_norms_precision
