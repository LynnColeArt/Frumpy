!> Typed native reduction dispatch with explicit result dtypes.
module frumpy_c_reductions
  use iso_c_binding, only: c_ptr, c_int32_t, c_int64_t
  use iso_fortran_env, only: int32
  use frumpy_c_handles, only: handle_slot, lookup, new_array_slot, publish, output_pointer
  use frumpy_statuses, only: frumpy_status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    FRUMPY_STATUS_INVALID_SHAPE
  use frumpy_operands, only: descriptor_dtype, operand, bind_operand
  use frumpy, only: argmin, argmax
  use frumpy, only: ndarray_bool, all_bool, any_bool
  use frumpy, only: ndarray_i32, sum_i32, prod_i32, min_i32, max_i32, mean_i32
  use frumpy, only: ndarray_i64, sum_i64, prod_i64, min_i64, max_i64, mean_i64
  use frumpy, only: ndarray_r32, sum_r32, prod_r32, min_r32, max_r32, mean_r32
  use frumpy, only: ndarray_r64, sum_r64, prod_r64, min_r64, max_r64, mean_r64
  implicit none
  private
contains
  integer(c_int32_t) function reduce(operation, source, has_axis, axis, keepdims, output) &
      bind(C, name="frumpy_reduce") result(code)
    integer(c_int64_t), value :: source
    integer(c_int32_t), value :: operation, has_axis, axis, keepdims
    type(c_ptr), value :: output
    integer(c_int64_t), pointer :: out
    type(handle_slot), pointer :: input, slot
    type(frumpy_status) :: status
    integer(int32), pointer :: optional_axis
    integer(int32), target :: normalized_axis
    type(operand) :: borrowed
    integer(int32) :: dtype, result_dtype

    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    input => lookup(source, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_INVALID_SHAPE
    if (has_axis < 0 .or. has_axis > 1 .or. keepdims < 0 .or. keepdims > 1) return
    nullify(optional_axis)
    if (operation == 8 .or. operation == 9) then
      ! Pass the original axis: native planning validates and normalizes exactly once.
      if (has_axis == 1) then
        normalized_axis = axis
        optional_axis => normalized_axis
      end if
      call new_array_slot(3_int32, slot, status)
      code = status%code
      if (status%is_failure()) return
      select type (b => slot%array)
      type is (ndarray_i64)
        if (operation == 8) then
          b = argmin(input%array, optional_axis, keepdims == 1, status)
        else
          b = argmax(input%array, optional_axis, keepdims == 1, status)
        end if
      end select
      call publish(slot, out, status)
      code = status%code
      return
    end if
    if (has_axis == 1) then
      call bind_operand(input%array, borrowed, status)
      code = status%code
      if (status%is_failure()) return
      normalized_axis = axis
      if (axis < 0) normalized_axis = axis + size(borrowed%shape)
      optional_axis => normalized_axis
    end if
    dtype = descriptor_dtype(input%array)
    code = FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR
    if (dtype == 1) then
      if (operation < 6 .or. operation > 7) return
    else
      if (operation < 1 .or. operation > 5) return
    end if
    result_dtype = dtype
    if (dtype == 2 .and. operation <= 2) result_dtype = 3_int32
    if ((dtype == 2 .or. dtype == 3) .and. operation == 5) result_dtype = 5_int32
    call new_array_slot(result_dtype, slot, status)
    code = status%code
    if (status%is_failure()) return
    select type (a => input%array)
    type is (ndarray_bool)
      select case (operation)
      case (6)
        select type (b => slot%array)
        type is (ndarray_bool)
          b = all_bool(a, optional_axis, keepdims == 1, status)
        end select
      case (7)
        select type (b => slot%array)
        type is (ndarray_bool)
          b = any_bool(a, optional_axis, keepdims == 1, status)
        end select
      end select
    type is (ndarray_i32)
      select case (operation)
      case (1)
        select type (b => slot%array)
        type is (ndarray_i64)
          b = sum_i32(a, optional_axis, keepdims == 1, status)
        end select
      case (2)
        select type (b => slot%array)
        type is (ndarray_i64)
          b = prod_i32(a, optional_axis, keepdims == 1, status)
        end select
      case (3)
        select type (b => slot%array)
        type is (ndarray_i32)
          b = min_i32(a, optional_axis, keepdims == 1, status)
        end select
      case (4)
        select type (b => slot%array)
        type is (ndarray_i32)
          b = max_i32(a, optional_axis, keepdims == 1, status)
        end select
      case (5)
        select type (b => slot%array)
        type is (ndarray_r64)
          b = mean_i32(a, optional_axis, keepdims == 1, status)
        end select
      end select
    type is (ndarray_i64)
      select case (operation)
      case (1)
        select type (b => slot%array)
        type is (ndarray_i64)
          b = sum_i64(a, optional_axis, keepdims == 1, status)
        end select
      case (2)
        select type (b => slot%array)
        type is (ndarray_i64)
          b = prod_i64(a, optional_axis, keepdims == 1, status)
        end select
      case (3)
        select type (b => slot%array)
        type is (ndarray_i64)
          b = min_i64(a, optional_axis, keepdims == 1, status)
        end select
      case (4)
        select type (b => slot%array)
        type is (ndarray_i64)
          b = max_i64(a, optional_axis, keepdims == 1, status)
        end select
      case (5)
        select type (b => slot%array)
        type is (ndarray_r64)
          b = mean_i64(a, optional_axis, keepdims == 1, status)
        end select
      end select
    type is (ndarray_r32)
      select case (operation)
      case (1)
        select type (b => slot%array)
        type is (ndarray_r32)
          b = sum_r32(a, optional_axis, keepdims == 1, status)
        end select
      case (2)
        select type (b => slot%array)
        type is (ndarray_r32)
          b = prod_r32(a, optional_axis, keepdims == 1, status)
        end select
      case (3)
        select type (b => slot%array)
        type is (ndarray_r32)
          b = min_r32(a, optional_axis, keepdims == 1, status)
        end select
      case (4)
        select type (b => slot%array)
        type is (ndarray_r32)
          b = max_r32(a, optional_axis, keepdims == 1, status)
        end select
      case (5)
        select type (b => slot%array)
        type is (ndarray_r32)
          b = mean_r32(a, optional_axis, keepdims == 1, status)
        end select
      end select
    type is (ndarray_r64)
      select case (operation)
      case (1)
        select type (b => slot%array)
        type is (ndarray_r64)
          b = sum_r64(a, optional_axis, keepdims == 1, status)
        end select
      case (2)
        select type (b => slot%array)
        type is (ndarray_r64)
          b = prod_r64(a, optional_axis, keepdims == 1, status)
        end select
      case (3)
        select type (b => slot%array)
        type is (ndarray_r64)
          b = min_r64(a, optional_axis, keepdims == 1, status)
        end select
      case (4)
        select type (b => slot%array)
        type is (ndarray_r64)
          b = max_r64(a, optional_axis, keepdims == 1, status)
        end select
      case (5)
        select type (b => slot%array)
        type is (ndarray_r64)
          b = mean_r64(a, optional_axis, keepdims == 1, status)
        end select
      end select
    end select
    call publish(slot, out, status)
    code = status%code
  end function reduce
end module frumpy_c_reductions
