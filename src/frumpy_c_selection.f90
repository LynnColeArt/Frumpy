!> C gather and sequence joining, with retained native input descriptors.
module frumpy_c_selection
  use iso_c_binding, only: c_ptr, c_int32_t, c_int64_t, c_f_pointer, c_associated
  use iso_fortran_env, only: int32, int64
  use frumpy_c_handles, only: handle_slot, lookup, new_array_slot, publish, output_pointer
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_ALLOCATION_FAILED
  use frumpy_operands, only: descriptor_dtype
  use frumpy, only: ndarray_r64, take_r64, concatenate_r64, stack_r64
  implicit none
  private
contains
  integer(c_int32_t) function take(source, indices, count, axis, output) &
      bind(C, name="frumpy_take") result(code)
    integer(c_int64_t), value :: source, count
    integer(c_int32_t), value :: axis
    type(c_ptr), value :: indices
    type(c_ptr), value :: output
    integer(c_int64_t), pointer :: out
    type(handle_slot), pointer :: slot, input
    type(frumpy_status) :: status
    integer(c_int64_t), pointer :: buffer(:)
    integer(int64), target :: empty(0)

    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    input => lookup(source, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_UNSUPPORTED_DTYPE
    if (descriptor_dtype(input%array) /= 5) return
    code = FRUMPY_STATUS_INVALID_SHAPE
    if (count < 0) return
    if (count > 0 .and. .not. c_associated(indices)) return
    buffer => empty
    if (count > 0) call c_f_pointer(indices, buffer, [count])
    call new_array_slot(5_int32, slot, status)
    code = status%code
    if (status%is_failure()) return
    select type (a => input%array)
    type is (ndarray_r64)
      select type (b => slot%array)
      type is (ndarray_r64)
        b = take_r64(a, buffer, axis, status)
      end select
    end select
    call publish(slot, out, status)
    code = status%code
  end function take
  integer(c_int32_t) function join(stack, sources, count, axis, output) &
      bind(C, name="frumpy_join") result(code)
    integer(c_int32_t), value :: stack, count, axis
    type(c_ptr), value :: sources, output
    integer(c_int64_t), pointer :: out, ids(:)
    type(handle_slot), pointer :: input, slot
    type(ndarray_r64), allocatable :: arrays(:)
    type(frumpy_status) :: status
    integer(int32) :: i, alloc_stat

    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_INVALID_SHAPE
    if (count <= 0 .or. .not. c_associated(sources)) return
    if (stack < 0 .or. stack > 1) return
    call c_f_pointer(sources, ids, [count])
    allocate(arrays(count), stat=alloc_stat)
    code = FRUMPY_STATUS_ALLOCATION_FAILED
    if (alloc_stat /= 0) return
    do i = 1, count
      input => lookup(ids(i), 1_int32, status)
      if (status%is_failure()) exit
      if (descriptor_dtype(input%array) /= 5) then
        call set_status(status, FRUMPY_STATUS_UNSUPPORTED_DTYPE)
        exit
      end if
      select type (a => input%array)
      type is (ndarray_r64)
        call arrays(i)%share_from(a, status)
      end select
      if (status%is_failure()) exit
    end do
    nullify(slot)
    if (status%is_ok()) call new_array_slot(5_int32, slot, status)
    if (status%is_ok()) then
      select type (a => slot%array)
      type is (ndarray_r64)
        if (stack == 1) then
          a = stack_r64(arrays, axis, status)
        else
          a = concatenate_r64(arrays, axis, status)
        end if
      end select
    end if
    ! Descriptor arrays use explicit element-wise lifetime management.
    do i = 1, count
      call arrays(i)%release()
    end do
    call publish(slot, out, status)
    code = status%code
  end function join
end module frumpy_c_selection
