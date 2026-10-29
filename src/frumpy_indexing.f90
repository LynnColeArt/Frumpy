!> Full-shape boolean selection and staged same-dtype writes.
module frumpy_indexing
  use iso_fortran_env, only: int8, int32, int64
  use frumpy_operands, only: operand, bind_operand, boolean_value
  use frumpy_shape, only: element_count
  use frumpy_strides, only: flat_offset
  use frumpy_broadcast, only: broadcast_plan, broadcast_plan_from_metadata
  use frumpy_dtypes, only: dtype_byte_size
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_INVALID_SHAPE, &
    FRUMPY_STATUS_UNSUPPORTED_DTYPE, FRUMPY_STATUS_ALLOCATION_FAILED, FRUMPY_STATUS_OVERFLOW
  use frumpy_ndarray_bool, only: ndarray_bool, owned_descriptor_bool
  use frumpy_ndarray_i32, only: ndarray_i32, owned_descriptor_i32
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64
  use frumpy_ndarray_r32, only: ndarray_r32, owned_descriptor_r32
  use frumpy_ndarray_r64, only: ndarray_r64, owned_descriptor_r64
  implicit none
  private
  public :: mask_select, assign, mask_assign
  interface mask_select
    module procedure mask_select_bool
    module procedure mask_select_i32
    module procedure mask_select_i64
    module procedure mask_select_r32
    module procedure mask_select_r64
  end interface mask_select
contains
  function mask_select_bool(source, mask, status) result(array)
    type(ndarray_bool), target, intent(in) :: source
    type(ndarray_bool), target, intent(in) :: mask
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_bool), target :: array
    type(operand) :: input, condition, output
    type(frumpy_status) :: local
    integer(int64) :: count, i0, selected, position

    call bind_operand(source, input, local)
    if (local%is_ok()) call check_mask(input, mask, condition, count, local)
    if (local%is_ok()) call check_bytes(count, input%dtype_id, local)
    if (local%is_ok()) array = owned_descriptor_bool([count], status=local)
    if (local%is_ok()) call bind_operand(array, output, local)
    if (present(status)) status = local
    if (local%is_failure()) return
    selected = 0_int64
    do i0 = 0_int64, element_count(input%shape) - 1_int64
      position = flat_offset(condition%shape, condition%strides, condition%offset, i0)
      if (.not. boolean_value(condition, position)) cycle
      selected = selected + 1_int64
      position = flat_offset(input%shape, input%strides, input%offset, i0)
      call copy_value(input, position, output, selected)
    end do
  end function mask_select_bool

  function mask_select_i32(source, mask, status) result(array)
    type(ndarray_i32), target, intent(in) :: source
    type(ndarray_bool), target, intent(in) :: mask
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i32), target :: array
    type(operand) :: input, condition, output
    type(frumpy_status) :: local
    integer(int64) :: count, i0, selected, position

    call bind_operand(source, input, local)
    if (local%is_ok()) call check_mask(input, mask, condition, count, local)
    if (local%is_ok()) call check_bytes(count, input%dtype_id, local)
    if (local%is_ok()) array = owned_descriptor_i32([count], status=local)
    if (local%is_ok()) call bind_operand(array, output, local)
    if (present(status)) status = local
    if (local%is_failure()) return
    selected = 0_int64
    do i0 = 0_int64, element_count(input%shape) - 1_int64
      position = flat_offset(condition%shape, condition%strides, condition%offset, i0)
      if (.not. boolean_value(condition, position)) cycle
      selected = selected + 1_int64
      position = flat_offset(input%shape, input%strides, input%offset, i0)
      call copy_value(input, position, output, selected)
    end do
  end function mask_select_i32

  function mask_select_i64(source, mask, status) result(array)
    type(ndarray_i64), target, intent(in) :: source
    type(ndarray_bool), target, intent(in) :: mask
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i64), target :: array
    type(operand) :: input, condition, output
    type(frumpy_status) :: local
    integer(int64) :: count, i0, selected, position

    call bind_operand(source, input, local)
    if (local%is_ok()) call check_mask(input, mask, condition, count, local)
    if (local%is_ok()) call check_bytes(count, input%dtype_id, local)
    if (local%is_ok()) array = owned_descriptor_i64([count], status=local)
    if (local%is_ok()) call bind_operand(array, output, local)
    if (present(status)) status = local
    if (local%is_failure()) return
    selected = 0_int64
    do i0 = 0_int64, element_count(input%shape) - 1_int64
      position = flat_offset(condition%shape, condition%strides, condition%offset, i0)
      if (.not. boolean_value(condition, position)) cycle
      selected = selected + 1_int64
      position = flat_offset(input%shape, input%strides, input%offset, i0)
      call copy_value(input, position, output, selected)
    end do
  end function mask_select_i64

  function mask_select_r32(source, mask, status) result(array)
    type(ndarray_r32), target, intent(in) :: source
    type(ndarray_bool), target, intent(in) :: mask
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_r32), target :: array
    type(operand) :: input, condition, output
    type(frumpy_status) :: local
    integer(int64) :: count, i0, selected, position

    call bind_operand(source, input, local)
    if (local%is_ok()) call check_mask(input, mask, condition, count, local)
    if (local%is_ok()) call check_bytes(count, input%dtype_id, local)
    if (local%is_ok()) array = owned_descriptor_r32([count], status=local)
    if (local%is_ok()) call bind_operand(array, output, local)
    if (present(status)) status = local
    if (local%is_failure()) return
    selected = 0_int64
    do i0 = 0_int64, element_count(input%shape) - 1_int64
      position = flat_offset(condition%shape, condition%strides, condition%offset, i0)
      if (.not. boolean_value(condition, position)) cycle
      selected = selected + 1_int64
      position = flat_offset(input%shape, input%strides, input%offset, i0)
      call copy_value(input, position, output, selected)
    end do
  end function mask_select_r32

  function mask_select_r64(source, mask, status) result(array)
    type(ndarray_r64), target, intent(in) :: source
    type(ndarray_bool), target, intent(in) :: mask
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_r64), target :: array
    type(operand) :: input, condition, output
    type(frumpy_status) :: local
    integer(int64) :: count, i0, selected, position

    call bind_operand(source, input, local)
    if (local%is_ok()) call check_mask(input, mask, condition, count, local)
    if (local%is_ok()) call check_bytes(count, input%dtype_id, local)
    if (local%is_ok()) array = owned_descriptor_r64([count], status=local)
    if (local%is_ok()) call bind_operand(array, output, local)
    if (present(status)) status = local
    if (local%is_failure()) return
    selected = 0_int64
    do i0 = 0_int64, element_count(input%shape) - 1_int64
      position = flat_offset(condition%shape, condition%strides, condition%offset, i0)
      if (.not. boolean_value(condition, position)) cycle
      selected = selected + 1_int64
      position = flat_offset(input%shape, input%strides, input%offset, i0)
      call copy_value(input, position, output, selected)
    end do
  end function mask_select_r64

  ! The descriptor is immutable; writes affect only its pointed-to payload.
  ! INTENT(IN) permits identical descriptors and shared backing among operands.
  subroutine assign(target, values, status)
    class(*), target, intent(in) :: target, values
    type(frumpy_status), optional, intent(out) :: status
    type(frumpy_status) :: local

    call staged_assign(target, values, local)
    if (present(status)) status = local
  end subroutine assign

  subroutine mask_assign(target, mask, values, status)
    class(*), target, intent(in) :: target, values
    type(ndarray_bool), target, intent(in) :: mask
    type(frumpy_status), optional, intent(out) :: status
    type(frumpy_status) :: local

    call staged_assign(target, values, local, mask)
    if (present(status)) status = local
  end subroutine mask_assign

  subroutine staged_assign(target, values, status, mask)
    class(*), target, intent(in) :: target, values
    type(frumpy_status), intent(out) :: status
    type(ndarray_bool), optional, target, intent(in) :: mask
    type(operand) :: destination, input, condition, buffer
    type(broadcast_plan) :: plan
    class(*), allocatable, target :: staged
    integer(int64), allocatable :: positions(:)
    integer(int64) :: count, i0, selected, position, value_position
    integer(int32) :: alloc_stat

    call bind_operand(target, destination, status)
    if (status%is_ok()) call bind_operand(values, input, status)
    if (status%is_failure()) return
    if (destination%dtype_id /= input%dtype_id) then
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, 'assignment requires matching dtypes')
      return
    end if
    count = element_count(destination%shape)
    if (present(mask)) then
      call check_mask(destination, mask, condition, count, status)
      if (status%is_failure()) return
      if (size(input%shape) > 1) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, 'masked values must be scalar or rank one')
        return
      end if
      if (size(input%shape) == 1) then
        if (input%shape(1) /= 1_int64 .and. input%shape(1) /= count) then
          call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, 'masked values must match selected count')
          return
        end if
      end if
      ! Snapshot destinations too: a boolean mask can alias the writable target.
      if (count > shiftr(huge(count), 3)) then
        call set_status(status, FRUMPY_STATUS_OVERFLOW, 'mask position bytes overflow')
        return
      end if
      allocate(positions(count), stat=alloc_stat)
      if (alloc_stat /= 0) then
        call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED)
        return
      end if
    else
      plan = broadcast_plan_from_metadata(destination%shape, destination%strides, &
        input%shape, input%strides, status)
      if (status%is_failure()) return
      if (plan%rank /= size(destination%shape)) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, 'assignment cannot expand target')
        return
      end if
      if (any(plan%shape /= destination%shape)) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, 'assignment cannot expand target')
        return
      end if
    end if
    call allocate_stage(staged, count, input%dtype_id, buffer, status)
    if (status%is_failure()) return
    if (present(mask)) then
      selected = 0_int64
      do i0 = 0_int64, element_count(destination%shape) - 1_int64
        position = flat_offset(condition%shape, condition%strides, condition%offset, i0)
        if (.not. boolean_value(condition, position)) cycle
        selected = selected + 1_int64
        positions(selected) = flat_offset(destination%shape, destination%strides, destination%offset, i0)
        value_position = input%offset
        if (size(input%shape) == 1) then
          if (input%shape(1) /= 1_int64) &
            value_position = value_position + (selected - 1_int64) * input%strides(1)
        end if
        call copy_value(input, value_position, buffer, selected)
      end do
      do selected = 1_int64, count
        call copy_value(buffer, selected, destination, positions(selected))
      end do
    else
      do i0 = 0_int64, count - 1_int64
        position = flat_offset(plan%shape, plan%rhs_strides, input%offset, i0)
        call copy_value(input, position, buffer, i0 + 1_int64)
      end do
      do i0 = 0_int64, count - 1_int64
        position = flat_offset(destination%shape, destination%strides, destination%offset, i0)
        call copy_value(buffer, i0 + 1_int64, destination, position)
      end do
    end if
  end subroutine staged_assign

  subroutine check_mask(input, mask, condition, count, status)
    type(operand), intent(in) :: input
    type(ndarray_bool), target, intent(in) :: mask
    type(operand), intent(out) :: condition
    integer(int64), intent(out) :: count
    type(frumpy_status), intent(out) :: status
    integer(int64) :: i0, position

    count = 0_int64
    call bind_operand(mask, condition, status)
    if (status%is_failure()) return
    if (size(input%shape) /= size(condition%shape)) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, 'mask rank must match source')
      return
    end if
    if (any(input%shape /= condition%shape)) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, 'mask shape must match source')
      return
    end if
    do i0 = 0_int64, element_count(input%shape) - 1_int64
      position = flat_offset(condition%shape, condition%strides, condition%offset, i0)
      if (boolean_value(condition, position)) count = count + 1_int64
    end do
  end subroutine check_mask

  subroutine check_bytes(count, dtype, status)
    integer(int64), intent(in) :: count
    integer(int32), intent(in) :: dtype
    type(frumpy_status), intent(inout) :: status

    if (count > huge(count) / dtype_byte_size(dtype)) &
      call set_status(status, FRUMPY_STATUS_OVERFLOW, 'indexing output bytes overflow')
  end subroutine check_bytes

  subroutine allocate_stage(staged, count, dtype, buffer, status)
    class(*), allocatable, target, intent(out) :: staged
    integer(int64), intent(in) :: count
    integer(int32), intent(in) :: dtype
    type(operand), intent(out) :: buffer
    type(frumpy_status), intent(inout) :: status
    integer(int32) :: alloc_stat

    call check_bytes(count, dtype, status)
    if (status%is_failure()) return
    select case (dtype)
    case (1)
      allocate(ndarray_bool :: staged, stat=alloc_stat)
    case (2)
      allocate(ndarray_i32 :: staged, stat=alloc_stat)
    case (3)
      allocate(ndarray_i64 :: staged, stat=alloc_stat)
    case (4)
      allocate(ndarray_r32 :: staged, stat=alloc_stat)
    case (5)
      allocate(ndarray_r64 :: staged, stat=alloc_stat)
    end select
    if (alloc_stat /= 0) then
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED)
      return
    end if
    select type (staged)
    type is (ndarray_bool)
      staged = owned_descriptor_bool([count], status=status)
    type is (ndarray_i32)
      staged = owned_descriptor_i32([count], status=status)
    type is (ndarray_i64)
      staged = owned_descriptor_i64([count], status=status)
    type is (ndarray_r32)
      staged = owned_descriptor_r32([count], status=status)
    type is (ndarray_r64)
      staged = owned_descriptor_r64([count], status=status)
    end select
    if (status%is_ok()) call bind_operand(staged, buffer, status)
  end subroutine allocate_stage

  subroutine copy_value(input, source_position, output, output_position)
    type(operand), intent(in) :: input, output
    integer(int64), intent(in) :: source_position, output_position

    select case (input%dtype_id)
    case (1)
      output%values_bool(output_position) = merge(1_int8, 0_int8, input%values_bool(source_position) /= 0_int8)
    case (2)
      output%values_i32(output_position) = input%values_i32(source_position)
    case (3)
      output%values_i64(output_position) = input%values_i64(source_position)
    case (4)
      output%values_r32(output_position) = input%values_r32(source_position)
    case (5)
      output%values_r64(output_position) = input%values_r64(source_position)
    end select
  end subroutine copy_value
end module frumpy_indexing
