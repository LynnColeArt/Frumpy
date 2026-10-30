!> C mask selection, broadcast where and staged assignment.
module frumpy_c_indexing
  use iso_c_binding, only: c_ptr, c_int32_t, c_int64_t, c_f_pointer, c_associated
  use frumpy_constants, only: FRUMPY_MAX_RANK
  use frumpy_c_handles, only: release_handle
  use frumpy_coordinates, only: argwhere_native => argwhere, nonzero_native => nonzero, release_nonzero
  use iso_fortran_env, only: int32, int64
  use frumpy_c_handles, only: handle_slot, lookup, new_array_slot, publish, output_pointer
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_ALLOCATION_FAILED
  use frumpy_operands, only: descriptor_dtype, operand, bind_operand
  use frumpy, only: ndarray_bool, ndarray_r64, ndarray_i64, &
    nonzero_bool
  use frumpy, only: ndarray_i32, ndarray_r32, where_native => where
  use frumpy_indexing, only: mask_select_native => mask_select, assign_native => assign, &
    mask_assign_native => mask_assign
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
    condition => lookup(mask, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_UNSUPPORTED_DTYPE
    if (descriptor_dtype(condition%array) /= 1) return
    call new_array_slot(descriptor_dtype(input%array), slot, status)
    code = status%code
    if (status%is_failure()) return
    select type (m => condition%array)
    type is (ndarray_bool)
      select type (a => input%array)
      type is (ndarray_bool)
        select type (b => slot%array)
        type is (ndarray_bool)
          b = mask_select_native(a, m, status)
        end select
      type is (ndarray_i32)
        select type (b => slot%array)
        type is (ndarray_i32)
          b = mask_select_native(a, m, status)
        end select
      type is (ndarray_i64)
        select type (b => slot%array)
        type is (ndarray_i64)
          b = mask_select_native(a, m, status)
        end select
      type is (ndarray_r32)
        select type (b => slot%array)
        type is (ndarray_r32)
          b = mask_select_native(a, m, status)
        end select
      type is (ndarray_r64)
        select type (b => slot%array)
        type is (ndarray_r64)
          b = mask_select_native(a, m, status)
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
    ! Preserve the established no-allocation identical-handle shortcut.
    code = 0_c_int32_t
    if (target == values) return
    call assign_native(destination%array, input%array, status)
    code = status%code
  end function assign
  integer(c_int32_t) function mask_assign(target, mask, values) &
      bind(C, name="frumpy_mask_assign") result(code)
    integer(c_int64_t), value :: target, mask, values
    type(handle_slot), pointer :: destination, condition, input
    type(frumpy_status) :: status

    destination => lookup(target, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    condition => lookup(mask, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_UNSUPPORTED_DTYPE
    if (descriptor_dtype(condition%array) /= 1) return
    input => lookup(values, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    select type (m => condition%array)
    type is (ndarray_bool)
      call mask_assign_native(destination%array, m, input%array, status)
    end select
    code = status%code
  end function mask_assign
  integer(c_int32_t) function argwhere(source, output) bind(C, name="frumpy_argwhere") result(code)
    integer(c_int64_t), value :: source
    type(c_ptr), value :: output
    integer(c_int64_t), pointer :: out
    type(handle_slot), pointer :: input, slot
    type(frumpy_status) :: status

    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    input => lookup(source, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    call new_array_slot(3_int32, slot, status)
    code = status%code
    if (status%is_failure()) return
    select type (a => slot%array)
    type is (ndarray_i64)
      a = argwhere_native(input%array, status)
    end select
    call publish(slot, out, status)
    code = status%code
  end function argwhere

  integer(c_int32_t) function nonzero(source, output, capacity) bind(C, name="frumpy_nonzero") result(code)
    integer(c_int64_t), value :: source
    type(c_ptr), value :: output
    integer(c_int32_t), value :: capacity
    integer(c_int64_t), pointer :: out(:)
    type(handle_slot), pointer :: input, slot
    type(ndarray_i64), allocatable :: axes(:)
    type(frumpy_status) :: status, cleanup
    integer(int32) :: dim1

    code = FRUMPY_STATUS_INVALID_SHAPE
    if (capacity < 0 .or. capacity > FRUMPY_MAX_RANK) return
    if (.not. c_associated(output)) return
    call c_f_pointer(output, out, [capacity])
    out = 0_c_int64_t
    input => lookup(source, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    ! Check caller capacity before scanning or allocating coordinate storage.
    block
      type(operand) :: borrowed
      call bind_operand(input%array, borrowed, status)
      if (status%is_ok()) then
        if (size(borrowed%shape) == 0 .or. size(borrowed%shape) > capacity) &
          call set_status(status, FRUMPY_STATUS_INVALID_SHAPE)
      end if
    end block
    code = status%code
    if (status%is_failure()) return
    call nonzero_native(input%array, axes, status)
    if (status%is_ok()) then
      do dim1 = 1, size(axes)
        call new_array_slot(3_int32, slot, status)
        if (status%is_failure()) exit
        select type (a => slot%array)
        type is (ndarray_i64)
          call a%share_from(axes(dim1), status)
        end select
        call publish(slot, out(dim1), status)
        if (status%is_failure()) exit
      end do
    end if
    call release_nonzero(axes)
    if (status%is_failure()) then
      do dim1 = 1, capacity
        if (out(dim1) /= 0_c_int64_t) call release_handle(out(dim1), cleanup)
      end do
      out = 0_c_int64_t
    end if
    code = status%code
  end function nonzero
end module frumpy_c_indexing
