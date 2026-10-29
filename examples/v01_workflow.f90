!> End-to-end release example: managed views and native numerical work.
program v01_workflow
  use iso_fortran_env, only: int32, int64, real64
  use frumpy, only: ndarray_r64, ndarray_i32, ndarray_bool, frumpy_status, &
    asarray_r64, asarray_i32, full_r64, transpose_r64, add, sum_r64, greater, &
    mask_select_r64, matmul_r64, solve_r64
  implicit none
  type(ndarray_r64) :: a, view, mixed, totals, selected, identity, product, system, rhs, solution
  type(ndarray_i32) :: integers
  type(ndarray_bool) :: mask
  type(frumpy_status) :: status

  a = asarray_r64([1.0_real64,2.0_real64,3.0_real64,4.0_real64], &
    [2_int64,2_int64], status=status)
  call require_ok()
  view = transpose_r64(a, status)
  call require_ok()
  call a%release()
  if (view%owns_data .or. .not. view%has_storage()) error stop 'view lifetime'
  integers = asarray_i32([10_int32,20_int32], status=status)
  call require_ok()
  call add(view, integers, mixed, status)
  call require_ok()
  totals = sum_r64(mixed, axis0=1_int32, status=status)
  call require_ok()
  if (any(abs(totals%data - [34.0_real64,36.0_real64]) > 1.0e-12_real64)) &
    error stop 'broadcast reduction'
  rhs = full_r64([integer(int64) ::], 2.0_real64, status=status)
  call require_ok()
  mask = greater(view, rhs, status)
  call require_ok()
  selected = mask_select_r64(view, mask, status)
  call require_ok()
  if (any(abs(selected%data - [3.0_real64,4.0_real64]) > 1.0e-12_real64)) &
    error stop 'selection'
  identity = asarray_r64([1.0_real64,0.0_real64,0.0_real64,1.0_real64], &
    [2_int64,2_int64], status=status)
  call require_ok()
  product = matmul_r64(view, identity, status)
  call require_ok()
  if (any(abs(product%data - [1.0_real64,3.0_real64,2.0_real64,4.0_real64]) > &
      1.0e-12_real64)) error stop 'matmul'
  system = asarray_r64([4.0_real64,1.0_real64,1.0_real64,3.0_real64], &
    [2_int64,2_int64], status=status)
  call require_ok()
  rhs = asarray_r64([1.0_real64,2.0_real64], status=status)
  call require_ok()
  solution = solve_r64(system, rhs, status)
  call require_ok()
  if (any(abs(solution%data - [1.0_real64,7.0_real64]/11.0_real64) > &
      1.0e-12_real64)) error stop 'solve'
  print '(a,2f12.6)', 'row sums: ', totals%data
  print '(a,2f12.6)', 'selected: ', selected%data
  print '(a,2f12.6)', 'solution: ', solution%data
contains
  subroutine require_ok()
    if (status%is_failure()) then
      print *, trim(status%message)
      error stop 'Frumpy operation failed'
    end if
  end subroutine require_ok
end program v01_workflow
