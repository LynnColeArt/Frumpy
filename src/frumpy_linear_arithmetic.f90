!> Allocation-free linear floating-point kernels; callers validate storage bounds first.
module frumpy_linear_arithmetic
  use iso_fortran_env, only: int32, int64, real32, real64
  use frumpy_strides, only: is_c_contiguous
  implicit none
  private
  public :: linear_step, linear_binary_r32, linear_binary_r64

contains

  ! Derive traversal from actual broadcast strides, never cached descriptor flags.
  integer(int64) function linear_step(shape, strides) result(step)
    integer(int64), intent(in) :: shape(:), strides(:)

    step = -1_int64
    if (all(shape <= 1_int64 .or. strides == 0_int64)) then
      step = 0_int64
    else if (is_c_contiguous(shape, strides)) then
      step = 1_int64
    end if
  end function linear_step

  subroutine linear_binary_r32(left, right, output, left_offset, right_offset, &
      left_step, right_step, operation)
    real(real32), intent(in) :: left(:), right(:)
    real(real32), intent(out) :: output(:)
    integer(int64), intent(in) :: left_offset, right_offset, left_step, right_step
    integer(int32), intent(in) :: operation
    integer(int64) :: i

    select case (operation)
    case (1)
      do i = 0_int64, size(output, kind=int64) - 1_int64
        output(i + 1_int64) = left(left_offset + i * left_step) &
          + right(right_offset + i * right_step)
      end do
    case (2)
      do i = 0_int64, size(output, kind=int64) - 1_int64
        output(i + 1_int64) = left(left_offset + i * left_step) &
          - right(right_offset + i * right_step)
      end do
    case (3)
      do i = 0_int64, size(output, kind=int64) - 1_int64
        output(i + 1_int64) = left(left_offset + i * left_step) &
          * right(right_offset + i * right_step)
      end do
    case (4)
      do i = 0_int64, size(output, kind=int64) - 1_int64
        output(i + 1_int64) = left(left_offset + i * left_step) &
          / right(right_offset + i * right_step)
      end do
    end select
  end subroutine linear_binary_r32

  subroutine linear_binary_r64(left, right, output, left_offset, right_offset, &
      left_step, right_step, operation)
    real(real64), intent(in) :: left(:), right(:)
    real(real64), intent(out) :: output(:)
    integer(int64), intent(in) :: left_offset, right_offset, left_step, right_step
    integer(int32), intent(in) :: operation
    integer(int64) :: i

    select case (operation)
    case (1)
      do i = 0_int64, size(output, kind=int64) - 1_int64
        output(i + 1_int64) = left(left_offset + i * left_step) &
          + right(right_offset + i * right_step)
      end do
    case (2)
      do i = 0_int64, size(output, kind=int64) - 1_int64
        output(i + 1_int64) = left(left_offset + i * left_step) &
          - right(right_offset + i * right_step)
      end do
    case (3)
      do i = 0_int64, size(output, kind=int64) - 1_int64
        output(i + 1_int64) = left(left_offset + i * left_step) &
          * right(right_offset + i * right_step)
      end do
    case (4)
      do i = 0_int64, size(output, kind=int64) - 1_int64
        output(i + 1_int64) = left(left_offset + i * left_step) &
          / right(right_offset + i * right_step)
      end do
    end select
  end subroutine linear_binary_r64

end module frumpy_linear_arithmetic
