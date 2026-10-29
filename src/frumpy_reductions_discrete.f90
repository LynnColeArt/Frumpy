!> Integer and boolean reductions with explicit result types and modular accumulators.
module frumpy_reductions_discrete
  use iso_fortran_env, only: int8, int32, int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use frumpy_operands, only: operand, bind_operand, integer_value, boolean_value, descriptor_dtype
  use frumpy_dtypes, only: dtype_byte_size
  use frumpy_integer_scalars, only: wrapped_add_i64, wrapped_multiply_i64
  use frumpy_reduction_plans, only: reduction_plan, plan_reduction
  use frumpy_strides, only: flat_offset
  use frumpy_ndarray_bool, only: ndarray_bool, owned_descriptor_bool
  use frumpy_ndarray_i32, only: ndarray_i32, owned_descriptor_i32
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64
  use frumpy_ndarray_r64, only: ndarray_r64, owned_descriptor_r64
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_OVERFLOW, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR
  implicit none
  private
  public :: sum_i32, prod_i32, min_i32, max_i32, mean_i32
  public :: sum_i64, prod_i64, min_i64, max_i64, mean_i64
  public :: all_bool, any_bool
contains
  function sum_i32(source, axis0, keepdims, status) result(array)
    type(ndarray_i32), target, intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array

    call reduce_discrete(source, array, 'sum', axis0, keepdims, status)
  end function sum_i32

  function prod_i32(source, axis0, keepdims, status) result(array)
    type(ndarray_i32), target, intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array

    call reduce_discrete(source, array, 'prod', axis0, keepdims, status)
  end function prod_i32

  function min_i32(source, axis0, keepdims, status) result(array)
    type(ndarray_i32), target, intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i32) :: array

    call reduce_discrete(source, array, 'min', axis0, keepdims, status)
  end function min_i32

  function max_i32(source, axis0, keepdims, status) result(array)
    type(ndarray_i32), target, intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i32) :: array

    call reduce_discrete(source, array, 'max', axis0, keepdims, status)
  end function max_i32

  function mean_i32(source, axis0, keepdims, status) result(array)
    type(ndarray_i32), target, intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    call reduce_discrete(source, array, 'mean', axis0, keepdims, status)
  end function mean_i32

  function sum_i64(source, axis0, keepdims, status) result(array)
    type(ndarray_i64), target, intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array

    call reduce_discrete(source, array, 'sum', axis0, keepdims, status)
  end function sum_i64

  function prod_i64(source, axis0, keepdims, status) result(array)
    type(ndarray_i64), target, intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array

    call reduce_discrete(source, array, 'prod', axis0, keepdims, status)
  end function prod_i64

  function min_i64(source, axis0, keepdims, status) result(array)
    type(ndarray_i64), target, intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array

    call reduce_discrete(source, array, 'min', axis0, keepdims, status)
  end function min_i64

  function max_i64(source, axis0, keepdims, status) result(array)
    type(ndarray_i64), target, intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array

    call reduce_discrete(source, array, 'max', axis0, keepdims, status)
  end function max_i64

  function mean_i64(source, axis0, keepdims, status) result(array)
    type(ndarray_i64), target, intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    call reduce_discrete(source, array, 'mean', axis0, keepdims, status)
  end function mean_i64

  function all_bool(source, axis0, keepdims, status) result(array)
    type(ndarray_bool), target, intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: array

    call reduce_discrete(source, array, 'all', axis0, keepdims, status)
  end function all_bool

  function any_bool(source, axis0, keepdims, status) result(array)
    type(ndarray_bool), target, intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: array

    call reduce_discrete(source, array, 'any', axis0, keepdims, status)
  end function any_bool

  subroutine reduce_discrete(source, result, operation, axis0, keepdims, status)
    class(*), target, intent(in) :: source
    class(*), intent(inout) :: result
    character(len=*), intent(in) :: operation
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(operand) :: borrowed
    type(reduction_plan) :: plan
    type(frumpy_status) :: local_status
    integer(int64) :: i0, base, integral, bytes
    real(real64) :: average
    logical :: truth

    call bind_operand(source, borrowed, local_status)
    if (local_status%is_ok()) plan = plan_reduction(borrowed%shape, borrowed%strides, &
      axis0, keepdims, operation /= 'mean', local_status)
    if (local_status%is_ok()) then
      if (plan%reduced_count == 0_int64 .and. (operation == 'min' .or. operation == 'max')) &
        call set_status(local_status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, "empty min/max reduction")
      bytes = dtype_byte_size(descriptor_dtype(result))
      if (plan%count > huge(1_int64) / bytes) &
        call set_status(local_status, FRUMPY_STATUS_OVERFLOW, "reduction result bytes overflow")
    end if
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    select type (result)
    type is (ndarray_bool)
      result = owned_descriptor_bool(plan%shape(:plan%rank), status=local_status)
      if (local_status%is_ok()) then
        do i0 = 0_int64, plan%count - 1_int64
          base = flat_offset(plan%shape(:plan%rank), plan%strides(:plan%rank), borrowed%offset, i0)
          call reduce_one(borrowed, plan, base, operation, integral, average, truth)
          result%data(i0 + 1_int64) = merge(1_int8, 0_int8, truth)
        end do
      end if
    type is (ndarray_i32)
      result = owned_descriptor_i32(plan%shape(:plan%rank), status=local_status)
      if (local_status%is_ok()) then
        do i0 = 0_int64, plan%count - 1_int64
          base = flat_offset(plan%shape(:plan%rank), plan%strides(:plan%rank), borrowed%offset, i0)
          call reduce_one(borrowed, plan, base, operation, integral, average, truth)
          result%data(i0 + 1_int64) = int(integral, int32)
        end do
      end if
    type is (ndarray_i64)
      result = owned_descriptor_i64(plan%shape(:plan%rank), status=local_status)
      if (local_status%is_ok()) then
        do i0 = 0_int64, plan%count - 1_int64
          base = flat_offset(plan%shape(:plan%rank), plan%strides(:plan%rank), borrowed%offset, i0)
          call reduce_one(borrowed, plan, base, operation, integral, average, truth)
          result%data(i0 + 1_int64) = integral
        end do
      end if
    type is (ndarray_r64)
      result = owned_descriptor_r64(plan%shape(:plan%rank), status=local_status)
      if (local_status%is_ok()) then
        do i0 = 0_int64, plan%count - 1_int64
          base = flat_offset(plan%shape(:plan%rank), plan%strides(:plan%rank), borrowed%offset, i0)
          call reduce_one(borrowed, plan, base, operation, integral, average, truth)
          result%data(i0 + 1_int64) = average
        end do
      end if
    end select
    if (present(status)) status = local_status
  end subroutine reduce_discrete

  subroutine reduce_one(source, plan, base, operation, integral, average, truth)
    type(operand), intent(in) :: source
    type(reduction_plan), intent(in) :: plan
    integer(int64), intent(in) :: base
    character(len=*), intent(in) :: operation
    integer(int64), intent(out) :: integral
    real(real64), intent(out) :: average
    logical, intent(out) :: truth
    integer(int64) :: j0, position, value

    integral = 0_int64
    if (operation == 'prod') integral = 1_int64
    average = 0.0_real64
    truth = operation == 'all'
    do j0 = 0_int64, plan%reduced_count - 1_int64
      position = flat_offset(plan%reduced_shape(:plan%reduced_rank), &
        plan%reduced_strides(:plan%reduced_rank), base, j0)
      value = integer_value(source, position)
      select case (operation)
      case ('sum')
        integral = wrapped_add_i64(integral, value)
      case ('prod')
        integral = wrapped_multiply_i64(integral, value)
      case ('min')
        if (j0 == 0_int64) integral = value
        integral = min(integral, value)
      case ('max')
        if (j0 == 0_int64) integral = value
        integral = max(integral, value)
      case ('mean')
        average = average + real(value, real64)
      case ('all')
        truth = truth .and. boolean_value(source, position)
      case ('any')
        truth = truth .or. boolean_value(source, position)
      end select
    end do
    if (operation == 'mean') then
      if (plan%reduced_count == 0_int64) then
        average = ieee_value(average, ieee_quiet_nan)
      else
        average = average / real(plan%reduced_count, real64)
      end if
    end if
  end subroutine reduce_one
end module frumpy_reductions_discrete
