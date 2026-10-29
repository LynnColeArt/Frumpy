!> Allocation-free linear floating-point kernels; callers validate storage bounds first.
module frumpy_linear_arithmetic
  use iso_fortran_env, only: int32, int64, real32, real64
  implicit none
  private
  public :: linear_step, linear_binary_r32, linear_binary_r64
  public :: row_binary_r32, row_binary_r64

contains

  ! Derive traversal from actual broadcast strides, never cached descriptor flags.
  integer(int64) function linear_step(shape, strides, linear) result(step)
    integer(int64), intent(in) :: shape(:), strides(:)
    logical, intent(out) :: linear
    integer(int64) :: expected
    integer :: dim1
    logical :: found

    step = 0_int64
    expected = 0_int64
    found = .false.
    linear = .false.
    do dim1 = size(shape), 1, -1
      if (shape(dim1) <= 1_int64) cycle
      if (.not. found) then
        step = strides(dim1)
        expected = step
        found = .true.
      end if
      if (strides(dim1) /= expected) return
      if (dim1 > 1) then
        ! Avoid ABS(min-int) and signed multiplication overflow on malformed metadata.
        if (expected > huge(expected) / shape(dim1) .or. &
            expected < -huge(expected) / shape(dim1)) return
        expected = expected * shape(dim1)
      end if
    end do
    linear = .true.
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

  ! Input bounds are validated by callers; only outer coordinates need decoding.
  subroutine row_binary_r32(left, right, output, left_offset, right_offset, &
      shape, left_strides, right_strides, operation, index0)
    real(real32), intent(in) :: left(:), right(:)
    real(real32), intent(out) :: output(:)
    integer(int64), intent(in) :: left_offset, right_offset, shape(:)
    integer(int64), intent(in) :: left_strides(:), right_strides(:)
    integer(int32), intent(in) :: operation
    integer(int64), intent(out) :: index0(:)
    integer(int64) :: first, width, left_base, right_base
    integer :: rank, dim1

    rank = size(shape)
    width = shape(rank)
    index0 = 0_int64
    do first = 1_int64, size(output, kind=int64), width
      left_base = left_offset + sum(index0 * left_strides)
      right_base = right_offset + sum(index0 * right_strides)
      call linear_binary_r32(left, right, output(first:first + width - 1_int64), &
        left_base, right_base, left_strides(rank), right_strides(rank), operation)
      do dim1 = rank - 1, 1, -1
        index0(dim1) = index0(dim1) + 1_int64
        if (index0(dim1) < shape(dim1)) exit
        index0(dim1) = 0_int64
      end do
    end do
  end subroutine row_binary_r32

  ! Input bounds are validated by callers; only outer coordinates need decoding.
  subroutine row_binary_r64(left, right, output, left_offset, right_offset, &
      shape, left_strides, right_strides, operation, index0)
    real(real64), intent(in) :: left(:), right(:)
    real(real64), intent(out) :: output(:)
    integer(int64), intent(in) :: left_offset, right_offset, shape(:)
    integer(int64), intent(in) :: left_strides(:), right_strides(:)
    integer(int32), intent(in) :: operation
    integer(int64), intent(out) :: index0(:)
    integer(int64) :: first, width, left_base, right_base
    integer :: rank, dim1

    rank = size(shape)
    width = shape(rank)
    index0 = 0_int64
    do first = 1_int64, size(output, kind=int64), width
      left_base = left_offset + sum(index0 * left_strides)
      right_base = right_offset + sum(index0 * right_strides)
      call linear_binary_r64(left, right, output(first:first + width - 1_int64), &
        left_base, right_base, left_strides(rank), right_strides(rank), operation)
      do dim1 = rank - 1, 1, -1
        index0(dim1) = index0(dim1) + 1_int64
        if (index0(dim1) < shape(dim1)) exit
        index0(dim1) = 0_int64
      end do
    end do
  end subroutine row_binary_r64

end module frumpy_linear_arithmetic
