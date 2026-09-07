!> Initial r64 sorting helpers for sort and argsort.
module frumpy_sorting_r64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
  use iso_fortran_env, only: int32, int64, real64
  use frumpy_strides, only: storage_bounds_are_valid
  use frumpy_constants, only: FRUMPY_ORDER_C, FRUMPY_ORDER_F
  use frumpy_constructors_r64, only: empty_r64
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64
  use frumpy_ndarray_r64, only: ndarray_r64
  use frumpy_statuses, only: FRUMPY_STATUS_ALLOCATION_FAILED, &
    FRUMPY_STATUS_INVALID_AXIS, FRUMPY_STATUS_INVALID_SHAPE, &
    FRUMPY_STATUS_OK, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, frumpy_status, &
    set_status

  implicit none

  private

  public :: sort_r64
  public :: argsort_r64

contains

  function sort_r64(source, axis0, status) result(array)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(frumpy_status) :: local_status
    integer(int32) :: axis_dim1
    integer(int32) :: resolved_axis0
    integer(int32) :: order

    resolved_axis0 = -1_int32
    if (present(axis0)) resolved_axis0 = axis0

    call validate_sort_source(source, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    axis_dim1 = resolve_sort_axis(resolved_axis0, source%rank, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    order = sort_output_order(source)
    array = empty_r64(source%shape, order, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    call copy_sorted_values(source, axis_dim1, array, local_status)
    call set_optional_status_value(status, local_status)
  end function sort_r64

  function argsort_r64(source, axis0, status) result(array)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array
    type(frumpy_status) :: local_status
    integer(int32) :: axis_dim1
    integer(int32) :: resolved_axis0

    resolved_axis0 = -1_int32
    if (present(axis0)) resolved_axis0 = axis0

    call validate_sort_source(source, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    if (source%rank == 0_int32) then
      if (resolved_axis0 /= -1_int32 .and. resolved_axis0 /= 0_int32) then
        call set_optional_status(status, FRUMPY_STATUS_INVALID_AXIS, &
          "argsort axis is out of bounds for scalar array")
        return
      end if
      array = owned_descriptor_i64([1_int64], FRUMPY_ORDER_C, local_status)
      if (local_status%is_failure()) then
        call set_optional_status_value(status, local_status)
        return
      end if

      array%data(1) = 0_int64
      call set_optional_status(status, FRUMPY_STATUS_OK)
      return
    end if

    axis_dim1 = resolve_sort_axis(resolved_axis0, source%rank, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    array = owned_descriptor_i64(source%shape, FRUMPY_ORDER_C, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    call copy_argsorted_indices(source, axis_dim1, array, local_status)
    call set_optional_status_value(status, local_status)
  end function argsort_r64

  subroutine validate_sort_source(source, status)
    type(ndarray_r64), intent(in) :: source
    type(frumpy_status), intent(out) :: status

    if (.not. source%has_storage()) then
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "sorting requires accessible r64 storage")
      return
    end if

    if (.not. allocated(source%shape) .or. .not. allocated(source%strides)) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "sorting source descriptor has incomplete metadata")
      return
    end if

    if (source%rank /= int(size(source%shape), int32) .or. &
        source%rank /= int(size(source%strides), int32)) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "sorting source rank does not match metadata")
      return
    end if

    if (.not. storage_bounds_are_valid(source%shape, source%strides, &
        source%offset, source%storage_size())) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "sorting source descriptor references storage out of bounds")
      return
    end if

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine validate_sort_source

  integer(int32) function resolve_sort_axis(axis0, rank, status) result(dim1)
    integer(int32), intent(in) :: axis0
    integer(int32), intent(in) :: rank
    type(frumpy_status), intent(out) :: status

    if (rank < 1_int32) then
      dim1 = -1_int32
      call set_status(status, FRUMPY_STATUS_INVALID_AXIS, &
        "sort axis is out of bounds for array rank")
      return
    end if

    if (axis0 >= 0_int32) then
      if (axis0 >= rank) then
        dim1 = -1_int32
        call set_status(status, FRUMPY_STATUS_INVALID_AXIS, &
          "sort axis is out of bounds for array rank")
        return
      end if
      dim1 = axis0 + 1_int32
    else
      if (axis0 < -rank) then
        dim1 = -1_int32
        call set_status(status, FRUMPY_STATUS_INVALID_AXIS, &
          "sort axis is out of bounds for array rank")
        return
      end if
      dim1 = rank + axis0 + 1_int32
    end if

    call set_status(status, FRUMPY_STATUS_OK)
  end function resolve_sort_axis

  integer(int32) function sort_output_order(source) result(order)
    type(ndarray_r64), intent(in) :: source

    if (source%is_f_contiguous .and. .not. source%is_c_contiguous) then
      order = FRUMPY_ORDER_F
    else
      order = FRUMPY_ORDER_C
    end if
  end function sort_output_order

  subroutine copy_sorted_values(source, axis_dim1, output, status)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in) :: axis_dim1
    type(ndarray_r64), intent(inout) :: output
    type(frumpy_status), intent(out) :: status
    integer(int64), allocatable :: outer_index0(:)
    integer(int64), allocatable :: outer_shape(:)
    integer(int64), allocatable :: slice_indices(:)
    real(real64), allocatable :: slice_values(:)
    integer(int64) :: axis_extent
    integer(int64) :: item1
    integer :: alloc_stat

    if (output%size() == 0_int64) then
      call set_status(status, FRUMPY_STATUS_OK)
      return
    end if

    axis_extent = source%shape(axis_dim1)
    allocate(outer_index0(source%rank), outer_shape(source%rank), &
      slice_indices(axis_extent), slice_values(axis_extent), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "sort_r64 work allocation failed")
      return
    end if

    outer_shape = source%shape
    outer_shape(axis_dim1) = 1_int64
    outer_index0 = 0_int64

    do
      call gather_sorted_slice(source, outer_index0, axis_dim1, slice_values, &
        slice_indices)
      call sort_slice_pairs(slice_values, slice_indices)

      do item1 = 1_int64, axis_extent
        outer_index0(axis_dim1) = item1 - 1_int64
        output%data(storage_position(output%offset, output%strides, &
          outer_index0)) = slice_values(item1)
      end do

      call advance_c_order_index(outer_index0, outer_shape)
      if (all(outer_index0 == 0_int64)) exit
    end do

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine copy_sorted_values

  subroutine copy_argsorted_indices(source, axis_dim1, output, status)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in) :: axis_dim1
    type(ndarray_i64), intent(inout) :: output
    type(frumpy_status), intent(out) :: status
    integer(int64), allocatable :: outer_index0(:)
    integer(int64), allocatable :: outer_shape(:)
    integer(int64), allocatable :: slice_indices(:)
    real(real64), allocatable :: slice_values(:)
    integer(int64) :: axis_extent
    integer(int64) :: item1
    integer :: alloc_stat

    if (output%size() == 0_int64) then
      call set_status(status, FRUMPY_STATUS_OK)
      return
    end if

    axis_extent = source%shape(axis_dim1)
    allocate(outer_index0(source%rank), outer_shape(source%rank), &
      slice_indices(axis_extent), slice_values(axis_extent), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "argsort_r64 work allocation failed")
      return
    end if

    outer_shape = source%shape
    outer_shape(axis_dim1) = 1_int64
    outer_index0 = 0_int64

    do
      call gather_sorted_slice(source, outer_index0, axis_dim1, slice_values, &
        slice_indices)
      call sort_slice_pairs(slice_values, slice_indices)

      do item1 = 1_int64, axis_extent
        outer_index0(axis_dim1) = item1 - 1_int64
        output%data(storage_position(output%offset, output%strides, &
          outer_index0)) = slice_indices(item1)
      end do

      call advance_c_order_index(outer_index0, outer_shape)
      if (all(outer_index0 == 0_int64)) exit
    end do

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine copy_argsorted_indices

  subroutine gather_sorted_slice(source, outer_index0, axis_dim1, slice_values, &
      slice_indices)
    type(ndarray_r64), intent(in) :: source
    integer(int64), intent(inout) :: outer_index0(:)
    integer(int32), intent(in) :: axis_dim1
    real(real64), intent(inout) :: slice_values(:)
    integer(int64), intent(inout) :: slice_indices(:)
    integer(int64) :: item1

    do item1 = 1_int64, int(size(slice_values), int64)
      outer_index0(axis_dim1) = item1 - 1_int64
      slice_values(item1) = source%data(storage_position(source%offset, &
        source%strides, outer_index0))
      slice_indices(item1) = item1 - 1_int64
    end do
  end subroutine gather_sorted_slice

  subroutine sort_slice_pairs(values, indices)
    real(real64), intent(inout) :: values(:)
    integer(int64), intent(inout) :: indices(:)
    integer(int64) :: item1
    integer(int64) :: item2
    real(real64) :: key_value
    integer(int64) :: key_index

    do item1 = 2_int64, int(size(values), int64)
      key_value = values(item1)
      key_index = indices(item1)
      item2 = item1 - 1_int64

      do while (item2 >= 1_int64)
        ! NumPy sorts NaNs last; equal values retain their original order.
        if (ieee_is_nan(key_value)) exit
        if (.not. ieee_is_nan(values(item2))) then
          if (values(item2) <= key_value) exit
        end if
        values(item2 + 1_int64) = values(item2)
        indices(item2 + 1_int64) = indices(item2)
        item2 = item2 - 1_int64
      end do

      values(item2 + 1_int64) = key_value
      indices(item2 + 1_int64) = key_index
    end do
  end subroutine sort_slice_pairs

  integer(int64) function storage_position(offset, strides, index0) result(pos)
    integer(int64), intent(in) :: offset
    integer(int64), intent(in) :: strides(:)
    integer(int64), intent(in) :: index0(:)
    integer(int32) :: dim1

    pos = offset
    do dim1 = 1_int32, int(size(index0), int32)
      pos = pos + index0(dim1) * strides(dim1)
    end do
  end function storage_position


  subroutine advance_c_order_index(index0, shape)
    integer(int64), intent(inout) :: index0(:)
    integer(int64), intent(in) :: shape(:)
    integer(int32) :: dim1

    if (size(index0) == 0) return

    do dim1 = size(index0), 1, -1
      index0(dim1) = index0(dim1) + 1_int64
      if (index0(dim1) < shape(dim1)) return
      index0(dim1) = 0_int64
    end do
  end subroutine advance_c_order_index

  subroutine set_optional_status(status, code, message)
    type(frumpy_status), intent(out), optional :: status
    integer(int32), intent(in) :: code
    character(len=*), intent(in), optional :: message

    if (.not. present(status)) return

    if (present(message)) then
      call set_status(status, code, message)
    else
      call set_status(status, code)
    end if
  end subroutine set_optional_status

  subroutine set_optional_status_value(status, source_status)
    type(frumpy_status), intent(out), optional :: status
    type(frumpy_status), intent(in) :: source_status

    if (.not. present(status)) return

    status = source_status
  end subroutine set_optional_status_value
end module frumpy_sorting_r64
