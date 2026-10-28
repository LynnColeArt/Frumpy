!> Stable sorting and ordered search C entry points.
module frumpy_c_ordering
  use iso_c_binding, only: c_ptr, c_int32_t, c_int64_t, c_f_pointer, c_associated
  use iso_fortran_env, only: int32, int64
  use frumpy_c_handles, only: handle_slot, lookup, new_array_slot, publish, output_pointer
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_ALLOCATION_FAILED
  use frumpy_operands, only: descriptor_dtype
  use frumpy, only: ndarray_r64, ndarray_i64, searchsorted_r64
  use frumpy, only: ndarray_bool, ndarray_i32, ndarray_r32, sort_native => sort, argsort
  implicit none
  private
contains
  integer(c_int32_t) function sort(indices, source, axis, output) &
      bind(C, name="frumpy_sort") result(code)
    integer(c_int32_t), value :: indices, axis
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
    code = FRUMPY_STATUS_INVALID_SHAPE
    if (indices < 0 .or. indices > 1) return
    call new_array_slot(merge(3_int32,descriptor_dtype(input%array),indices == 1), slot, status)
    code = status%code
    if (status%is_failure()) return
    if (indices == 1) then
      select type (b => slot%array)
      type is (ndarray_i64)
        b = argsort(input%array,axis,status)
      end select
    else
      select type (a => input%array)
      type is (ndarray_bool)
        select type (b => slot%array)
        type is (ndarray_bool)
          b = sort_native(a,axis,status)
        end select
      type is (ndarray_i32)
        select type (b => slot%array)
        type is (ndarray_i32)
          b = sort_native(a,axis,status)
        end select
      type is (ndarray_i64)
        select type (b => slot%array)
        type is (ndarray_i64)
          b = sort_native(a,axis,status)
        end select
      type is (ndarray_r32)
        select type (b => slot%array)
        type is (ndarray_r32)
          b = sort_native(a,axis,status)
        end select
      type is (ndarray_r64)
        select type (b => slot%array)
        type is (ndarray_r64)
          b = sort_native(a,axis,status)
        end select
      end select
    end if
    call publish(slot, out, status)
    code = status%code
  end function sort
  integer(c_int32_t) function searchsorted(source, values, right, output) &
      bind(C, name="frumpy_searchsorted") result(code)
    integer(c_int64_t), value :: source, values
    integer(c_int32_t), value :: right
    type(c_ptr), value :: output
    integer(c_int64_t), pointer :: out
    type(handle_slot), pointer :: slot, input, queries
    type(frumpy_status) :: status
    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    input => lookup(source, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_UNSUPPORTED_DTYPE
    if (descriptor_dtype(input%array) /= 5) return
    queries => lookup(values, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_UNSUPPORTED_DTYPE
    if (descriptor_dtype(queries%array) /= 5) return
    code = FRUMPY_STATUS_INVALID_SHAPE
    if (right < 0 .or. right > 1) return
    call new_array_slot(3_int32, slot, status)
    code = status%code
    if (status%is_failure()) return
    select type (a => input%array)
    type is (ndarray_r64)
      select type (b => queries%array)
      type is (ndarray_r64)
        select type (c => slot%array)
        type is (ndarray_i64)
          c = searchsorted_r64(a, b, right == 1, status)
        end select
      end select
    end select
    call publish(slot, out, status)
    code = status%code
  end function searchsorted
end module frumpy_c_ordering
