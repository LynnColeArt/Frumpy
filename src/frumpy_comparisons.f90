!> Broadcast comparisons promote numeric pairs and return normalized boolean storage.
module frumpy_comparisons
  use iso_fortran_env, only: int8, int32, int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
  use frumpy_operands, only: operand, bind_operand, integer_value, real64_value, boolean_value
  use frumpy_dtypes, only: FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_I64
  use frumpy_broadcast, only: broadcast_plan, broadcast_plan_from_metadata
  use frumpy_strides, only: flat_offset
  use frumpy_ndarray_bool, only: ndarray_bool, owned_descriptor_bool
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_UNSUPPORTED_DTYPE
  implicit none
  private
  public :: equal, not_equal, less, less_equal, greater, greater_equal
  public :: logical_and_bool, logical_or_bool, logical_xor_bool, logical_not_bool
contains
  function equal(lhs, rhs, status) result(array)
    class(*), target, intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: array

    array = boolean_binary(lhs, rhs, 'equal', status)
  end function equal

  function not_equal(lhs, rhs, status) result(array)
    class(*), target, intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: array

    array = boolean_binary(lhs, rhs, 'not_equal', status)
  end function not_equal

  function less(lhs, rhs, status) result(array)
    class(*), target, intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: array

    array = boolean_binary(lhs, rhs, 'less', status)
  end function less

  function less_equal(lhs, rhs, status) result(array)
    class(*), target, intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: array

    array = boolean_binary(lhs, rhs, 'less_equal', status)
  end function less_equal

  function greater(lhs, rhs, status) result(array)
    class(*), target, intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: array

    array = boolean_binary(lhs, rhs, 'greater', status)
  end function greater

  function greater_equal(lhs, rhs, status) result(array)
    class(*), target, intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: array

    array = boolean_binary(lhs, rhs, 'greater_equal', status)
  end function greater_equal

  function logical_and_bool(lhs, rhs, status) result(array)
    class(*), target, intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: array

    array = boolean_binary(lhs, rhs, 'logical_and', status)
  end function logical_and_bool

  function logical_or_bool(lhs, rhs, status) result(array)
    class(*), target, intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: array

    array = boolean_binary(lhs, rhs, 'logical_or', status)
  end function logical_or_bool

  function logical_xor_bool(lhs, rhs, status) result(array)
    class(*), target, intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: array

    array = boolean_binary(lhs, rhs, 'logical_xor', status)
  end function logical_xor_bool

  function logical_not_bool(source, status) result(array)
    class(*), target, intent(in) :: source
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: array
    type(operand) :: borrowed
    type(frumpy_status) :: local_status
    integer(int64) :: i0, position

    call bind_operand(source, borrowed, local_status)
    if (local_status%is_ok() .and. borrowed%dtype_id /= FRUMPY_DTYPE_BOOL) &
      call set_status(local_status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
        "logical operations require bool")
    if (local_status%is_ok()) array = owned_descriptor_bool(borrowed%shape, status=local_status)
    if (present(status)) status = local_status
    if (local_status%is_failure()) return
    do i0 = 0_int64, array%size() - 1_int64
      position = flat_offset(borrowed%shape, borrowed%strides, borrowed%offset, i0)
      array%data(i0 + 1_int64) = merge(0_int8, 1_int8, boolean_value(borrowed, position))
    end do
  end function logical_not_bool

  function boolean_binary(lhs, rhs, operation, status) result(array)
    class(*), target, intent(in) :: lhs, rhs
    character(len=*), intent(in) :: operation
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: array
    type(operand) :: left, right
    type(broadcast_plan) :: plan
    type(frumpy_status) :: local_status
    integer(int64) :: i0, lp, rp, li, ri
    integer(int32) :: relation
    real(real64) :: lr, rr
    logical :: value, unordered

    call bind_operand(lhs, left, local_status)
    if (local_status%is_ok()) call bind_operand(rhs, right, local_status)
    if (index(operation, 'logical_') == 1 .and. local_status%is_ok()) then
      if (left%dtype_id /= FRUMPY_DTYPE_BOOL .or. right%dtype_id /= FRUMPY_DTYPE_BOOL) &
        call set_status(local_status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
          "logical operands require bool")
    end if
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    plan = broadcast_plan_from_metadata(left%shape, left%strides, &
      right%shape, right%strides, local_status)
    if (local_status%is_ok()) array = owned_descriptor_bool(plan%shape, status=local_status)
    if (present(status)) status = local_status
    if (local_status%is_failure()) return
    do i0 = 0_int64, array%size() - 1_int64
      lp = flat_offset(plan%shape, plan%lhs_strides, left%offset, i0)
      rp = flat_offset(plan%shape, plan%rhs_strides, right%offset, i0)
      relation = 0_int32
      unordered = .false.
      if (max(left%dtype_id, right%dtype_id) <= FRUMPY_DTYPE_I64) then
        li = integer_value(left, lp)
        ri = integer_value(right, rp)
        if (li < ri) relation = -1_int32
        if (li > ri) relation = 1_int32
      else
        ! Float32/bool comparisons are exact when widened; integer/float pairs promote to r64.
        lr = real64_value(left, lp)
        rr = real64_value(right, rp)
        unordered = ieee_is_nan(lr) .or. ieee_is_nan(rr)
        if (.not. unordered) then
          if (lr < rr) relation = -1_int32
          if (lr > rr) relation = 1_int32
        end if
      end if
      value = .false.
      select case (operation)
      case ('equal')
        value = .not. unordered .and. relation == 0_int32
      case ('not_equal')
        value = unordered .or. relation /= 0_int32
      case ('less')
        value = .not. unordered .and. relation < 0_int32
      case ('less_equal')
        value = .not. unordered .and. relation <= 0_int32
      case ('greater')
        value = .not. unordered .and. relation > 0_int32
      case ('greater_equal')
        value = .not. unordered .and. relation >= 0_int32
      case ('logical_and')
        value = boolean_value(left, lp) .and. boolean_value(right, rp)
      case ('logical_or')
        value = boolean_value(left, lp) .or. boolean_value(right, rp)
      case ('logical_xor')
        value = boolean_value(left, lp) .neqv. boolean_value(right, rp)
      end select
      array%data(i0 + 1_int64) = merge(1_int8, 0_int8, value)
    end do
  end function boolean_binary
end module frumpy_comparisons
