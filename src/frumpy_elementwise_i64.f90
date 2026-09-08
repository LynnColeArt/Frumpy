!> Integer arithmetic with explicit modular overflow and NumPy broadcasting.
module frumpy_elementwise_i64
  use iso_fortran_env, only: int32, int64, real64
  use frumpy_integer_scalars, only: wrapped_add => wrapped_add_i64, &
    wrapped_subtract => wrapped_subtract_i64, wrapped_multiply => wrapped_multiply_i64
  use frumpy_broadcast, only: broadcast_plan, broadcast_plan_from_metadata
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64
  use frumpy_ndarray_r64, only: ndarray_r64, owned_descriptor_r64
  use frumpy_strides, only: storage_bounds_are_valid
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    FRUMPY_STATUS_ALLOCATION_FAILED
  implicit none
  private
  public :: add_i64, subtract_i64, multiply_i64, divide_i64

  integer(int32), parameter :: OP_ADD = 1_int32, OP_SUBTRACT = 2_int32, OP_MULTIPLY = 3_int32

contains

  function add_i64(lhs, rhs, status) result(array)
    type(ndarray_i64), intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array

    array = binary_i64(lhs, rhs, OP_ADD, status)
  end function add_i64

  function subtract_i64(lhs, rhs, status) result(array)
    type(ndarray_i64), intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array

    array = binary_i64(lhs, rhs, OP_SUBTRACT, status)
  end function subtract_i64

  function multiply_i64(lhs, rhs, status) result(array)
    type(ndarray_i64), intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array

    array = binary_i64(lhs, rhs, OP_MULTIPLY, status)
  end function multiply_i64

  function binary_i64(lhs, rhs, operation, status) result(array)
    type(ndarray_i64), intent(in) :: lhs, rhs
    integer(int32), intent(in) :: operation
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array
    type(broadcast_plan) :: plan
    type(frumpy_status) :: local_status
    integer(int64), allocatable :: index0(:)
    integer(int64) :: item1, lhs_position, rhs_position
    integer(int32) :: dim1

    call prepare_binary(lhs, rhs, plan, index0, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    array = owned_descriptor_i64(plan%shape, status=local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    do item1 = 1_int64, array%size()
      lhs_position = lhs%offset + sum(index0 * plan%lhs_strides)
      rhs_position = rhs%offset + sum(index0 * plan%rhs_strides)
      select case (operation)
      case (OP_ADD)
        array%data(item1) = wrapped_add(lhs%data(lhs_position), rhs%data(rhs_position))
      case (OP_SUBTRACT)
        array%data(item1) = wrapped_subtract(lhs%data(lhs_position), rhs%data(rhs_position))
      case (OP_MULTIPLY)
        array%data(item1) = wrapped_multiply(lhs%data(lhs_position), rhs%data(rhs_position))
      end select
      do dim1 = plan%rank, 1_int32, -1_int32
        index0(dim1) = index0(dim1) + 1_int64
        if (index0(dim1) < plan%shape(dim1)) exit
        index0(dim1) = 0_int64
      end do
    end do
    if (present(status)) call set_status(status, FRUMPY_STATUS_OK)
  end function binary_i64

  function divide_i64(lhs, rhs, status) result(array)
    type(ndarray_i64), intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(broadcast_plan) :: plan
    type(frumpy_status) :: local_status
    integer(int64), allocatable :: index0(:)
    integer(int64) :: item1, lhs_position, rhs_position
    integer(int32) :: dim1

    call prepare_binary(lhs, rhs, plan, index0, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    array = owned_descriptor_r64(plan%shape, status=local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    do item1 = 1_int64, array%size()
      lhs_position = lhs%offset + sum(index0 * plan%lhs_strides)
      rhs_position = rhs%offset + sum(index0 * plan%rhs_strides)
      array%data(item1) = real(lhs%data(lhs_position), real64) / &
        real(rhs%data(rhs_position), real64)
      do dim1 = plan%rank, 1_int32, -1_int32
        index0(dim1) = index0(dim1) + 1_int64
        if (index0(dim1) < plan%shape(dim1)) exit
        index0(dim1) = 0_int64
      end do
    end do
    if (present(status)) call set_status(status, FRUMPY_STATUS_OK)
  end function divide_i64

  subroutine prepare_binary(lhs, rhs, plan, index0, status)
    type(ndarray_i64), intent(in) :: lhs, rhs
    type(broadcast_plan), intent(out) :: plan
    integer(int64), allocatable, intent(out) :: index0(:)
    type(frumpy_status), intent(out) :: status
    integer(int32) :: alloc_stat

    call validate_source(lhs, status)
    if (status%is_ok()) call validate_source(rhs, status)
    if (status%is_failure()) return
    plan = broadcast_plan_from_metadata(lhs%shape, lhs%strides, rhs%shape, rhs%strides, status)
    if (status%is_failure()) return
    allocate(index0(plan%rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "integer broadcast index allocation failed")
      return
    end if
    index0 = 0_int64
  end subroutine prepare_binary

  subroutine validate_source(source, status)
    type(ndarray_i64), intent(in) :: source
    type(frumpy_status), intent(out) :: status

    if (.not. source%has_storage()) then
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "integer arithmetic requires storage")
      return
    end if
    call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
      "invalid integer metadata or reachable storage")
    if (.not. allocated(source%shape) .or. .not. allocated(source%strides)) return
    if (source%rank /= size(source%shape)) return
    if (.not. storage_bounds_are_valid(source%shape, source%strides, source%offset, &
        source%storage_size())) return
    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine validate_source

end module frumpy_elementwise_i64
