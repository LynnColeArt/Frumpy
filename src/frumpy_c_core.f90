!> Copying C buffer boundary and descriptor queries; no Fortran layout crosses the ABI.
module frumpy_c_core
  use iso_c_binding, only: c_ptr, c_associated, c_f_pointer, c_int8_t, c_int32_t, &
    c_int64_t, c_float, c_double
  use iso_fortran_env, only: int32, int64
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_INVALID_SHAPE, &
    FRUMPY_STATUS_OVERFLOW, FRUMPY_STATUS_OK
  use frumpy_c_handles, only: handle_slot, lookup, new_array_slot, publish, discard, &
    read_shape, output_pointer, retain_handle, release_handle
  use frumpy_shape, only: element_count
  use frumpy_strides, only: flat_offset
  use frumpy, only: ndarray_bool, empty_bool
  use frumpy, only: ndarray_i32, empty_i32
  use frumpy, only: ndarray_i64, empty_i64
  use frumpy, only: ndarray_r32, empty_r32
  use frumpy, only: ndarray_r64, empty_r64
  implicit none
  private
contains
  integer(c_int32_t) function abi_version() bind(C, name="frumpy_abi_version") result(code)
    code = 1_c_int32_t
  end function abi_version
  integer(c_int32_t) function retain(id) bind(C, name="frumpy_retain") result(code)
    integer(c_int64_t), value :: id
    type(frumpy_status) :: status
    call retain_handle(id, status)
    code = status%code
  end function retain
  integer(c_int32_t) function release(id) bind(C, name="frumpy_release") result(code)
    integer(c_int64_t), value :: id
    type(frumpy_status) :: status
    call release_handle(id, status)
    code = status%code
  end function release
  subroutine create_slot(dtype, rank, shape_address, order, slot, status)
    integer(c_int32_t), intent(in) :: dtype, rank, order
    type(c_ptr), intent(in) :: shape_address
    type(handle_slot), pointer, intent(out) :: slot
    type(frumpy_status), intent(out) :: status
    integer(int64), allocatable :: shape(:)
    integer(int64) :: count
    integer(int64), parameter :: bytes(5) = [1_int64,4_int64,8_int64,4_int64,8_int64]

    nullify(slot)
    call read_shape(shape_address, rank, shape, status)
    if (status%is_failure()) return
    count = element_count(shape, status)
    if (status%is_failure()) return
    call new_array_slot(dtype, slot, status)
    if (status%is_failure()) return
    if (count > huge(count) / bytes(dtype)) then
      call set_status(status, FRUMPY_STATUS_OVERFLOW, "ABI allocation byte count")
      call discard(slot)
      return
    end if
    select type (a => slot%array)
    type is (ndarray_bool)
      a = empty_bool(shape, order, status)
    type is (ndarray_i32)
      a = empty_i32(shape, order, status)
    type is (ndarray_i64)
      a = empty_i64(shape, order, status)
    type is (ndarray_r32)
      a = empty_r32(shape, order, status)
    type is (ndarray_r64)
      a = empty_r64(shape, order, status)
    end select
    if (status%is_failure()) call discard(slot)
  end subroutine create_slot

  integer(c_int32_t) function create(dtype, rank, shape, order, output) &
      bind(C, name="frumpy_create") result(code)
    integer(c_int32_t), value :: dtype, rank, order
    type(c_ptr), value :: shape, output
    integer(c_int64_t), pointer :: out
    type(handle_slot), pointer :: slot
    type(frumpy_status) :: status

    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    call create_slot(dtype, rank, shape, order, slot, status)
    call publish(slot, out, status)
    code = status%code
  end function create

  integer(c_int32_t) function import_buffer(dtype, rank, shape, order, data, count, output) &
      bind(C, name="frumpy_import") result(code)
    integer(c_int32_t), value :: dtype, rank, order
    integer(c_int64_t), value :: count
    type(c_ptr), value :: shape, data, output
    integer(c_int64_t), pointer :: out
    integer(int64), allocatable :: dims(:)
    integer(int64) :: expected
    type(handle_slot), pointer :: slot
    type(frumpy_status) :: status

    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    call read_shape(shape, rank, dims, status)
    code = status%code
    if (status%is_failure()) return
    expected = element_count(dims, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_INVALID_SHAPE
    if (count /= expected) return
    if (count > 0_int64 .and. .not. c_associated(data)) return
    call create_slot(dtype, rank, shape, order, slot, status)
    if (status%is_ok()) call transfer_buffer(slot, data, count, .true., status)
    call publish(slot, out, status)
    code = status%code
  end function import_buffer

  integer(c_int32_t) function export_buffer(id, data, count) &
      bind(C, name="frumpy_export") result(code)
    integer(c_int64_t), value :: id, count
    type(c_ptr), value :: data
    type(handle_slot), pointer :: slot
    type(frumpy_status) :: status

    slot => lookup(id, 1_int32, status)
    if (status%is_ok()) call transfer_buffer(slot, data, count, .false., status)
    code = status%code
  end function export_buffer

  subroutine transfer_buffer(slot, data, count, importing, status)
    type(handle_slot), intent(inout) :: slot
    type(c_ptr), intent(in) :: data
    integer(int64), intent(in) :: count
    logical, intent(in) :: importing
    type(frumpy_status), intent(out) :: status
    integer(int64) :: i, position, expected
    integer(c_int8_t), pointer :: buffer_bool(:)
    integer(c_int32_t), pointer :: buffer_i32(:)
    integer(c_int64_t), pointer :: buffer_i64(:)
    real(c_float), pointer :: buffer_r32(:)
    real(c_double), pointer :: buffer_r64(:)

    call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, "invalid ABI data buffer")
    if (count < 0_int64) return
    if (count > 0_int64 .and. .not. c_associated(data)) return
    select type (a => slot%array)
    type is (ndarray_bool)
      expected = element_count(a%shape, status)
      if (count /= expected) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, "ABI buffer count mismatch")
        return
      end if
      if (count == 0_int64) return
      call c_f_pointer(data, buffer_bool, [count])
      do i = 1_int64, count
        position = flat_offset(a%shape, a%strides, a%offset, i - 1_int64)
        if (importing) then
          a%data(position) = merge(1_c_int8_t, 0_c_int8_t, buffer_bool(i) /= 0_c_int8_t)
        else
          buffer_bool(i) = a%data(position)
        end if
      end do
    type is (ndarray_i32)
      expected = element_count(a%shape, status)
      if (count /= expected) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, "ABI buffer count mismatch")
        return
      end if
      if (count == 0_int64) return
      call c_f_pointer(data, buffer_i32, [count])
      do i = 1_int64, count
        position = flat_offset(a%shape, a%strides, a%offset, i - 1_int64)
        if (importing) then
          a%data(position) = buffer_i32(i)
        else
          buffer_i32(i) = a%data(position)
        end if
      end do
    type is (ndarray_i64)
      expected = element_count(a%shape, status)
      if (count /= expected) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, "ABI buffer count mismatch")
        return
      end if
      if (count == 0_int64) return
      call c_f_pointer(data, buffer_i64, [count])
      do i = 1_int64, count
        position = flat_offset(a%shape, a%strides, a%offset, i - 1_int64)
        if (importing) then
          a%data(position) = buffer_i64(i)
        else
          buffer_i64(i) = a%data(position)
        end if
      end do
    type is (ndarray_r32)
      expected = element_count(a%shape, status)
      if (count /= expected) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, "ABI buffer count mismatch")
        return
      end if
      if (count == 0_int64) return
      call c_f_pointer(data, buffer_r32, [count])
      do i = 1_int64, count
        position = flat_offset(a%shape, a%strides, a%offset, i - 1_int64)
        if (importing) then
          a%data(position) = buffer_r32(i)
        else
          buffer_r32(i) = a%data(position)
        end if
      end do
    type is (ndarray_r64)
      expected = element_count(a%shape, status)
      if (count /= expected) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, "ABI buffer count mismatch")
        return
      end if
      if (count == 0_int64) return
      call c_f_pointer(data, buffer_r64, [count])
      do i = 1_int64, count
        position = flat_offset(a%shape, a%strides, a%offset, i - 1_int64)
        if (importing) then
          a%data(position) = buffer_r64(i)
        else
          buffer_r64(i) = a%data(position)
        end if
      end do
    end select
    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine transfer_buffer

  integer(c_int32_t) function info(id, dtype, rank, shape, strides, capacity, offset, flags) &
      bind(C, name="frumpy_info") result(code)
    integer(c_int64_t), value :: id
    integer(c_int32_t), value :: capacity
    type(c_ptr), value :: dtype, rank, shape, strides, offset, flags
    integer(c_int32_t), pointer :: out_dtype, out_rank, out_flags
    integer(c_int64_t), pointer :: out_shape(:), out_strides(:), out_offset
    type(handle_slot), pointer :: slot
    type(frumpy_status) :: status

    slot => lookup(id, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_INVALID_SHAPE
    if (.not. c_associated(dtype) .or. .not. c_associated(rank)) return
    if (.not. c_associated(offset) .or. .not. c_associated(flags)) return
    if (capacity < 0_c_int32_t) return
    call c_f_pointer(dtype, out_dtype)
    call c_f_pointer(rank, out_rank)
    call c_f_pointer(offset, out_offset)
    call c_f_pointer(flags, out_flags)
    select type (a => slot%array)
    type is (ndarray_bool)
      if (capacity < a%rank) return
      if (a%rank > 0) then
        if (.not. c_associated(shape) .or. .not. c_associated(strides)) return
        call c_f_pointer(shape, out_shape, [a%rank])
        call c_f_pointer(strides, out_strides, [a%rank])
        out_shape = a%shape
        out_strides = a%strides
      end if
      out_dtype = a%dtype_id
      out_rank = a%rank
      out_offset = a%offset - 1_int64
      out_flags = merge(1,0,a%is_c_contiguous) + merge(2,0,a%is_f_contiguous) + &
        merge(4,0,a%owns_data)
    type is (ndarray_i32)
      if (capacity < a%rank) return
      if (a%rank > 0) then
        if (.not. c_associated(shape) .or. .not. c_associated(strides)) return
        call c_f_pointer(shape, out_shape, [a%rank])
        call c_f_pointer(strides, out_strides, [a%rank])
        out_shape = a%shape
        out_strides = a%strides
      end if
      out_dtype = a%dtype_id
      out_rank = a%rank
      out_offset = a%offset - 1_int64
      out_flags = merge(1,0,a%is_c_contiguous) + merge(2,0,a%is_f_contiguous) + &
        merge(4,0,a%owns_data)
    type is (ndarray_i64)
      if (capacity < a%rank) return
      if (a%rank > 0) then
        if (.not. c_associated(shape) .or. .not. c_associated(strides)) return
        call c_f_pointer(shape, out_shape, [a%rank])
        call c_f_pointer(strides, out_strides, [a%rank])
        out_shape = a%shape
        out_strides = a%strides
      end if
      out_dtype = a%dtype_id
      out_rank = a%rank
      out_offset = a%offset - 1_int64
      out_flags = merge(1,0,a%is_c_contiguous) + merge(2,0,a%is_f_contiguous) + &
        merge(4,0,a%owns_data)
    type is (ndarray_r32)
      if (capacity < a%rank) return
      if (a%rank > 0) then
        if (.not. c_associated(shape) .or. .not. c_associated(strides)) return
        call c_f_pointer(shape, out_shape, [a%rank])
        call c_f_pointer(strides, out_strides, [a%rank])
        out_shape = a%shape
        out_strides = a%strides
      end if
      out_dtype = a%dtype_id
      out_rank = a%rank
      out_offset = a%offset - 1_int64
      out_flags = merge(1,0,a%is_c_contiguous) + merge(2,0,a%is_f_contiguous) + &
        merge(4,0,a%owns_data)
    type is (ndarray_r64)
      if (capacity < a%rank) return
      if (a%rank > 0) then
        if (.not. c_associated(shape) .or. .not. c_associated(strides)) return
        call c_f_pointer(shape, out_shape, [a%rank])
        call c_f_pointer(strides, out_strides, [a%rank])
        out_shape = a%shape
        out_strides = a%strides
      end if
      out_dtype = a%dtype_id
      out_rank = a%rank
      out_offset = a%offset - 1_int64
      out_flags = merge(1,0,a%is_c_contiguous) + merge(2,0,a%is_f_contiguous) + &
        merge(4,0,a%owns_data)
    end select
    code = FRUMPY_STATUS_OK
  end function info

  integer(c_int32_t) function full(dtype, rank, shape, order, value, output) &
      bind(C, name="frumpy_full") result(code)
    integer(c_int32_t), value :: dtype, rank, order
    type(c_ptr), value :: shape, value, output
    integer(c_int64_t), pointer :: out
    type(handle_slot), pointer :: slot
    type(frumpy_status) :: status
    integer(c_int8_t), pointer :: scalar_bool
    integer(c_int32_t), pointer :: scalar_i32
    integer(c_int64_t), pointer :: scalar_i64
    real(c_float), pointer :: scalar_r32
    real(c_double), pointer :: scalar_r64

    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_INVALID_SHAPE
    if (.not. c_associated(value)) return
    call create_slot(dtype, rank, shape, order, slot, status)
    if (status%is_ok()) then
      select type (a => slot%array)
      type is (ndarray_bool)
        call c_f_pointer(value, scalar_bool)
        a%data = merge(1_c_int8_t,0_c_int8_t,scalar_bool /= 0_c_int8_t)
      type is (ndarray_i32)
        call c_f_pointer(value, scalar_i32)
        a%data = scalar_i32
      type is (ndarray_i64)
        call c_f_pointer(value, scalar_i64)
        a%data = scalar_i64
      type is (ndarray_r32)
        call c_f_pointer(value, scalar_r32)
        a%data = scalar_r32
      type is (ndarray_r64)
        call c_f_pointer(value, scalar_r64)
        a%data = scalar_r64
      end select
    end if
    call publish(slot, out, status)
    code = status%code
  end function full
end module frumpy_c_core
