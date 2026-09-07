!> Float32 binary arithmetic with NumPy broadcasting and signed element strides.
module frumpy_elementwise_r32
  use iso_fortran_env, only: int32, int64, real32
  use frumpy_broadcast, only: broadcast_plan, broadcast_plan_from_metadata
  use frumpy_ndarray_r32, only: ndarray_r32, owned_descriptor_r32
  use frumpy_strides, only: storage_bounds_are_valid
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    FRUMPY_STATUS_ALLOCATION_FAILED
  implicit none
  private
  public :: add_r32, subtract_r32, multiply_r32, divide_r32

  integer(int32), parameter :: OP_ADD = 1_int32, OP_SUBTRACT = 2_int32
  integer(int32), parameter :: OP_MULTIPLY = 3_int32, OP_DIVIDE = 4_int32

contains

  function add_r32(lhs, rhs, status) result(array)
    type(ndarray_r32), intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: array

    array = binary_r32(lhs, rhs, OP_ADD, status)
  end function add_r32

  function subtract_r32(lhs, rhs, status) result(array)
    type(ndarray_r32), intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: array

    array = binary_r32(lhs, rhs, OP_SUBTRACT, status)
  end function subtract_r32

  function multiply_r32(lhs, rhs, status) result(array)
    type(ndarray_r32), intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: array

    array = binary_r32(lhs, rhs, OP_MULTIPLY, status)
  end function multiply_r32

  function divide_r32(lhs, rhs, status) result(array)
    type(ndarray_r32), intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: array

    array = binary_r32(lhs, rhs, OP_DIVIDE, status)
  end function divide_r32

  function binary_r32(lhs, rhs, operation, status) result(array)
    type(ndarray_r32), intent(in) :: lhs, rhs
    integer(int32), intent(in) :: operation
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: array
    type(broadcast_plan) :: plan
    type(frumpy_status) :: local_status
    integer(int64), allocatable :: index0(:)
    integer(int64) :: item1, lhs_position, rhs_position
    integer(int32) :: dim1, alloc_stat

    call validate_source(lhs, local_status)
    if (local_status%is_ok()) call validate_source(rhs, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    plan = broadcast_plan_from_metadata(lhs%shape, lhs%strides, rhs%shape, &
      rhs%strides, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    allocate(index0(plan%rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(local_status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "float32 broadcast index allocation failed")
      if (present(status)) status = local_status
      return
    end if
    array = owned_descriptor_r32(plan%shape, status=local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    index0 = 0_int64
    do item1 = 1_int64, array%size()
      lhs_position = lhs%offset + sum(index0 * plan%lhs_strides)
      rhs_position = rhs%offset + sum(index0 * plan%rhs_strides)
      select case (operation)
      case (OP_ADD)
        array%data(item1) = lhs%data(lhs_position) + rhs%data(rhs_position)
      case (OP_SUBTRACT)
        array%data(item1) = lhs%data(lhs_position) - rhs%data(rhs_position)
      case (OP_MULTIPLY)
        array%data(item1) = lhs%data(lhs_position) * rhs%data(rhs_position)
      case (OP_DIVIDE)
        array%data(item1) = lhs%data(lhs_position) / rhs%data(rhs_position)
      end select
      do dim1 = plan%rank, 1_int32, -1_int32
        index0(dim1) = index0(dim1) + 1_int64
        if (index0(dim1) < plan%shape(dim1)) exit
        index0(dim1) = 0_int64
      end do
    end do
    if (present(status)) call set_status(status, FRUMPY_STATUS_OK)
  end function binary_r32

  subroutine validate_source(source, status)
    type(ndarray_r32), intent(in) :: source
    type(frumpy_status), intent(out) :: status

    if (.not. source%has_storage()) then
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "float32 arithmetic requires source storage")
      return
    end if
    call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
      "float32 source metadata or reachable storage is invalid")
    if (.not. allocated(source%shape) .or. .not. allocated(source%strides)) return
    if (source%rank /= size(source%shape)) return
    if (.not. storage_bounds_are_valid(source%shape, source%strides, source%offset, &
        source%storage_size())) return
    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine validate_source
end module frumpy_elementwise_r32
