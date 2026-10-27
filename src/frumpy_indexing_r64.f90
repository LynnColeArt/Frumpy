!> Full-shape boolean extraction and staged broadcast assignment through float64 views.
module frumpy_indexing_r64
  use iso_fortran_env, only: int64
  use frumpy_ndarray_r64, only: ndarray_r64, owned_descriptor_r64
  use frumpy_ndarray_bool, only: ndarray_bool
  use frumpy_access_r64, only: validate_r64
  use frumpy_operands, only: operand, bind_operand, boolean_value
  use frumpy_broadcast, only: broadcast_plan, broadcast_plan_from_metadata
  use frumpy_strides, only: flat_offset
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_INVALID_SHAPE, &
    FRUMPY_STATUS_OVERFLOW
  implicit none
  private
  public :: mask_select_r64, assign_r64
contains
  !> The mask must have exactly the source shape; selected values are copied in C logical order.
  function mask_select_r64(source, mask, status) result(array)
    type(ndarray_r64), intent(in) :: source
    type(ndarray_bool), target, intent(in) :: mask
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(operand) :: condition
    type(frumpy_status) :: local_status
    integer(int64) :: i0, position, mask_position, selected

    call validate_r64(source, local_status)
    if (local_status%is_ok()) call bind_operand(mask, condition, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    if (source%rank /= mask%rank) then
      call set_status(local_status, FRUMPY_STATUS_INVALID_SHAPE, "mask rank must match source")
    else if (any(source%shape /= mask%shape)) then
      call set_status(local_status, FRUMPY_STATUS_INVALID_SHAPE, "mask shape must match source")
    end if
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    selected = 0_int64
    do i0 = 0_int64, source%size() - 1_int64
      mask_position = flat_offset(mask%shape, mask%strides, mask%offset, i0)
      if (boolean_value(condition, mask_position)) then
        if (selected == shiftr(huge(1_int64), 3)) then
          call set_status(local_status, FRUMPY_STATUS_OVERFLOW, "masked result bytes overflow")
          if (present(status)) status = local_status
          return
        end if
        selected = selected + 1_int64
      end if
    end do
    array = owned_descriptor_r64([selected], status=local_status)
    if (present(status)) status = local_status
    if (local_status%is_failure()) return
    selected = 0_int64
    do i0 = 0_int64, source%size() - 1_int64
      mask_position = flat_offset(mask%shape, mask%strides, mask%offset, i0)
      if (.not. boolean_value(condition, mask_position)) cycle
      selected = selected + 1_int64
      position = flat_offset(source%shape, source%strides, source%offset, i0)
      array%data(selected) = source%data(position)
    end do
  end function mask_select_r64

  !> Stage every RHS value before writing. Distinct descriptors may share backing storage.
  subroutine assign_r64(target, values, status)
    type(ndarray_r64), intent(inout) :: target
    type(ndarray_r64), intent(in) :: values
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: staged
    type(broadcast_plan) :: plan
    type(frumpy_status) :: local_status
    integer(int64) :: i0, position

    call validate_r64(target, local_status)
    if (local_status%is_ok()) call validate_r64(values, local_status)
    if (local_status%is_ok()) plan = broadcast_plan_from_metadata(target%shape, target%strides, &
      values%shape, values%strides, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    if (plan%rank /= target%rank) then
      call set_status(local_status, FRUMPY_STATUS_INVALID_SHAPE, "assignment cannot expand target")
    else if (any(plan%shape /= target%shape)) then
      call set_status(local_status, FRUMPY_STATUS_INVALID_SHAPE, "assignment cannot expand target")
    end if
    if (local_status%is_ok()) then
      if (target%size() > shiftr(huge(1_int64), 3)) &
        call set_status(local_status, FRUMPY_STATUS_OVERFLOW, "assignment staging bytes overflow")
    end if
    if (local_status%is_ok()) staged = owned_descriptor_r64(target%shape, status=local_status)
    if (present(status)) status = local_status
    if (local_status%is_failure()) return
    do i0 = 0_int64, target%size() - 1_int64
      position = flat_offset(plan%shape, plan%rhs_strides, values%offset, i0)
      staged%data(i0 + 1_int64) = values%data(position)
    end do
    do i0 = 0_int64, target%size() - 1_int64
      position = flat_offset(target%shape, target%strides, target%offset, i0)
      target%data(position) = staged%data(i0 + 1_int64)
    end do
  end subroutine assign_r64
end module frumpy_indexing_r64
