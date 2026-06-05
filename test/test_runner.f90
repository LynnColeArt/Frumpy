program test_runner
  use iso_fortran_env, only: int32
  use fenum_test_smoke, only: run_smoke_tests

  implicit none

  integer(int32) :: failures = 0_int32

  call run_smoke_tests(failures)

  if (failures > 0_int32) then
    write(*, '(a, i0)') "Fenum smoke tests failed: ", failures
    error stop 1
  end if

  write(*, '(a)') "Fenum smoke tests passed."
end program test_runner
