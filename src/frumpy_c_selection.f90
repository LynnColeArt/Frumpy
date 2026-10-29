!> C gather and sequence joining, with retained native input descriptors.
module frumpy_c_selection
  use iso_c_binding, only: c_ptr, c_int32_t, c_int64_t, c_f_pointer, c_associated
  use iso_fortran_env, only: int32, int64
  use frumpy_c_handles, only: handle_slot, lookup, new_array_slot, publish, output_pointer
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_ALLOCATION_FAILED, FRUMPY_STATUS_OVERFLOW
  use frumpy_operands, only: descriptor_dtype
  use frumpy, only: ndarray_bool, ndarray_i32, ndarray_i64, ndarray_r32, ndarray_r64, &
    take_native => take, concatenate_native => concatenate, stack_native => stack
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
    code = FRUMPY_STATUS_INVALID_SHAPE
    if (count < 0) return
    code = FRUMPY_STATUS_OVERFLOW
    if (count > shiftr(huge(count), 3)) return
    code = FRUMPY_STATUS_INVALID_SHAPE
    if (count > 0 .and. .not. c_associated(indices)) return
    buffer => empty
    if (count > 0) call c_f_pointer(indices, buffer, [count])
    call new_array_slot(descriptor_dtype(input%array), slot, status)
    code = status%code
    if (status%is_failure()) return
    select type (a => input%array)
    type is (ndarray_bool)
      select type (b => slot%array)
      type is (ndarray_bool)
        b = take_native(a, buffer, axis, status)
      end select
    type is (ndarray_i32)
      select type (b => slot%array)
      type is (ndarray_i32)
        b = take_native(a, buffer, axis, status)
      end select
    type is (ndarray_i64)
      select type (b => slot%array)
      type is (ndarray_i64)
        b = take_native(a, buffer, axis, status)
      end select
    type is (ndarray_r32)
      select type (b => slot%array)
      type is (ndarray_r32)
        b = take_native(a, buffer, axis, status)
      end select
    type is (ndarray_r64)
      select type (b => slot%array)
      type is (ndarray_r64)
        b = take_native(a, buffer, axis, status)
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
    class(*), allocatable :: arrays(:)
    type(frumpy_status) :: status
    integer(int32) :: i, alloc_stat, dtype

    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_INVALID_SHAPE
    if (count <= 0 .or. .not. c_associated(sources)) return
    if (stack < 0 .or. stack > 1) return
    call c_f_pointer(sources, ids, [count])
    input => lookup(ids(1), 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    dtype = descriptor_dtype(input%array)
    select case (dtype)
    case (1)
      allocate(ndarray_bool :: arrays(count), stat=alloc_stat)
    case (2)
      allocate(ndarray_i32 :: arrays(count), stat=alloc_stat)
    case (3)
      allocate(ndarray_i64 :: arrays(count), stat=alloc_stat)
    case (4)
      allocate(ndarray_r32 :: arrays(count), stat=alloc_stat)
    case (5)
      allocate(ndarray_r64 :: arrays(count), stat=alloc_stat)
    case default
      code = FRUMPY_STATUS_UNSUPPORTED_DTYPE
      return
    end select
    code = FRUMPY_STATUS_ALLOCATION_FAILED
    if (alloc_stat /= 0) return
    do i = 1, count
      input => lookup(ids(i), 1_int32, status)
      if (status%is_failure()) exit
      if (descriptor_dtype(input%array) /= dtype) then
        call set_status(status, FRUMPY_STATUS_UNSUPPORTED_DTYPE)
        exit
      end if
      select type (a => input%array)
      type is (ndarray_bool)
        select type (b => arrays)
        type is (ndarray_bool)
          call b(i)%share_from(a, status)
        end select
      type is (ndarray_i32)
        select type (b => arrays)
        type is (ndarray_i32)
          call b(i)%share_from(a, status)
        end select
      type is (ndarray_i64)
        select type (b => arrays)
        type is (ndarray_i64)
          call b(i)%share_from(a, status)
        end select
      type is (ndarray_r32)
        select type (b => arrays)
        type is (ndarray_r32)
          call b(i)%share_from(a, status)
        end select
      type is (ndarray_r64)
        select type (b => arrays)
        type is (ndarray_r64)
          call b(i)%share_from(a, status)
        end select
      end select
      if (status%is_failure()) exit
    end do
    nullify(slot)
    if (status%is_ok()) call new_array_slot(dtype, slot, status)
    if (status%is_ok()) then
      select type (a => slot%array)
      type is (ndarray_bool)
        select type (b => arrays)
        type is (ndarray_bool)
          if (stack == 1) then
            a = stack_native(b, axis, status)
          else
            a = concatenate_native(b, axis, status)
          end if
        end select
      type is (ndarray_i32)
        select type (b => arrays)
        type is (ndarray_i32)
          if (stack == 1) then
            a = stack_native(b, axis, status)
          else
            a = concatenate_native(b, axis, status)
          end if
        end select
      type is (ndarray_i64)
        select type (b => arrays)
        type is (ndarray_i64)
          if (stack == 1) then
            a = stack_native(b, axis, status)
          else
            a = concatenate_native(b, axis, status)
          end if
        end select
      type is (ndarray_r32)
        select type (b => arrays)
        type is (ndarray_r32)
          if (stack == 1) then
            a = stack_native(b, axis, status)
          else
            a = concatenate_native(b, axis, status)
          end if
        end select
      type is (ndarray_r64)
        select type (b => arrays)
        type is (ndarray_r64)
          if (stack == 1) then
            a = stack_native(b, axis, status)
          else
            a = concatenate_native(b, axis, status)
          end if
        end select
      end select
    end if
    ! Release each retained reference before polymorphic container deallocation.
    select type (a => arrays)
    type is (ndarray_bool)
      do i = 1, count
        call a(i)%release()
      end do
    type is (ndarray_i32)
      do i = 1, count
        call a(i)%release()
      end do
    type is (ndarray_i64)
      do i = 1, count
        call a(i)%release()
      end do
    type is (ndarray_r32)
      do i = 1, count
        call a(i)%release()
      end do
    type is (ndarray_r64)
      do i = 1, count
        call a(i)%release()
      end do
    end select
    call publish(slot, out, status)
    code = status%code
  end function join
end module frumpy_c_selection
