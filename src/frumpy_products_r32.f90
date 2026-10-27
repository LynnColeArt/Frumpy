!> Native float32 dot and outer products with C-logical strided traversal.
module frumpy_products_r32
  use iso_fortran_env, only: int32, int64, real32
  use frumpy_constants, only: FRUMPY_MAX_RANK
  use frumpy_ndarray_r32, only: ndarray_r32, owned_descriptor_r32
  use frumpy_constructors_r32, only: validate_source => validate_r32
  use frumpy_strides, only: flat_offset
  use frumpy_shape, only: element_count
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_INVALID_SHAPE, &
    FRUMPY_STATUS_OVERFLOW
  implicit none
  private
  public :: outer_r32, dot_r32
contains
  !> Flatten inputs in C logical order without copies; allocate only the rank-two result.
  function outer_r32(lhs, rhs, status) result(array)
    type(ndarray_r32), intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: array
    type(frumpy_status) :: local_status
    integer(int64) :: m, n, count, row0, column0, left_position, right_position

    call validate_source(lhs, local_status)
    if (local_status%is_ok()) call validate_source(rhs, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    m = lhs%size()
    n = rhs%size()
    count = element_count([m, n], local_status)
    if (local_status%is_ok()) then
      if (count > shiftr(huge(1_int64), 2)) &
        call set_status(local_status, FRUMPY_STATUS_OVERFLOW, "outer output byte count overflows")
    end if
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    array = owned_descriptor_r32([m, n], status=local_status)
    if (present(status)) status = local_status
    if (local_status%is_failure() .or. count == 0_int64) return
    do row0 = 0_int64, m - 1_int64
      left_position = flat_offset(lhs%shape, lhs%strides, lhs%offset, row0)
      do column0 = 0_int64, n - 1_int64
        right_position = flat_offset(rhs%shape, rhs%strides, rhs%offset, column0)
        array%data(row0 * n + column0 + 1_int64) = &
          lhs%data(left_position) * rhs%data(right_position)
      end do
    end do
  end function outer_r32


  !> Contract the last left axis with the second-last right axis (only axis for vectors).
  function dot_r32(lhs, rhs, status) result(array)
    type(ndarray_r32), intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: array
    type(frumpy_status) :: local_status
    integer(int64) :: shape(2 * FRUMPY_MAX_RANK), left(2 * FRUMPY_MAX_RANK)
    integer(int64) :: right(2 * FRUMPY_MAX_RANK), k, count, i0, lp, rp, ls, rs
    integer(int32) :: rank, dim1, contracted
    real(real32) :: value
    logical :: scalar_product

    call validate_source(lhs, local_status)
    if (local_status%is_ok()) call validate_source(rhs, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    left = 0_int64
    right = 0_int64
    rank = 0_int32
    ls = 0_int64
    rs = 0_int64
    k = 1_int64
    scalar_product = lhs%rank == 0 .or. rhs%rank == 0
    if (scalar_product) then
      rank = max(lhs%rank, rhs%rank)
      if (lhs%rank > 0) then
        shape(:rank) = lhs%shape
        left(:rank) = lhs%strides
      else
        shape(:rank) = rhs%shape
        right(:rank) = rhs%strides
      end if
    else
      contracted = max(1_int32, rhs%rank - 1_int32)
      k = lhs%shape(lhs%rank)
      if (rhs%shape(contracted) /= k) then
        call set_status(local_status, FRUMPY_STATUS_INVALID_SHAPE, "dot core dimensions differ")
        if (present(status)) status = local_status
        return
      end if
      ls = lhs%strides(lhs%rank)
      rs = rhs%strides(contracted)
      rank = lhs%rank - 1_int32
      shape(:rank) = lhs%shape(:rank)
      left(:rank) = lhs%strides(:rank)
      do dim1 = 1_int32, rhs%rank
        if (dim1 == contracted) cycle
        rank = rank + 1_int32
        shape(rank) = rhs%shape(dim1)
        right(rank) = rhs%strides(dim1)
      end do
    end if
    count = element_count(shape(:rank), local_status)
    if (local_status%is_ok()) then
      if (count > shiftr(huge(1_int64), 2)) &
        call set_status(local_status, FRUMPY_STATUS_OVERFLOW, "dot output bytes overflow")
    end if
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    array = owned_descriptor_r32(shape(:rank), status=local_status)
    if (present(status)) status = local_status
    if (local_status%is_failure()) return
    array%data = 0.0_real32
    if (k == 0_int64) return
    do i0 = 0_int64, count - 1_int64
      lp = flat_offset(shape(:rank), left(:rank), lhs%offset, i0)
      rp = flat_offset(shape(:rank), right(:rank), rhs%offset, i0)
      if (scalar_product) then
        value = lhs%data(lp) * rhs%data(rp)
      else
        value = pairwise_dot(lhs%data, rhs%data, lp, rp, ls, rs, k)
      end if
      array%data(i0 + 1_int64) = value
    end do
  end function dot_r32
  ! Fixed pairwise tree bounds long-contraction rounding without widening or a product buffer.
  recursive function pairwise_dot(lhs, rhs, lp, rp, ls, rs, count) result(value)
    real(real32), intent(in) :: lhs(:), rhs(:)
    integer(int64), intent(in) :: lp, rp, ls, rs, count
    real(real32) :: value, left_sum, right_sum
    integer(int64) :: middle, i0

    if (count <= 32_int64) then
      value = 0.0_real32
      do i0 = 0_int64, count - 1_int64
        value = value + lhs(lp + i0*ls) * rhs(rp + i0*rs)
      end do
    else
      middle = count / 2_int64
      left_sum = pairwise_dot(lhs, rhs, lp, rp, ls, rs, middle)
      right_sum = pairwise_dot(lhs, rhs, lp + middle*ls, rp + middle*rs, ls, rs, count - middle)
      value = left_sum + right_sum
    end if
  end function pairwise_dot
end module frumpy_products_r32
