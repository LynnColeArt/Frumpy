!> Constructors and explicit data-movement helpers for r64 ndarrays.
module frumpy_constructors_r64
  use iso_fortran_env, only: int32, int64, real64
  use frumpy_constants, only: FRUMPY_ORDER_A, FRUMPY_ORDER_C, FRUMPY_ORDER_F, &
    FRUMPY_ORDER_K
  use frumpy_ndarray_r64, only: ndarray_r64, owned_descriptor_r64
  use frumpy_shape, only: element_count
  use frumpy_statuses, only: FRUMPY_STATUS_ALLOCATION_FAILED, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OK, FRUMPY_STATUS_OVERFLOW, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, frumpy_status, set_status

  implicit none

  private

  public :: empty_r64
  public :: zeros_r64
  public :: ones_r64
  public :: full_r64
  public :: arange_r64
  public :: linspace_r64
  public :: copy_r64
  public :: asarray_r64
  public :: ascontiguousarray_r64

contains

  function empty_r64(shape, order, status) result(array)
    integer(int64), intent(in) :: shape(:)
    integer(int32), intent(in), optional :: order
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    if (present(order)) then
      array = owned_descriptor_r64(shape, order, status)
    else
      array = owned_descriptor_r64(shape, status=status)
    end if
  end function empty_r64

  function zeros_r64(shape, order, status) result(array)
    integer(int64), intent(in) :: shape(:)
    integer(int32), intent(in), optional :: order
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = filled_array_r64(shape, 0.0_real64, order, status)
  end function zeros_r64

  function ones_r64(shape, order, status) result(array)
    integer(int64), intent(in) :: shape(:)
    integer(int32), intent(in), optional :: order
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = filled_array_r64(shape, 1.0_real64, order, status)
  end function ones_r64

  function full_r64(shape, fill_value, order, status) result(array)
    integer(int64), intent(in) :: shape(:)
    real(real64), intent(in) :: fill_value
    integer(int32), intent(in), optional :: order
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = filled_array_r64(shape, fill_value, order, status)
  end function full_r64

  function arange_r64(start, stop, step, status) result(array)
    real(real64), intent(in) :: start
    real(real64), intent(in) :: stop
    real(real64), intent(in), optional :: step
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(frumpy_status) :: local_status
    real(real64) :: resolved_step
    real(real64) :: raw_count
    integer(int64) :: count
    integer(int64) :: item1

    resolved_step = 1.0_real64
    if (present(step)) resolved_step = step

    if (abs(resolved_step) <= tiny(resolved_step)) then
      call set_optional_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "arange_r64 step must be non-zero")
      return
    end if

    raw_count = (stop - start) / resolved_step
    if (raw_count <= 0.0_real64) then
      count = 0_int64
    else if (raw_count > real(huge(count), real64)) then
      call set_optional_status(status, FRUMPY_STATUS_OVERFLOW, &
        "arange_r64 element count overflows int64")
      return
    else
      count = ceiling(raw_count, kind=int64)
    end if

    array = empty_r64([count], FRUMPY_ORDER_C, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    do item1 = 1_int64, count
      array%data(item1) = start + real(item1 - 1_int64, real64) * &
        resolved_step
    end do

    call set_optional_status(status, FRUMPY_STATUS_OK)
  end function arange_r64

  function linspace_r64(start, stop, num, endpoint, status) result(array)
    real(real64), intent(in) :: start
    real(real64), intent(in) :: stop
    integer(int64), intent(in) :: num
    logical, intent(in), optional :: endpoint
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(frumpy_status) :: local_status
    logical :: include_endpoint
    real(real64) :: step
    integer(int64) :: item1

    if (num < 0_int64) then
      call set_optional_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "linspace_r64 num must be non-negative")
      return
    end if

    include_endpoint = .true.
    if (present(endpoint)) include_endpoint = endpoint

    array = empty_r64([num], FRUMPY_ORDER_C, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    if (num == 0_int64) then
      call set_optional_status(status, FRUMPY_STATUS_OK)
      return
    end if

    if (num == 1_int64) then
      array%data(1) = start
      call set_optional_status(status, FRUMPY_STATUS_OK)
      return
    end if

    if (include_endpoint) then
      step = (stop - start) / real(num - 1_int64, real64)
      do item1 = 1_int64, num - 1_int64
        array%data(item1) = start + real(item1 - 1_int64, real64) * step
      end do
      array%data(num) = stop
    else
      step = (stop - start) / real(num, real64)
      do item1 = 1_int64, num
        array%data(item1) = start + real(item1 - 1_int64, real64) * step
      end do
    end if

    call set_optional_status(status, FRUMPY_STATUS_OK)
  end function linspace_r64

  function copy_r64(source, order, status) result(array)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in), optional :: order
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(frumpy_status) :: local_status
    integer(int32) :: resolved_order

    resolved_order = resolve_copy_order(source, order, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    if (.not. source%has_storage()) then
      call set_optional_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "copy_r64 requires accessible source storage")
      return
    end if

    if (.not. allocated(source%shape) .or. .not. allocated(source%strides)) then
      call set_optional_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "copy_r64 source descriptor has incomplete metadata")
      return
    end if

    array = empty_r64(source%shape, resolved_order, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    call copy_logical_values(source, array, local_status)
    call set_optional_status_value(status, local_status)
  end function copy_r64

  function asarray_r64(values, shape, order, status) result(array)
    real(real64), intent(in) :: values(:)
    integer(int64), intent(in), optional :: shape(:)
    integer(int32), intent(in), optional :: order
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(frumpy_status) :: local_status
    integer(int64), allocatable :: resolved_shape(:)
    integer(int64) :: expected_count
    integer :: alloc_stat

    if (present(shape)) then
      allocate(resolved_shape(size(shape)), stat=alloc_stat)
      if (alloc_stat /= 0) then
        call set_optional_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
          "asarray_r64 shape allocation failed")
        return
      end if
      resolved_shape = shape
    else
      allocate(resolved_shape(1), stat=alloc_stat)
      if (alloc_stat /= 0) then
        call set_optional_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
          "asarray_r64 shape allocation failed")
        return
      end if
      resolved_shape(1) = int(size(values), int64)
    end if

    expected_count = element_count(resolved_shape, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    if (expected_count /= int(size(values), int64)) then
      call set_optional_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "asarray_r64 shape element count must match values")
      return
    end if

    array = empty_r64(resolved_shape, order, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    call fill_from_c_flat_values(array, values, local_status)
    call set_optional_status_value(status, local_status)
  end function asarray_r64

  function ascontiguousarray_r64(source, status) result(array)
    type(ndarray_r64), intent(in) :: source
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = copy_r64(source, FRUMPY_ORDER_C, status)
  end function ascontiguousarray_r64

  function filled_array_r64(shape, fill_value, order, status) result(array)
    integer(int64), intent(in) :: shape(:)
    real(real64), intent(in) :: fill_value
    integer(int32), intent(in), optional :: order
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(frumpy_status) :: local_status

    array = empty_r64(shape, order, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    if (associated(array%data)) array%data = fill_value
    call set_optional_status(status, FRUMPY_STATUS_OK)
  end function filled_array_r64

  integer(int32) function resolve_copy_order(source, order, status) &
      result(resolved_order)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in), optional :: order
    type(frumpy_status), intent(out) :: status
    integer(int32) :: requested_order

    requested_order = FRUMPY_ORDER_C
    if (present(order)) requested_order = order

    select case (requested_order)
    case (FRUMPY_ORDER_C, FRUMPY_ORDER_F)
      resolved_order = requested_order
    case (FRUMPY_ORDER_A, FRUMPY_ORDER_K)
      if (source%is_f_contiguous .and. .not. source%is_c_contiguous) then
        resolved_order = FRUMPY_ORDER_F
      else
        resolved_order = FRUMPY_ORDER_C
      end if
    case default
      resolved_order = FRUMPY_ORDER_C
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "copy_r64 supports only C, F, A, or K order")
      return
    end select

    call set_status(status, FRUMPY_STATUS_OK)
  end function resolve_copy_order

  subroutine fill_from_c_flat_values(array, values, status)
    type(ndarray_r64), intent(inout) :: array
    real(real64), intent(in) :: values(:)
    type(frumpy_status), intent(out) :: status
    integer(int64), allocatable :: index0(:)
    integer(int64) :: item1
    integer(int64) :: target_position

    if (array%size() == 0_int64) then
      call set_status(status, FRUMPY_STATUS_OK)
      return
    end if

    if (array%rank == 0_int32) then
      array%data(array%offset) = values(1)
      call set_status(status, FRUMPY_STATUS_OK)
      return
    end if

    if (.not. allocate_index_vector(index0, array%rank, status)) return
    index0 = 0_int64

    do item1 = 1_int64, int(size(values), int64)
      target_position = storage_position(array, index0)
      if (.not. is_valid_storage_position(array, target_position)) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
          "asarray_r64 target descriptor references storage out of bounds")
        return
      end if

      array%data(target_position) = values(item1)
      call advance_c_order_index(index0, array%shape)
    end do

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine fill_from_c_flat_values

  subroutine copy_logical_values(source, target, status)
    type(ndarray_r64), intent(in) :: source
    type(ndarray_r64), intent(inout) :: target
    type(frumpy_status), intent(out) :: status
    integer(int64), allocatable :: index0(:)
    integer(int64) :: item1
    integer(int64) :: source_position
    integer(int64) :: target_position

    if (source%size() == 0_int64) then
      call set_status(status, FRUMPY_STATUS_OK)
      return
    end if

    if (source%rank == 0_int32) then
      if (.not. is_valid_storage_position(source, source%offset)) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
          "copy_r64 source scalar references storage out of bounds")
        return
      end if

      target%data(target%offset) = source%data(source%offset)
      call set_status(status, FRUMPY_STATUS_OK)
      return
    end if

    if (.not. allocate_index_vector(index0, source%rank, status)) return
    index0 = 0_int64

    do item1 = 1_int64, source%size()
      source_position = storage_position(source, index0)
      target_position = storage_position(target, index0)

      if (.not. is_valid_storage_position(source, source_position)) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
          "copy_r64 source descriptor references storage out of bounds")
        return
      end if

      if (.not. is_valid_storage_position(target, target_position)) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
          "copy_r64 target descriptor references storage out of bounds")
        return
      end if

      target%data(target_position) = source%data(source_position)
      call advance_c_order_index(index0, source%shape)
    end do

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine copy_logical_values

  integer(int64) function storage_position(array, index0) result(position)
    type(ndarray_r64), intent(in) :: array
    integer(int64), intent(in) :: index0(:)
    integer(int32) :: dim1

    position = array%offset
    do dim1 = 1_int32, int(size(index0), int32)
      position = position + index0(dim1) * array%strides(dim1)
    end do
  end function storage_position

  logical function is_valid_storage_position(array, position)
    type(ndarray_r64), intent(in) :: array
    integer(int64), intent(in) :: position

    is_valid_storage_position = position >= 1_int64 .and. &
      position <= array%storage_size()
  end function is_valid_storage_position

  subroutine advance_c_order_index(index0, shape)
    integer(int64), intent(inout) :: index0(:)
    integer(int64), intent(in) :: shape(:)
    integer(int32) :: dim1

    do dim1 = int(size(shape), int32), 1_int32, -1_int32
      index0(dim1) = index0(dim1) + 1_int64
      if (index0(dim1) < shape(dim1)) return
      index0(dim1) = 0_int64
    end do
  end subroutine advance_c_order_index

  logical function allocate_index_vector(index0, rank, status)
    integer(int64), allocatable, intent(out) :: index0(:)
    integer(int32), intent(in) :: rank
    type(frumpy_status), intent(out) :: status
    integer :: alloc_stat

    allocate(index0(rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      allocate_index_vector = .false.
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "constructor index vector allocation failed")
      return
    end if

    allocate_index_vector = .true.
    call set_status(status, FRUMPY_STATUS_OK)
  end function allocate_index_vector

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
end module frumpy_constructors_r64
