!> State serialization, stream chunking, and failure atomicity for explicit RNG objects.
program test_random
  use iso_fortran_env, only: int64, real64
  use frumpy, only: random_generator, uniform_r64, normal_r64, ndarray_r64, frumpy_status, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OVERFLOW
  implicit none
  call exercise()
contains
  subroutine exercise()
    type(random_generator) :: generator, restored, seeded
    type(ndarray_r64) :: first, second, whole, failed
    type(frumpy_status) :: status
    integer(int64) :: saved(7), bad(7), expected(4)

    call seeded%seed(0_int64)
    call require(all(generator%get_state() == seeded%get_state()), 'default is seed zero')
    first = uniform_r64(generator, [4_int64], status)
    call require(status%is_ok(), 'uniform status')
    expected = [int(z'3FE33D8BE6D96EBE', int64), int(z'3FE7EDC3EF092AC8', int64), &
      int(z'3FBA5F849D4933E0', int64), int(z'3FDAA9653C498B4A', int64)]
    ! Golden binary64 words are fixed separately from the unsigned Python reference.
    call require(all(transfer(first%data, expected) == expected), 'uniform golden stream')
    call require(first%owns_data .and. first%is_c_contiguous, 'random owned result')
    call generator%seed(-1_int64)
    first = normal_r64(generator, [3_int64], status)
    saved = generator%get_state()
    call require(saved(6) == 1_int64, 'odd normal call caches partner')
    call restored%set_state(saved, status)
    call require(status%is_ok(), 'state restore')
    first = normal_r64(generator, [7_int64])
    second = normal_r64(restored, [7_int64])
    call require(all(transfer(first%data, [0_int64], 7) == &
      transfer(second%data, [0_int64], 7)), 'restored stream including partner')
    call generator%seed(123_int64)
    whole = normal_r64(generator, [10_int64])
    call generator%seed(123_int64)
    first = normal_r64(generator, [3_int64])
    second = normal_r64(generator, [7_int64])
    call require(all(abs(whole%data - [first%data, second%data]) < 1e-15_real64), 'chunk invariant')
    saved = generator%get_state()
    failed = normal_r64(generator, [-1_int64], status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'invalid random shape')
    call require(all(generator%get_state() == saved), 'invalid shape preserves state')
    call require(.not. failed%has_storage(), 'failed random has no output')
    failed = uniform_r64(generator, [shiftr(huge(1_int64), 3) + 1_int64], status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'random bytes overflow')
    call require(all(generator%get_state() == saved), 'overflow preserves state')
    failed = normal_r64(generator, [0_int64])
    call require(all(generator%get_state() == saved), 'empty normal consumes nothing')
    bad = saved
    bad(1) = 99_int64
    call generator%set_state(bad, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'state version rejected')
    call require(all(generator%get_state() == saved), 'bad state preserves generator')
    bad = saved
    bad(2:5) = 0_int64
    call generator%set_state(bad)
    call require(all(generator%get_state() == saved), 'zero state rejected without status')
    call generator%set_state(saved(:6), status)
    call require(status%is_failure(), 'state length rejected')
    bad = saved
    bad(6) = 1_int64
    bad(7) = int(z'7FF0000000000000', int64)
    call generator%set_state(bad, status)
    call require(status%is_failure(), 'nonfinite cached normal rejected')
  end subroutine exercise

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_random
