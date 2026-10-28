!> First-occurrence index reductions; integer comparisons never pass through real64.
module frumpy_arg_reductions
  use iso_fortran_env, only: int32, int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
  use frumpy_operands, only: operand, bind_operand, integer_value, real64_value
  use frumpy_dtypes, only: FRUMPY_DTYPE_I64
  use frumpy_reduction_plans, only: reduction_plan, plan_reduction
  use frumpy_linear_arithmetic, only: linear_step
  use frumpy_strides, only: flat_offset
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_INVALID_SHAPE, &
    FRUMPY_STATUS_OVERFLOW
  implicit none
  private
  public :: argmin, argmax
contains
  function argmin(source, axis0, keepdims, status) result(array)
    class(*), target, intent(in) :: source
    integer(int32), optional, intent(in) :: axis0
    logical, optional, intent(in) :: keepdims
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i64) :: array

    array = arg_reduce(source, .false., axis0, keepdims, status)
  end function argmin

  function argmax(source, axis0, keepdims, status) result(array)
    class(*), target, intent(in) :: source
    integer(int32), optional, intent(in) :: axis0
    logical, optional, intent(in) :: keepdims
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i64) :: array

    array = arg_reduce(source, .true., axis0, keepdims, status)
  end function argmax

  function arg_reduce(source, maximum, axis0, keepdims, status) result(array)
    class(*), target, intent(in) :: source
    logical, intent(in) :: maximum
    integer(int32), optional, intent(in) :: axis0
    logical, optional, intent(in) :: keepdims
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i64) :: array
    type(operand) :: borrowed
    type(reduction_plan) :: plan
    type(frumpy_status) :: local
    integer(int64) :: i, base, step
    logical :: linear

    call bind_operand(source, borrowed, local)
    if (local%is_ok()) then
      plan = plan_reduction(borrowed%shape, borrowed%strides, axis0, keepdims, .true., local)
    end if
    if (local%is_ok()) then
      ! An empty reduced axis is invalid even when another axis makes the output empty.
      if (plan%reduced_count == 0_int64) then
        call set_status(local, FRUMPY_STATUS_INVALID_SHAPE, 'arg reduction axis has zero length')
      else if (plan%count > shiftr(huge(1_int64),3)) then
        call set_status(local, FRUMPY_STATUS_OVERFLOW, 'arg reduction result bytes overflow')
      end if
    end if
    if (local%is_ok()) array = owned_descriptor_i64(plan%shape(:plan%rank), status=local)
    if (present(status)) status = local
    if (local%is_failure()) return
    step = linear_step(plan%reduced_shape(:plan%reduced_rank), &
      plan%reduced_strides(:plan%reduced_rank), linear)
    do i = 0_int64, plan%count - 1_int64
      base = flat_offset(plan%shape(:plan%rank), plan%strides(:plan%rank), borrowed%offset, i)
      if (borrowed%dtype_id <= FRUMPY_DTYPE_I64) then
        array%data(i+1_int64) = integer_index(borrowed, plan, base, step, linear, maximum)
      else
        array%data(i+1_int64) = real_index(borrowed, plan, base, step, linear, maximum)
      end if
    end do
  end function arg_reduce

  function integer_index(source, plan, base, step, linear, maximum) result(index0)
    type(operand), intent(in) :: source
    type(reduction_plan), intent(in) :: plan
    integer(int64), intent(in) :: base, step
    logical, intent(in) :: linear, maximum
    integer(int64) :: index0, j, position, best, value

    index0 = 0_int64
    best = integer_value(source, base)
    do j = 1_int64, plan%reduced_count - 1_int64
      if (linear) then
        position = base + j * step
      else
        position = flat_offset(plan%reduced_shape(:plan%reduced_rank), &
          plan%reduced_strides(:plan%reduced_rank), base, j)
      end if
      value = integer_value(source, position)
      if ((maximum .and. value > best) .or. (.not. maximum .and. value < best)) then
        best = value
        index0 = j
      end if
    end do
  end function integer_index

  function real_index(source, plan, base, step, linear, maximum) result(index0)
    type(operand), intent(in) :: source
    type(reduction_plan), intent(in) :: plan
    integer(int64), intent(in) :: base, step
    logical, intent(in) :: linear, maximum
    integer(int64) :: index0, j, position
    real(real64) :: best, value

    index0 = 0_int64
    best = real64_value(source, base)
    if (ieee_is_nan(best)) return
    do j = 1_int64, plan%reduced_count - 1_int64
      if (linear) then
        position = base + j * step
      else
        position = flat_offset(plan%reduced_shape(:plan%reduced_rank), &
          plan%reduced_strides(:plan%reduced_rank), base, j)
      end if
      value = real64_value(source, position)
      if (ieee_is_nan(value)) then
        index0 = j
        return
      end if
      ! Strict comparisons preserve the first tie, including opposite signed zeros.
      if ((maximum .and. value > best) .or. (.not. maximum .and. value < best)) then
        best = value
        index0 = j
      end if
    end do
  end function real_index
end module frumpy_arg_reductions
