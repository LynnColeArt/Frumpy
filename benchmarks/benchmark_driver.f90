!> Wall-clock timing inside one process; setup and correctness checks are outside samples.
program benchmark_driver
  use iso_fortran_env, only: int32, int64, real32, real64, compiler_version, compiler_options
  use frumpy, only: ndarray_r64, ndarray_r32, owned_descriptor_r64, owned_descriptor_r32, &
    view_descriptor_r64, add_r64, add_r32, sum_r64, sort_r64, frumpy_status
  implicit none
  character(len=32) :: operation, layout, argument
  integer(int64) :: count
  integer(int32) :: iterations, samples

  call get_command_argument(1, operation)
  if (operation == '--version') then
    print '(a)', compiler_version()
    print '(a)', compiler_options()
    stop
  end if
  call get_command_argument(2, layout)
  call get_command_argument(3, argument)
  read (argument, *) count
  call get_command_argument(4, argument)
  read (argument, *) iterations
  call get_command_argument(5, argument)
  read (argument, *) samples
  if (count < 1 .or. iterations < 1 .or. samples < 1) error stop 'positive sizes required'
  call run_benchmark()

contains

  subroutine run_benchmark()
    type(ndarray_r64) :: backing, lhs, rhs, result
    type(ndarray_r32) :: lhs32, rhs32, result32
    type(frumpy_status) :: status
    integer(int64) :: item1, step, offset, start, finish, rate
    integer(int32) :: iteration, sample
    real(real64) :: checksum, expected

    step = 1_int64
    if (layout == 'stride2') step = 2_int64
    backing = owned_descriptor_r64([count * step])
    do item1 = 1_int64, count * step
      backing%data(item1) = real(modulo(37_int64 * item1, count), real64) / real(count, real64)
    end do
    offset = 1_int64
    if (layout == 'reverse') then
      step = -1_int64
      offset = count
    end if
    lhs = view_descriptor_r64(backing, [count], [step], offset)
    if (layout == 'broadcast') then
      rhs = owned_descriptor_r64([integer(int64) ::])
    else
      rhs = owned_descriptor_r64([count])
    end if
    rhs%data = 2.0_real64
    if (operation == 'add_r32') then
      if (layout /= 'contiguous') error stop 'float32 benchmark uses contiguous layout'
      lhs32 = owned_descriptor_r32([count])
      rhs32 = owned_descriptor_r32([count])
      lhs32%data = real(backing%data, real32)
      rhs32%data = 2.0_real32
    end if

    ! Warm up and validate the entire output, not merely the first value.
    call compute(lhs, rhs, lhs32, rhs32, result, result32, status)
    if (status%is_failure()) error stop 'benchmark operation failed'
    if (operation == 'add_r32') then
      if (any(abs(result32%data - (lhs32%data + rhs32%data)) > 0.0_real32)) &
        error stop 'incorrect float32 addition'
      checksum = sum(real(result32%data, real64))
    else if (operation == 'sum_r64') then
      expected = sum(backing%data(offset:offset + (count - 1_int64) * step:step))
      if (abs(result%data(1) - expected) > 1e-10_real64 * max(1.0_real64, abs(expected))) &
        error stop 'incorrect reduction'
      checksum = result%data(1)
    else
      do item1 = 1_int64, count
        if (operation == 'sort_r64') then
          expected = real(item1 - 1_int64, real64) / real(count, real64)
        else
          expected = backing%data(offset + (item1 - 1_int64) * step) + 2.0_real64
        end if
        if (abs(result%data(item1) - expected) > 1e-12_real64) error stop 'incorrect values'
      end do
      checksum = sum(result%data)
    end if
    call result%release()
    call result32%release()
    write (*, '(es26.17e3)') checksum
    call system_clock(count_rate=rate)
    do sample = 1_int32, samples
      call system_clock(start)
      do iteration = 1_int32, iterations
        call compute(lhs, rhs, lhs32, rhs32, result, result32, status)
        if (status%is_failure()) error stop 'benchmark operation failed'
        call result%release()
        call result32%release()
      end do
      call system_clock(finish)
      write (*, '(es26.17e3)') real(finish - start, real64) / real(rate, real64) &
        / real(iterations, real64)
    end do
  end subroutine run_benchmark

  subroutine compute(lhs, rhs, lhs32, rhs32, result, result32, status)
    type(ndarray_r64), intent(in) :: lhs, rhs
    type(ndarray_r32), intent(in) :: lhs32, rhs32
    type(ndarray_r64), intent(inout) :: result
    type(ndarray_r32), intent(inout) :: result32
    type(frumpy_status), intent(out) :: status

    select case (operation)
    case ('add_r64')
      result = add_r64(lhs, rhs, status)
    case ('add_r32')
      result32 = add_r32(lhs32, rhs32, status)
    case ('sum_r64')
      result = sum_r64(lhs, status=status)
    case ('sort_r64')
      result = sort_r64(lhs, status=status)
    case default
      error stop 'unknown benchmark operation'
    end select
  end subroutine compute
end program benchmark_driver
