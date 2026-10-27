!> Concrete i64 constructors; values are supplied in C logical order.
module frumpy_constructors_i64
  use iso_fortran_env, only: int32, int64
  use frumpy_constants, only: FRUMPY_ORDER_C, FRUMPY_ORDER_F, FRUMPY_ORDER_A, FRUMPY_ORDER_K
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64
  use frumpy_dtypes, only: FRUMPY_DTYPE_I64
  use frumpy_strides, only: storage_bounds_are_valid, flat_offset, is_f_contiguous, is_c_contiguous
  use frumpy_shape, only: element_count
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_OVERFLOW, FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR
  implicit none
  private
  public :: empty_i64, zeros_i64, ones_i64, full_i64, asarray_i64, copy_i64, ascontiguousarray_i64
  public :: validate_i64
contains
  function empty_i64(shape, order, status) result(array)
    integer(int64), intent(in) :: shape(:)
    integer(int32), intent(in), optional :: order
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array
    type(frumpy_status) :: local_status
    integer(int64) :: count

    count = element_count(shape, local_status)
    if (local_status%is_ok()) then
      if (count > shiftr(huge(1_int64), 3)) &
        call set_status(local_status, FRUMPY_STATUS_OVERFLOW, "constructor byte count overflow")
    end if
    if (local_status%is_ok()) array = owned_descriptor_i64(shape, order, local_status)
    if (present(status)) status = local_status
  end function empty_i64

  function full_i64(shape, fill_value, order, status) result(array)
    integer(int64), intent(in) :: shape(:)
    integer(int64), intent(in) :: fill_value
    integer(int32), intent(in), optional :: order
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array
    type(frumpy_status) :: local_status

    array = empty_i64(shape, order, local_status)
    if (local_status%is_ok()) array%data = fill_value
    if (present(status)) status = local_status
  end function full_i64

  function zeros_i64(shape, order, status) result(array)
    integer(int64), intent(in) :: shape(:)
    integer(int32), intent(in), optional :: order
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array

    array = full_i64(shape, 0_int64, order, status)
  end function zeros_i64

  function ones_i64(shape, order, status) result(array)
    integer(int64), intent(in) :: shape(:)
    integer(int32), intent(in), optional :: order
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array

    array = full_i64(shape, 1_int64, order, status)
  end function ones_i64

  function asarray_i64(values, shape, order, status) result(array)
    integer(int64), intent(in) :: values(:)
    integer(int64), intent(in), optional :: shape(:)
    integer(int32), intent(in), optional :: order
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array
    type(frumpy_status) :: local_status
    integer(int64) :: count, i0, position

    call set_status(local_status, FRUMPY_STATUS_OK)
    count = size(values, kind=int64)
    if (present(shape)) count = element_count(shape, local_status)
    if (local_status%is_ok() .and. count /= size(values, kind=int64)) &
      call set_status(local_status, FRUMPY_STATUS_INVALID_SHAPE, &
        "asarray shape differs from values")
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    if (present(shape)) then
      array = empty_i64(shape, order, local_status)
    else
      array = empty_i64([count], order, local_status)
    end if
    if (present(status)) status = local_status
    if (local_status%is_failure()) return
    do i0 = 0_int64, count - 1_int64
      position = flat_offset(array%shape, array%strides, array%offset, i0)
      array%data(position) = values(i0 + 1_int64)
    end do
  end function asarray_i64

  !> Always copy; A/K choose F only for exclusively F-contiguous sources.
  function copy_i64(source, order, status) result(array)
    type(ndarray_i64), intent(in) :: source
    integer(int32), intent(in), optional :: order
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array
    type(frumpy_status) :: local_status
    integer(int32) :: resolved_order
    integer(int64) :: i0, source_position, target_position

    call validate_i64(source, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    resolved_order = FRUMPY_ORDER_C
    if (present(order)) resolved_order = order
    select case (resolved_order)
    case (FRUMPY_ORDER_A, FRUMPY_ORDER_K)
      resolved_order = FRUMPY_ORDER_C
      if (is_f_contiguous(source%shape, source%strides) .and. &
          .not. is_c_contiguous(source%shape, source%strides)) resolved_order = FRUMPY_ORDER_F
    case (FRUMPY_ORDER_C, FRUMPY_ORDER_F)
    case default
      call set_status(local_status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, "invalid copy order")
      if (present(status)) status = local_status
      return
    end select
    array = empty_i64(source%shape, resolved_order, local_status)
    if (present(status)) status = local_status
    if (local_status%is_failure()) return
    do i0 = 0_int64, source%size() - 1_int64
      source_position = flat_offset(source%shape, source%strides, source%offset, i0)
      target_position = flat_offset(array%shape, array%strides, array%offset, i0)
      array%data(target_position) = source%data(source_position)
    end do
  end function copy_i64

  !> Like the existing r64 API, this explicitly copies even a contiguous source.
  function ascontiguousarray_i64(source, status) result(array)
    type(ndarray_i64), intent(in) :: source
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array

    array = copy_i64(source, FRUMPY_ORDER_C, status)
  end function ascontiguousarray_i64

  subroutine validate_i64(source, status)
    type(ndarray_i64), intent(in) :: source
    type(frumpy_status), intent(out) :: status

    if (source%dtype_id /= FRUMPY_DTYPE_I64) then
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
        "descriptor dtype disagrees with type")
      return
    end if
    if (.not. source%has_storage()) then
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, "source requires storage")
      return
    end if
    call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "invalid source metadata or storage bounds")
    if (.not. allocated(source%shape) .or. .not. allocated(source%strides)) return
    if (source%rank /= size(source%shape)) return
    if (.not. storage_bounds_are_valid(source%shape, source%strides, source%offset, &
        source%storage_size())) return
    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine validate_i64
end module frumpy_constructors_i64
