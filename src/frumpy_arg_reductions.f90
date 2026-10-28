!> First-occurrence index reductions; integer comparisons never pass through real64.
module frumpy_arg_reductions
  use iso_fortran_env, only: int8, int32, int64, real32, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
  use frumpy_operands, only: operand, bind_operand
  use frumpy_dtypes, only: FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_I32, FRUMPY_DTYPE_I64, &
    FRUMPY_DTYPE_R32, FRUMPY_DTYPE_R64
  use frumpy_constants, only: FRUMPY_MAX_RANK
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
      select case (borrowed%dtype_id)
      case (FRUMPY_DTYPE_BOOL)
        array%data(i+1_int64) = scan_bool(borrowed%values_bool, plan, base, step, linear, maximum)
      case (FRUMPY_DTYPE_I32)
        array%data(i+1_int64) = scan_i32(borrowed%values_i32, plan, base, step, linear, maximum)
      case (FRUMPY_DTYPE_I64)
        array%data(i+1_int64) = scan_i64(borrowed%values_i64, plan, base, step, linear, maximum)
      case (FRUMPY_DTYPE_R32)
        array%data(i+1_int64) = scan_r32(borrowed%values_r32, plan, base, step, linear, maximum)
      case (FRUMPY_DTYPE_R64)
        array%data(i+1_int64) = scan_r64(borrowed%values_r64, plan, base, step, linear, maximum)
      end select
    end do
  end function arg_reduce

  ! Advance only between valid elements. Resetting a completed dimension before
  ! carrying avoids constructing an out-of-bounds or overflowing sentinel offset.
  subroutine advance(plan, coordinates, position)
    type(reduction_plan), intent(in) :: plan
    integer(int64), intent(inout) :: coordinates(FRUMPY_MAX_RANK), position
    integer(int32) :: dim1

    do dim1 = plan%reduced_rank, 1_int32, -1_int32
      if (coordinates(dim1) < plan%reduced_shape(dim1)-1_int64) then
        coordinates(dim1) = coordinates(dim1)+1_int64
        position = position+plan%reduced_strides(dim1)
        return
      end if
      position = position-coordinates(dim1)*plan%reduced_strides(dim1)
      coordinates(dim1) = 0_int64
    end do
  end subroutine advance

  function scan_bool(values, plan, base, step, linear, maximum) result(index0)
    integer(int8), intent(in) :: values(:)
    type(reduction_plan), intent(in) :: plan
    integer(int64), intent(in) :: base, step
    logical, intent(in) :: linear, maximum
    integer(int64) :: index0, j, position, coordinates(FRUMPY_MAX_RANK)

    index0 = 0_int64
    position = base
    coordinates = 0_int64
    ! False is the absolute minimum and True the absolute maximum. Any nonzero
    ! native bool byte is True; stopping here also preserves the first tie.
    do j = 0_int64, plan%reduced_count-1_int64
      if ((values(position) /= 0_int8) .eqv. maximum) then
        index0 = j
        return
      end if
      if (j == plan%reduced_count-1_int64) exit
      if (linear) then
        position = position+step
      else
        call advance(plan, coordinates, position)
      end if
    end do
  end function scan_bool

  function scan_i32(values, plan, base, step, linear, maximum) result(index0)
    integer(int32), intent(in) :: values(:)
    type(reduction_plan), intent(in) :: plan
    integer(int64), intent(in) :: base, step
    logical, intent(in) :: linear, maximum
    integer(int64) :: index0, j, position, coordinates(FRUMPY_MAX_RANK)
    integer(int32) :: best, value

    index0 = 0_int64
    position = base
    coordinates = 0_int64
    best = values(position)
    do j = 1_int64, plan%reduced_count-1_int64
      if (linear) then
        position = position+step
      else
        call advance(plan, coordinates, position)
      end if
      value = values(position)
      if ((maximum .and. value > best) .or. (.not. maximum .and. value < best)) then
        best = value
        index0 = j
      end if
    end do
  end function scan_i32

  function scan_i64(values, plan, base, step, linear, maximum) result(index0)
    integer(int64), intent(in) :: values(:)
    type(reduction_plan), intent(in) :: plan
    integer(int64), intent(in) :: base, step
    logical, intent(in) :: linear, maximum
    integer(int64) :: index0, j, position, coordinates(FRUMPY_MAX_RANK)
    integer(int64) :: best, value

    index0 = 0_int64
    position = base
    coordinates = 0_int64
    best = values(position)
    do j = 1_int64, plan%reduced_count-1_int64
      if (linear) then
        position = position+step
      else
        call advance(plan, coordinates, position)
      end if
      value = values(position)
      if ((maximum .and. value > best) .or. (.not. maximum .and. value < best)) then
        best = value
        index0 = j
      end if
    end do
  end function scan_i64

  function scan_r32(values, plan, base, step, linear, maximum) result(index0)
    real(real32), intent(in) :: values(:)
    type(reduction_plan), intent(in) :: plan
    integer(int64), intent(in) :: base, step
    logical, intent(in) :: linear, maximum
    integer(int64) :: index0, j, position, coordinates(FRUMPY_MAX_RANK)
    real(real32) :: best, value

    index0 = 0_int64
    position = base
    coordinates = 0_int64
    best = values(position)
    if (ieee_is_nan(best)) return
    do j = 1_int64, plan%reduced_count-1_int64
      if (linear) then
        position = position+step
      else
        call advance(plan, coordinates, position)
      end if
      value = values(position)
      ! Infinity cannot terminate a floating scan: a later NaN must still win.
      if (ieee_is_nan(value)) then
        index0 = j
        return
      end if
      if ((maximum .and. value > best) .or. (.not. maximum .and. value < best)) then
        best = value
        index0 = j
      end if
    end do
  end function scan_r32

  function scan_r64(values, plan, base, step, linear, maximum) result(index0)
    real(real64), intent(in) :: values(:)
    type(reduction_plan), intent(in) :: plan
    integer(int64), intent(in) :: base, step
    logical, intent(in) :: linear, maximum
    integer(int64) :: index0, j, position, coordinates(FRUMPY_MAX_RANK)
    real(real64) :: best, value

    index0 = 0_int64
    position = base
    coordinates = 0_int64
    best = values(position)
    if (ieee_is_nan(best)) return
    do j = 1_int64, plan%reduced_count-1_int64
      if (linear) then
        position = position+step
      else
        call advance(plan, coordinates, position)
      end if
      value = values(position)
      ! Infinity cannot terminate a floating scan: a later NaN must still win.
      if (ieee_is_nan(value)) then
        index0 = j
        return
      end if
      if ((maximum .and. value > best) .or. (.not. maximum .and. value < best)) then
        best = value
        index0 = j
      end if
    end do
  end function scan_r64

end module frumpy_arg_reductions
