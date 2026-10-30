!> Zero-based coordinates in C logical order for all registered value dtypes.
module frumpy_coordinates
  use iso_fortran_env, only: int32, int64
  use frumpy_operands, only: operand, bind_operand, boolean_value
  use frumpy_shape, only: element_count
  use frumpy_strides, only: flat_offset
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64, view_descriptor_i64
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_INVALID_SHAPE, &
    FRUMPY_STATUS_OVERFLOW, FRUMPY_STATUS_ALLOCATION_FAILED
  implicit none
  private
  public :: argwhere, nonzero, release_nonzero
contains
  function argwhere(source, status) result(indices)
    class(*), target, intent(in) :: source
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i64) :: indices
    type(frumpy_status) :: local

    indices = coordinate_matrix(source, .false., local)
    if (present(status)) status = local
  end function argwhere

  ! Transfer the descriptor container explicitly; no intrinsic container copying.
  ! On failure an existing output remains intact, with no partial new result.
  subroutine nonzero(source, axes, status)
    class(*), target, intent(in) :: source
    type(ndarray_i64), allocatable, intent(inout) :: axes(:)
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i64) :: packed
    type(ndarray_i64), allocatable :: staged(:)
    type(frumpy_status) :: local
    integer(int32) :: dim1, alloc_stat
    integer(int64) :: count

    packed = coordinate_matrix(source, .true., local)
    if (local%is_ok()) then
      allocate(staged(packed%shape(1)), stat=alloc_stat)
      if (alloc_stat /= 0) call set_status(local, FRUMPY_STATUS_ALLOCATION_FAILED)
    end if
    if (local%is_ok()) then
      count = packed%shape(2)
      do dim1 = 1, size(staged)
        staged(dim1) = view_descriptor_i64(packed, [count], [1_int64], &
          1_int64 + int(dim1 - 1, int64) * count, local)
        if (local%is_failure()) exit
      end do
    end if
    if (local%is_ok()) then
      call release_nonzero(axes)
      call move_alloc(staged, axes)
    end if
    call release_nonzero(staged)
    if (present(status)) status = local
  end subroutine nonzero

  subroutine release_nonzero(axes)
    type(ndarray_i64), allocatable, intent(inout) :: axes(:)
    integer(int32) :: dim1

    if (.not. allocated(axes)) return
    do dim1 = 1, size(axes)
      call axes(dim1)%release()
    end do
    deallocate(axes)
  end subroutine release_nonzero

  function coordinate_matrix(source, columns, status) result(indices)
    class(*), target, intent(in) :: source
    logical, intent(in) :: columns
    type(frumpy_status), intent(out) :: status
    type(ndarray_i64) :: indices
    type(operand) :: input
    integer(int32) :: rank, dim1
    integer(int64) :: count, i0, position, selected, remaining, coordinate

    call bind_operand(source, input, status)
    if (status%is_failure()) return
    rank = size(input%shape)
    if (columns .and. rank == 0) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, 'nonzero requires at least one dimension')
      return
    end if
    count = 0_int64
    do i0 = 0_int64, element_count(input%shape) - 1_int64
      position = flat_offset(input%shape, input%strides, input%offset, i0)
      if (boolean_value(input, position)) count = count + 1_int64
    end do
    if (rank > 0) then
      if (count > shiftr(huge(count), 3) / int(rank, int64)) then
        call set_status(status, FRUMPY_STATUS_OVERFLOW, 'coordinate result bytes overflow')
        return
      end if
    end if
    if (columns) then
      indices = owned_descriptor_i64([int(rank, int64), count], status=status)
    else
      indices = owned_descriptor_i64([count, int(rank, int64)], status=status)
    end if
    if (status%is_failure()) return
    selected = 0_int64
    do i0 = 0_int64, element_count(input%shape) - 1_int64
      position = flat_offset(input%shape, input%strides, input%offset, i0)
      if (.not. boolean_value(input, position)) cycle
      remaining = i0
      do dim1 = rank, 1, -1
        coordinate = modulo(remaining, input%shape(dim1))
        remaining = remaining / input%shape(dim1)
        if (columns) then
          position = int(dim1 - 1, int64) * count + selected + 1_int64
        else
          position = selected * int(rank, int64) + int(dim1, int64)
        end if
        indices%data(position) = coordinate
      end do
      selected = selected + 1_int64
    end do
  end function coordinate_matrix
end module frumpy_coordinates
