program first_vertical_slice
  use iso_fortran_env, only: int32, int64, real64
  use fenum, only: FENUM_STATUS_OK, add_r64, asarray_r64, fenum_status, &
    full_r64, ndarray_r64, sum_r64, zeros_r64

  implicit none

  type(fenum_status) :: status
  type(ndarray_r64) :: a
  type(ndarray_r64) :: b
  type(ndarray_r64) :: c
  type(ndarray_r64) :: d
  type(ndarray_r64) :: e

  a = zeros_r64([2_int64, 3_int64], status=status)
  call require_ok(status, "zeros_r64")

  b = full_r64([3_int64], 2.0_real64, status=status)
  call require_ok(status, "full_r64")

  c = add_r64(a, b, status)
  call require_ok(status, "add_r64")

  ! WP08 owns real reshape/view behavior. For the first executable vertical
  ! slice, make the reshaped step explicit as a C-order copy.
  d = asarray_r64(c%data, [3_int64, 2_int64], status=status)
  call require_ok(status, "temporary reshape copy")

  e = sum_r64(d, axis0=1_int32, status=status)
  call require_ok(status, "sum_r64")

  call require_shape(e, [3_int64])
  call require_values(e, [4.0_real64, 4.0_real64, 4.0_real64])

contains

  subroutine require_ok(status, label)
    type(fenum_status), intent(in) :: status
    character(len=*), intent(in) :: label

    if (status%code /= FENUM_STATUS_OK) then
      write (*, '(a,1x,a,1x,i0)') "FAIL:", label, status%code
      error stop 1
    end if
  end subroutine require_ok

  subroutine require_shape(array, expected_shape)
    type(ndarray_r64), intent(in) :: array
    integer(int64), intent(in) :: expected_shape(:)

    if (size(array%shape) /= size(expected_shape) .or. &
        any(array%shape /= expected_shape)) then
      write (*, '(a)') "FAIL: first vertical slice shape mismatch"
      error stop 1
    end if
  end subroutine require_shape

  subroutine require_values(array, expected_values)
    type(ndarray_r64), intent(in) :: array
    real(real64), intent(in) :: expected_values(:)

    if (size(array%data) /= size(expected_values) .or. &
        any(abs(array%data - expected_values) > 1.0e-12_real64)) then
      write (*, '(a)') "FAIL: first vertical slice value mismatch"
      error stop 1
    end if
  end subroutine require_values
end program first_vertical_slice
