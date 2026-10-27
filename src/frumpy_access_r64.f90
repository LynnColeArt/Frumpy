!> Validated float64 descriptor access shared by numerical kernels.
module frumpy_access_r64
  use iso_fortran_env, only: int32, int64
  use frumpy_dtypes, only: FRUMPY_DTYPE_R64
  use frumpy_ndarray_r64, only: ndarray_r64
  use frumpy_strides, only: storage_bounds_are_valid
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_UNSUPPORTED_DTYPE, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    FRUMPY_STATUS_INVALID_SHAPE
  implicit none
  private
  public :: validate_r64, position_r64, flat_offset
contains
  subroutine validate_r64(source, status)
    type(ndarray_r64), intent(in) :: source
    type(frumpy_status), intent(out) :: status

    if (source%dtype_id /= FRUMPY_DTYPE_R64) then
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, "float64 operation requires float64")
      return
    end if
    if (.not. source%has_storage()) then
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "float64 operation requires storage")
      return
    end if
    call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, "invalid float64 operation input metadata")
    if (.not. allocated(source%shape) .or. .not. allocated(source%strides)) return
    if (source%rank /= size(source%shape)) return
    if (.not. storage_bounds_are_valid(source%shape, source%strides, source%offset, &
        source%storage_size())) return
    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine validate_r64

  !> Caller validates reachable storage and only visits nonempty shapes.
  integer(int64) function flat_offset(shape, strides, offset, flat_index0) result(position)
    integer(int64), intent(in) :: shape(:), strides(:), offset, flat_index0
    integer(int64) :: remainder
    integer(int32) :: dim1

    position = offset
    remainder = flat_index0
    do dim1 = int(size(shape), int32), 1_int32, -1_int32
      position = position + modulo(remainder, shape(dim1)) * strides(dim1)
      remainder = remainder / shape(dim1)
    end do
  end function flat_offset

  integer(int64) function position_r64(source, flat_index0) result(position)
    type(ndarray_r64), intent(in) :: source
    integer(int64), intent(in) :: flat_index0

    position = flat_offset(source%shape, source%strides, source%offset, flat_index0)
  end function position_r64
end module frumpy_access_r64
