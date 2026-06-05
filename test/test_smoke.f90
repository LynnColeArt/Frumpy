module fenum_test_smoke
  use iso_fortran_env, only: error_unit, int32, real64

  implicit none

  private

  public :: run_smoke_tests

contains

  subroutine run_smoke_tests(failures)
    integer(int32), intent(inout) :: failures
    real(real64) :: vector(3)

    vector = [1.0_real64, 2.0_real64, 3.0_real64]

    call assert_true("real64 arithmetic is available", &
                     abs(sum(vector) - 6.0_real64) < epsilon(1.0_real64), &
                     failures)
    call assert_true("rank-one arrays report the expected size", &
                     size(vector) == 3, &
                     failures)
  end subroutine run_smoke_tests

  subroutine assert_true(message, condition, failures)
    character(len=*), intent(in) :: message
    logical, intent(in) :: condition
    integer(int32), intent(inout) :: failures

    if (.not. condition) then
      failures = failures + 1_int32
      write(error_unit, '(a, a)') "FAIL: ", message
    end if
  end subroutine assert_true

end module fenum_test_smoke
