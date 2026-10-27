!> Shared one-axis/all-axis metadata plans for discrete reductions.
module frumpy_reduction_plans
  use iso_fortran_env, only: int32, int64
  use frumpy_constants, only: FRUMPY_MAX_RANK
  use frumpy_shape, only: element_count
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_INVALID_AXIS
  implicit none
  private
  public :: reduction_plan, plan_reduction
  type :: reduction_plan
    integer(int32) :: rank = 0_int32, reduced_rank = 0_int32
    integer(int64) :: shape(FRUMPY_MAX_RANK) = 0_int64
    integer(int64) :: strides(FRUMPY_MAX_RANK) = 0_int64
    integer(int64) :: reduced_shape(FRUMPY_MAX_RANK) = 0_int64
    integer(int64) :: reduced_strides(FRUMPY_MAX_RANK) = 0_int64
    integer(int64) :: count = 0_int64, reduced_count = 0_int64
  end type reduction_plan
contains
  !> Caller supplies validated source metadata. Explicit scalar axes are operation-dependent.
  function plan_reduction(shape, strides, axis0, keepdims, scalar_axis, status) result(plan)
    integer(int64), intent(in) :: shape(:), strides(:)
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    logical, intent(in) :: scalar_axis
    type(frumpy_status), intent(out) :: status
    type(reduction_plan) :: plan
    integer(int32) :: axis, source_rank, dim1
    logical :: reduce(FRUMPY_MAX_RANK), keep

    keep = .false.
    if (present(keepdims)) keep = keepdims
    source_rank = int(size(shape), int32)
    reduce = .true.
    if (present(axis0)) then
      axis = axis0
      if (source_rank == 0_int32 .and. scalar_axis .and. &
          (axis == 0_int32 .or. axis == -1_int32)) then
        reduce = .false.
      else
        if (axis < -source_rank .or. axis >= source_rank) then
          call set_status(status, FRUMPY_STATUS_INVALID_AXIS, "reduction axis out of bounds")
          return
        end if
        if (axis < 0_int32) axis = axis + source_rank
        reduce = .false.
        reduce(axis + 1_int32) = .true.
      end if
    end if
    do dim1 = 1_int32, source_rank
      if (reduce(dim1)) then
        plan%reduced_rank = plan%reduced_rank + 1_int32
        plan%reduced_shape(plan%reduced_rank) = shape(dim1)
        plan%reduced_strides(plan%reduced_rank) = strides(dim1)
        if (.not. keep) cycle
        plan%rank = plan%rank + 1_int32
        plan%shape(plan%rank) = 1_int64
        plan%strides(plan%rank) = 0_int64
      else
        plan%rank = plan%rank + 1_int32
        plan%shape(plan%rank) = shape(dim1)
        plan%strides(plan%rank) = strides(dim1)
      end if
    end do
    plan%count = element_count(plan%shape(:plan%rank), status)
    if (status%is_failure()) return
    if (plan%count == 0_int64) then
      ! No iteration needs the reduced product; retain only whether it is empty.
      plan%reduced_count = 1_int64
      if (any(plan%reduced_shape(:plan%reduced_rank) == 0_int64)) plan%reduced_count = 0_int64
    else
      plan%reduced_count = element_count(plan%reduced_shape(:plan%reduced_rank), status)
    end if
  end function plan_reduction
end module frumpy_reduction_plans
