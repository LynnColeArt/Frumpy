!> Concrete bool ndarray descriptor.
module frumpy_ndarray_bool
  use iso_fortran_env, only: int32, int64
  use frumpy_constants, only: FRUMPY_ORDER_C, FRUMPY_ORDER_F
  use frumpy_dtypes, only: FRUMPY_DTYPE_BOOL
  use frumpy_shape, only: element_count, is_valid_shape
  use frumpy_statuses, only: FRUMPY_STATUS_ALLOCATION_FAILED, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, frumpy_status, set_status
  use frumpy_strides, only: c_order_strides, f_order_strides, &
    is_c_contiguous, is_f_contiguous

  implicit none

  private

  public :: ndarray_bool
  public :: owned_descriptor_bool
  public :: metadata_descriptor_bool
  public :: view_descriptor_bool

  type :: ndarray_bool
    integer(int32) :: dtype_id = FRUMPY_DTYPE_BOOL
    integer(int32) :: rank = 0_int32
    integer(int64), allocatable :: shape(:)
    integer(int64), allocatable :: strides(:)
    integer(int64) :: offset = 1_int64
    logical :: owns_data = .false.
    logical :: is_c_contiguous = .false.
    logical :: is_f_contiguous = .false.
    logical, pointer :: data(:) => null()
  contains
    procedure :: size => ndarray_bool_size
    procedure :: storage_size => ndarray_bool_storage_size
    procedure :: has_storage => ndarray_bool_has_storage
  end type ndarray_bool

contains

  function owned_descriptor_bool(shape, order, status) result(array)
    integer(int64), intent(in) :: shape(:)
    integer(int32), intent(in), optional :: order
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: array
    type(frumpy_status) :: local_status
    integer(int32) :: resolved_order
    integer(int64) :: element_count_value
    integer(int64), allocatable :: strides(:)
    integer :: alloc_stat

    resolved_order = FRUMPY_ORDER_C
    if (present(order)) resolved_order = order

    if (resolved_order /= FRUMPY_ORDER_C .and. &
        resolved_order /= FRUMPY_ORDER_F) then
      call set_optional_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "owned_descriptor_bool supports only C or Fortran order")
      return
    end if

    element_count_value = element_count(shape, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    if (resolved_order == FRUMPY_ORDER_F) then
      strides = f_order_strides(shape, local_status)
    else
      strides = c_order_strides(shape, local_status)
    end if

    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    call assign_descriptor_metadata(array, shape, strides, 1_int64, &
      .true., local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    allocate(array%data(element_count_value), stat=alloc_stat)
    if (alloc_stat /= 0) then
      array%owns_data = .false.
      call set_optional_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "ndarray_bool backing storage allocation failed")
      return
    end if

    call set_optional_status(status, FRUMPY_STATUS_OK)
  end function owned_descriptor_bool

  function metadata_descriptor_bool(shape, strides, offset, status) &
      result(array)
    integer(int64), intent(in) :: shape(:)
    integer(int64), intent(in) :: strides(:)
    integer(int64), intent(in) :: offset
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: array
    type(frumpy_status) :: local_status

    call assign_descriptor_metadata(array, shape, strides, offset, .false., &
      local_status)
    call set_optional_status_value(status, local_status)
  end function metadata_descriptor_bool

  function view_descriptor_bool(source, shape, strides, offset, status) &
      result(array)
    type(ndarray_bool), intent(in) :: source
    integer(int64), intent(in) :: shape(:)
    integer(int64), intent(in) :: strides(:)
    integer(int64), intent(in) :: offset
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: array
    type(frumpy_status) :: local_status

    if (.not. source%has_storage()) then
      call set_optional_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "view_descriptor_bool requires source storage")
      return
    end if

    call assign_descriptor_metadata(array, shape, strides, offset, .false., &
      local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    array%data => source%data
    call set_optional_status(status, FRUMPY_STATUS_OK)
  end function view_descriptor_bool

  function ndarray_bool_size(array) result(count)
    class(ndarray_bool), intent(in) :: array
    integer(int64) :: count

    if (.not. allocated(array%shape)) then
      count = 0_int64
    else
      count = element_count(array%shape)
    end if
  end function ndarray_bool_size

  function ndarray_bool_storage_size(array) result(count)
    class(ndarray_bool), intent(in) :: array
    integer(int64) :: count

    if (associated(array%data)) then
      count = int(size(array%data), int64)
    else
      count = 0_int64
    end if
  end function ndarray_bool_storage_size

  logical function ndarray_bool_has_storage(array)
    class(ndarray_bool), intent(in) :: array

    ndarray_bool_has_storage = associated(array%data)
  end function ndarray_bool_has_storage

  subroutine assign_descriptor_metadata(array, shape, strides, offset, &
      owns_data, status)
    type(ndarray_bool), intent(out) :: array
    integer(int64), intent(in) :: shape(:)
    integer(int64), intent(in) :: strides(:)
    integer(int64), intent(in) :: offset
    logical, intent(in) :: owns_data
    type(frumpy_status), intent(out) :: status
    integer :: alloc_stat

    if (.not. is_valid_shape(shape)) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "ndarray_bool shape must be valid")
      return
    end if

    if (size(shape) /= size(strides)) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "ndarray_bool shape and stride ranks must match")
      return
    end if

    if (offset < 1_int64) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "ndarray_bool offset is 1-based and must be positive")
      return
    end if

    allocate(array%shape(size(shape)), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "ndarray_bool shape allocation failed")
      return
    end if

    allocate(array%strides(size(strides)), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "ndarray_bool stride allocation failed")
      return
    end if

    array%dtype_id = FRUMPY_DTYPE_BOOL
    array%rank = int(size(shape), int32)
    array%shape = shape
    array%strides = strides
    array%offset = offset
    array%owns_data = owns_data
    array%is_c_contiguous = is_c_contiguous(shape, strides)
    array%is_f_contiguous = is_f_contiguous(shape, strides)

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine assign_descriptor_metadata

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
end module frumpy_ndarray_bool
