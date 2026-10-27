!> Floating-result products: promote inputs before entering the concrete kernels.
module frumpy_product_promotion
  use iso_fortran_env, only: int32
  use frumpy_operands, only: operand, bind_operand, descriptor_dtype
  use frumpy_promotion, only: promote_dtypes
  use frumpy_array_casting, only: astype
  use frumpy_ndarray_r32, only: ndarray_r32
  use frumpy_ndarray_r64, only: ndarray_r64
  use frumpy_linalg_r32, only: outer_r32, dot_r32, matmul_r32
  use frumpy_linalg_r64, only: outer_r64, dot_r64, matmul_r64
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_UNSUPPORTED_DTYPE
  implicit none
  private
  public :: outer, dot, matmul
contains
  subroutine outer(lhs, rhs, result, status)
    class(*), target, intent(in) :: lhs, rhs
    class(*), intent(inout) :: result
    type(frumpy_status), optional, intent(out) :: status

    call product(lhs, rhs, result, 1_int32, status)
  end subroutine outer

  subroutine dot(lhs, rhs, result, status)
    class(*), target, intent(in) :: lhs, rhs
    class(*), intent(inout) :: result
    type(frumpy_status), optional, intent(out) :: status

    call product(lhs, rhs, result, 2_int32, status)
  end subroutine dot

  subroutine matmul(lhs, rhs, result, status)
    class(*), target, intent(in) :: lhs, rhs
    class(*), intent(inout) :: result
    type(frumpy_status), optional, intent(out) :: status

    call product(lhs, rhs, result, 3_int32, status)
  end subroutine matmul

  ! Failure leaves the caller's previous result intact. Only changed dtypes allocate casts.
  subroutine product(lhs, rhs, result, operation, status)
    class(*), target, intent(in) :: lhs, rhs
    class(*), intent(inout) :: result
    integer(int32), intent(in) :: operation
    type(frumpy_status), optional, intent(out) :: status
    type(frumpy_status) :: local
    type(operand) :: borrowed
    integer(int32) :: dtype

    call bind_operand(lhs, borrowed, local)
    if (local%is_ok()) call bind_operand(rhs, borrowed, local)
    if (local%is_ok()) then
      dtype = promote_dtypes(descriptor_dtype(lhs), descriptor_dtype(rhs), local)
      if (local%is_ok()) then
        if ((dtype /= 4_int32 .and. dtype /= 5_int32) .or. &
            dtype /= descriptor_dtype(result)) then
          call set_status(local, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
            "product requires a floating promoted destination dtype")
        end if
      end if
    end if
    if (local%is_failure()) then
      if (present(status)) status = local
      return
    end if
    select type (result)
    type is (ndarray_r32)
      block
        type(ndarray_r32), target :: converted_left, converted_right
        type(ndarray_r32), pointer :: left, right
        type(ndarray_r32) :: staged

        select type (lhs)
        type is (ndarray_r32)
          left => lhs
        class default
          call astype(lhs, converted_left, status=local)
          left => converted_left
        end select
        if (local%is_ok()) then
          select type (rhs)
          type is (ndarray_r32)
            right => rhs
          class default
            call astype(rhs, converted_right, status=local)
            right => converted_right
          end select
        end if
        if (local%is_ok()) then
          select case (operation)
          case (1)
            staged = outer_r32(left, right, local)
          case (2)
            staged = dot_r32(left, right, local)
          case (3)
            staged = matmul_r32(left, right, local)
          end select
          if (local%is_ok()) call result%share_from(staged, local)
        end if
      end block
    type is (ndarray_r64)
      block
        type(ndarray_r64), target :: converted_left, converted_right
        type(ndarray_r64), pointer :: left, right
        type(ndarray_r64) :: staged

        select type (lhs)
        type is (ndarray_r64)
          left => lhs
        class default
          call astype(lhs, converted_left, status=local)
          left => converted_left
        end select
        if (local%is_ok()) then
          select type (rhs)
          type is (ndarray_r64)
            right => rhs
          class default
            call astype(rhs, converted_right, status=local)
            right => converted_right
          end select
        end if
        if (local%is_ok()) then
          select case (operation)
          case (1)
            staged = outer_r64(left, right, local)
          case (2)
            staged = dot_r64(left, right, local)
          case (3)
            staged = matmul_r64(left, right, local)
          end select
          if (local%is_ok()) call result%share_from(staged, local)
        end if
      end block
    end select
    if (present(status)) status = local
  end subroutine product
end module frumpy_product_promotion
