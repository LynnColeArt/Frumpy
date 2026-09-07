!> Initial r64 searching helpers for searchsorted.
module frumpy_searching_r64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
  use iso_fortran_env, only: int32, int64, real64
  use frumpy_strides, only: storage_bounds_are_valid
  use frumpy_constants, only: FRUMPY_ORDER_C
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64
  use frumpy_ndarray_r64, only: ndarray_r64
  use frumpy_statuses, only: FRUMPY_STATUS_ALLOCATION_FAILED, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, frumpy_status, set_status

  implicit none

  private

  public :: searchsorted_r64

contains

  function searchsorted_r64(source, values, side_right, status) result(array)
    type(ndarray_r64), intent(in) :: source
    type(ndarray_r64), intent(in) :: values
    logical, intent(in), optional :: side_right
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array
    type(frumpy_status) :: local_status
    logical :: use_right_side

    use_right_side = .false.
    if (present(side_right)) use_right_side = side_right

    call validate_searchsorted_source(source, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    call validate_searchsorted_values(values, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    array = owned_descriptor_i64(values%shape, FRUMPY_ORDER_C, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    call copy_searchsorted_values(source, values, use_right_side, array, &
      local_status)
    call set_optional_status_value(status, local_status)
  end function searchsorted_r64

  subroutine validate_searchsorted_source(source, status)
    type(ndarray_r64), intent(in) :: source
    type(frumpy_status), intent(out) :: status

    if (.not. source%has_storage()) then
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "searchsorted requires accessible r64 storage")
      return
    end if

    if (.not. allocated(source%shape) .or. .not. allocated(source%strides)) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "searchsorted source descriptor has incomplete metadata")
      return
    end if

    if (source%rank /= 1_int32 .or. source%rank /= int(size(source%shape), &
        int32) .or. source%rank /= int(size(source%strides), int32)) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "searchsorted source must be one-dimensional")
      return
    end if

    if (.not. storage_bounds_are_valid(source%shape, source%strides, &
        source%offset, source%storage_size())) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "searchsorted source descriptor references storage out of bounds")
      return
    end if

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine validate_searchsorted_source

  subroutine validate_searchsorted_values(values, status)
    type(ndarray_r64), intent(in) :: values
    type(frumpy_status), intent(out) :: status

    if (.not. values%has_storage()) then
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "searchsorted requires accessible values storage")
      return
    end if

    if (.not. allocated(values%shape) .or. .not. allocated(values%strides)) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "searchsorted values descriptor has incomplete metadata")
      return
    end if

    if (values%rank /= int(size(values%shape), int32) .or. &
        values%rank /= int(size(values%strides), int32)) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "searchsorted values rank does not match metadata")
      return
    end if

    if (.not. storage_bounds_are_valid(values%shape, values%strides, &
        values%offset, values%storage_size())) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "searchsorted values descriptor references storage out of bounds")
      return
    end if

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine validate_searchsorted_values

  subroutine copy_searchsorted_values(source, values, side_right, output, &
      status)
    type(ndarray_r64), intent(in) :: source
    type(ndarray_r64), intent(in) :: values
    logical, intent(in) :: side_right
    type(ndarray_i64), intent(inout) :: output
    type(frumpy_status), intent(out) :: status
    integer(int64), allocatable :: index0(:)
    integer(int64) :: output_position
    integer(int64) :: values_position
    integer(int64) :: insertion_position
    real(real64) :: search_value
    integer :: alloc_stat

    allocate(index0(values%rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "searchsorted work allocation failed")
      return
    end if

    if (output%size() == 0_int64) then
      call set_status(status, FRUMPY_STATUS_OK)
      return
    end if

    index0 = 0_int64
    do
      values_position = storage_position(values%offset, values%strides, index0)
      search_value = values%data(values_position)
      if (side_right) then
        insertion_position = searchsorted_right(source, search_value)
      else
        insertion_position = searchsorted_left(source, search_value)
      end if

      output_position = storage_position(output%offset, output%strides, index0)
      output%data(output_position) = insertion_position

      call advance_c_order_index(index0, values%shape)
      if (all(index0 == 0_int64)) exit
    end do

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine copy_searchsorted_values

  integer(int64) function searchsorted_left(source, target) result(position)
    type(ndarray_r64), intent(in) :: source
    real(real64), intent(in) :: target
    integer(int64) :: lower
    integer(int64) :: upper
    integer(int64) :: middle
    real(real64) :: middle_value

    lower = 0_int64
    upper = source%shape(1)

    do while (lower < upper)
      middle = lower + (upper - lower) / 2_int64
      middle_value = source%data(source%offset + middle * source%strides(1))
      ! NaNs form the final equivalence class in NumPy's sorted real order.
      if (ieee_is_nan(middle_value)) then
        upper = middle
      else if (ieee_is_nan(target)) then
        lower = middle + 1_int64
      else if (target <= middle_value) then
        upper = middle
      else
        lower = middle + 1_int64
      end if
    end do

    position = lower
  end function searchsorted_left

  integer(int64) function searchsorted_right(source, target) result(position)
    type(ndarray_r64), intent(in) :: source
    real(real64), intent(in) :: target
    integer(int64) :: lower
    integer(int64) :: upper
    integer(int64) :: middle
    real(real64) :: middle_value

    lower = 0_int64
    upper = source%shape(1)

    do while (lower < upper)
      middle = lower + (upper - lower) / 2_int64
      middle_value = source%data(source%offset + middle * source%strides(1))
      if (ieee_is_nan(target)) then
        lower = middle + 1_int64
      else if (ieee_is_nan(middle_value)) then
        upper = middle
      else if (target < middle_value) then
        upper = middle
      else
        lower = middle + 1_int64
      end if
    end do

    position = lower
  end function searchsorted_right

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

  subroutine set_optional_status_value(status, source_status)
    type(frumpy_status), intent(out), optional :: status
    type(frumpy_status), intent(in) :: source_status

    if (.not. present(status)) return

    status = source_status
  end subroutine set_optional_status_value
end module frumpy_searching_r64
