!> Native conversion cost; seven CPU-time samples, allocation/release included.
program benchmark_product_promotion
  use iso_fortran_env, only: int32, int64, real32, real64
  use frumpy, only: ndarray_i32, ndarray_r32, ndarray_r64, owned_descriptor_i32, &
    owned_descriptor_r32, dot, outer, matmul, astype, frumpy_status, &
    view_descriptor_i32, view_descriptor_r32
  implicit none
  integer :: operation, n, layout
  do operation = 1,3
    n = 256
    if (operation == 2) n = 65536
    if (operation == 3) n = 128
    do layout = 1,2
      call bench(operation,n,layout)
    end do
  end do
contains
  subroutine bench(operation,n,layout)
    integer, intent(in) :: operation,n,layout
    type(ndarray_i32) :: owner_a,a
    type(ndarray_r32) :: owner_b,b
    type(ndarray_r64) :: pa,pb,result,cast_a,cast_b
    type(frumpy_status) :: status
    integer :: mode,sample1,repeat1,repeats
    integer(int64), allocatable :: shape(:),strides(:)
    real(real64) :: start,finish,expected

    shape = [int(n*layout,int64)]
    if (operation == 3) shape = [int(n,int64),int(n*layout,int64)]
    owner_a = owned_descriptor_i32(shape)
    owner_b = owned_descriptor_r32(shape)
    owner_a%data = 1_int32
    owner_b%data = 1.0_real32
    shape(size(shape)) = int(n,int64)
    strides = owner_a%strides
    strides(size(strides)) = int(layout,int64)
    a = view_descriptor_i32(owner_a,shape,strides,1_int64)
    b = view_descriptor_r32(owner_b,shape,strides,1_int64)
    call astype(a,pa,status=status)
    if (status%is_failure()) error stop 'cast a'
    call astype(b,pb,status=status)
    if (status%is_failure()) error stop 'cast b'
    repeats = 20
    expected = real(n,real64)
    if (operation == 1) expected = 1.0_real64
    do mode = 1,3
      do sample1 = 1,7
        call cpu_time(start)
        do repeat1 = 1,repeats
          if (mode == 3) then
            call astype(a,cast_a,status=status)
            if (status%is_failure()) error stop 'cast a timed'
            call astype(b,cast_b,status=status)
            call cast_a%release()
            call cast_b%release()
          else
            select case (operation)
            case (1)
              if (mode == 1) then
                call outer(a,b,result,status)
              else
                call outer(pa,pb,result,status)
              end if
            case (2)
              if (mode == 1) then
                call dot(a,b,result,status)
              else
                call dot(pa,pb,result,status)
              end if
            case (3)
              if (mode == 1) then
                call matmul(a,b,result,status)
              else
                call matmul(pa,pb,result,status)
              end if
            end select
          end if
          if (status%is_failure()) error stop 'benchmark operation'
          if (mode /= 3) then
            if (abs(result%data(1)-expected)>1e-9_real64) error stop 'benchmark value'
            call result%release()
          end if
        end do
        call cpu_time(finish)
        write(*,'(4(i0,1x),es24.16)') operation,n,layout,mode,(finish-start)/repeats
      end do
    end do
  end subroutine bench
end program benchmark_product_promotion
