!> Internal fixed-width arithmetic shared by concrete and mixed-dtype array kernels.
module frumpy_integer_scalars
  use iso_fortran_env, only: int32, int64
  implicit none
  private
  public :: wrap_i32, wrapped_add_i64, wrapped_subtract_i64, wrapped_multiply_i64

contains

  ! Widening makes every int32 add/subtract/product representable. Rebuild the
  ! signed low word without an out-of-range integer conversion.
  pure function wrap_i32(value) result(wrapped)
    integer(int64), intent(in) :: value
    integer(int32) :: wrapped

    wrapped = int(ibits(value, 0, 31), int32)
    if (btest(value, 31)) wrapped = wrapped - huge(0_int32) - 1_int32
  end function wrap_i32

  ! Each half-word sum fits int64; shifts assemble the modular two's-complement result.
  pure function wrapped_add_i64(lhs, rhs) result(value)
    integer(int64), intent(in) :: lhs, rhs
    integer(int64) :: value, low, high
    integer(int64), parameter :: MASK32 = int(z'FFFFFFFF', int64)

    low = iand(lhs, MASK32) + iand(rhs, MASK32)
    high = shiftr(lhs, 32) + shiftr(rhs, 32) + shiftr(low, 32)
    value = ior(iand(low, MASK32), shiftl(iand(high, MASK32), 32))
  end function wrapped_add_i64

  pure function wrapped_subtract_i64(lhs, rhs) result(value)
    integer(int64), intent(in) :: lhs, rhs
    integer(int64) :: value

    value = wrapped_add_i64(wrapped_add_i64(lhs, not(rhs)), 1_int64)
  end function wrapped_subtract_i64

  ! Base-2**16 digits keep even the largest partial-product sum below 2**35.
  ! Only the low four digits belong to the modular 64-bit result.
  pure function wrapped_multiply_i64(lhs, rhs) result(value)
    integer(int64), intent(in) :: lhs, rhs
    integer(int64) :: value, carry
    integer(int32) :: digit, part
    integer(int64), parameter :: MASK16 = int(z'FFFF', int64)

    value = 0_int64
    carry = 0_int64
    do digit = 0_int32, 3_int32
      do part = 0_int32, digit
        carry = carry + ibits(lhs, 16 * part, 16) * ibits(rhs, 16 * (digit - part), 16)
      end do
      value = ior(value, shiftl(iand(carry, MASK16), 16 * digit))
      carry = shiftr(carry, 16)
    end do
  end function wrapped_multiply_i64
end module frumpy_integer_scalars
