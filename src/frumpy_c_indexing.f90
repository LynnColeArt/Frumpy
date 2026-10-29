!> C mask selection, broadcast where and staged assignment.
module frumpy_c_indexing
  use iso_c_binding, only: c_ptr, c_int32_t, c_int64_t, c_f_pointer, c_associated
  use iso_fortran_env, only: int32, int64
  use frumpy_c_handles, only: handle_slot, lookup, new_array_slot, publish, output_pointer
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_ALLOCATION_FAILED
  use frumpy_operands, only: descriptor_dtype
  use frumpy, only: ndarray_bool, ndarray_r64, ndarray_i64, mask_select_r64, &
    assign_r64, nonzero_bool
  use frumpy, only: ndarray_i32, ndarray_r32, where_native => where
  implicit none
  private
contains
  integer(c_int32_t) function where(condition, lhs, rhs, output) &
      bind(C, name="frumpy_where") result(code)
    integer(c_int64_t), value :: condition, lhs, rhs
    type(c_ptr), value :: output
    integer(c_int64_t), pointer :: out
    type(handle_slot), pointer :: slot, mask, left, right
    type(frumpy_status) :: status
    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    mask => lookup(condition, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_UNSUPPORTED_DTYPE
    if (descriptor_dtype(mask%array) /= 1) return
    left => lookup(lhs, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_UNSUPPORTED_DTYPE
    right => lookup(rhs, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_UNSUPPORTED_DTYPE
    if (descriptor_dtype(right%array) /= descriptor_dtype(left%array)) return
    call new_array_slot(descriptor_dtype(left%array), slot, status)
    code = status%code
    if (status%is_failure()) return
    select type (m => mask%array)
    type is (ndarray_bool)
      select type (a => left%array)
      type is (ndarray_bool)
        select type (b => right%array)
        type is (ndarray_bool)
          select type (c => slot%array)
          type is (ndarray_bool)
            c = where_native(m, a, b, status)
          end select
        end select
      type is (ndarray_i32)
        select type (b => right%array)
        type is (ndarray_i32)
          select type (c => slot%array)
          type is (ndarray_i32)
            c = where_native(m, a, b, status)
          end select
        end select
      type is (ndarray_i64)
        select type (b => right%array)
        type is (ndarray_i64)
          select type (c => slot%array)
          type is (ndarray_i64)
            c = where_native(m, a, b, status)
          end select
        end select
      type is (ndarray_r32)
        select type (b => right%array)
        type is (ndarray_r32)
          select type (c => slot%array)
          type is (ndarray_r32)
            c = where_native(m, a, b, status)
          end select
        end select
      type is (ndarray_r64)
        select type (b => right%array)
        type is (ndarray_r64)
          select type (c => slot%array)
          type is (ndarray_r64)
            c = where_native(m, a, b, status)
          end select
        end select
      end select
    end select
    call publish(slot, out, status)
    code = status%code
  end function where
  integer(c_int32_t) function mask_select(source, mask, output) &
      bind(C, name="frumpy_mask_select") result(code)
    integer(c_int64_t), value :: source, mask
    type(c_ptr), value :: output
    integer(c_int64_t), pointer :: out
    type(handle_slot), pointer :: slot, input, condition
    type(frumpy_status) :: status
    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    input => lookup(source, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_UNSUPPORTED_DTYPE
    if (descriptor_dtype(input%array) /= 5) return
    condition => lookup(mask, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_UNSUPPORTED_DTYPE
    if (descriptor_dtype(condition%array) /= 1) return
    call new_array_slot(5_int32, slot, status)
    code = status%code
    if (status%is_failure()) return
    select type (a => input%array)
    type is (ndarray_r64)
      select type (m => condition%array)
      type is (ndarray_bool)
        select type (b => slot%array)
        type is (ndarray_r64)
          b = mask_select_r64(a, m, status)
        end select
      end select
    end select
    call publish(slot, out, status)
    code = status%code
  end function mask_select
  integer(c_int32_t) function flatnonzero(source, output) &
      bind(C, name="frumpy_flatnonzero") result(code)
    integer(c_int64_t), value :: source
    type(c_ptr), value :: output
    integer(c_int64_t), pointer :: out
    type(handle_slot), pointer :: slot, input
    type(frumpy_status) :: status
    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    input => lookup(source, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_UNSUPPORTED_DTYPE
    if (descriptor_dtype(input%array) /= 1) return
    call new_array_slot(3_int32, slot, status)
    code = status%code
    if (status%is_failure()) return
    select type (a => input%array)
    type is (ndarray_bool)
      select type (b => slot%array)
      type is (ndarray_i64)
        b = nonzero_bool(a, status)
      end select
    end select
    call publish(slot, out, status)
    code = status%code
  end function flatnonzero
  integer(c_int32_t) function assign(target, values) bind(C, name="frumpy_assign") result(code)
    integer(c_int64_t), value :: target, values
    type(handle_slot), pointer :: destination, input
    type(frumpy_status) :: status

    destination => lookup(target, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    input => lookup(values, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_UNSUPPORTED_DTYPE
    if (descriptor_dtype(destination%array) /= 5 .or. descriptor_dtype(input%array) /= 5) return
    ! Identical handles need no writes and must not alias native INTENT arguments.
    code = 0_c_int32_t
    if (target == values) return
    select type (a => destination%array)
    type is (ndarray_r64)
      select type (b => input%array)
      type is (ndarray_r64)
        call assign_r64(a, b, status)
      end select
    end select
    code = status%code
  end function assign
end module frumpy_c_indexing
