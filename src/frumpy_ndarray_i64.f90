!> Concrete i64 ndarray descriptor.
module frumpy_ndarray_i64
  use iso_fortran_env, only: int32, int64
  use frumpy_constants, only: FRUMPY_ORDER_C, FRUMPY_ORDER_F
  use frumpy_dtypes, only: FRUMPY_DTYPE_I64
  use frumpy_shape, only: element_count, is_valid_shape
  use frumpy_statuses, only: FRUMPY_STATUS_ALLOCATION_FAILED, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, frumpy_status, set_status
  use frumpy_strides, only: allocate_c_order_strides, allocate_f_order_strides, &
    is_c_contiguous, is_f_contiguous

  implicit none

  private

  public :: ndarray_i64
  public :: owned_descriptor_i64
  public :: metadata_descriptor_i64
  public :: view_descriptor_i64
  public :: share_descriptors_i64

  type :: storage_i64
    integer(int64) :: references = 1_int64
    integer(int64), pointer :: values(:) => null()
  end type storage_i64

  type :: ndarray_i64
    integer(int32) :: dtype_id = FRUMPY_DTYPE_I64
    integer(int32) :: rank = 0_int32
    integer(int64), allocatable :: shape(:)
    integer(int64), allocatable :: strides(:)
    integer(int64) :: offset = 1_int64
    logical :: owns_data = .false.
    logical :: is_c_contiguous = .false.
    logical :: is_f_contiguous = .false.
    integer(int64), pointer :: data(:) => null()
    type(storage_i64), pointer, private :: backing => null()
  contains
    procedure :: release => ndarray_i64_release
    procedure :: share_from => ndarray_i64_share_from
    procedure, private :: assign => ndarray_i64_assign
    generic, public :: assignment(=) => assign
    final :: ndarray_i64_finalize
    procedure :: size => ndarray_i64_size
    procedure :: storage_size => ndarray_i64_storage_size
    procedure :: has_storage => ndarray_i64_has_storage
  end type ndarray_i64

contains

  function owned_descriptor_i64(shape, order, status) result(array)
    integer(int64), intent(in) :: shape(:)
    integer(int32), intent(in), optional :: order
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array
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
        "owned_descriptor_i64 supports only C or Fortran order")
      return
    end if

    element_count_value = element_count(shape, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    if (resolved_order == FRUMPY_ORDER_F) then
      call allocate_f_order_strides(shape, strides, local_status)
    else
      call allocate_c_order_strides(shape, strides, local_status)
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

    allocate(array%backing, stat=alloc_stat)
    if (alloc_stat == 0) then
      allocate(array%backing%values(element_count_value), stat=alloc_stat)
    end if
    if (alloc_stat /= 0) then
      call array%release()
      call set_optional_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "ndarray_i64 backing storage allocation failed")
      return
    end if

    array%data => array%backing%values
    call set_optional_status(status, FRUMPY_STATUS_OK)
  end function owned_descriptor_i64

  function metadata_descriptor_i64(shape, strides, offset, status) &
      result(array)
    integer(int64), intent(in) :: shape(:)
    integer(int64), intent(in) :: strides(:)
    integer(int64), intent(in) :: offset
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array
    type(frumpy_status) :: local_status

    call assign_descriptor_metadata(array, shape, strides, offset, .false., &
      local_status)
    call set_optional_status_value(status, local_status)
  end function metadata_descriptor_i64

  function view_descriptor_i64(source, shape, strides, offset, status) &
      result(array)
    type(ndarray_i64), intent(in) :: source
    integer(int64), intent(in) :: shape(:)
    integer(int64), intent(in) :: strides(:)
    integer(int64), intent(in) :: offset
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array
    type(frumpy_status) :: local_status

    if (.not. source%has_storage()) then
      call set_optional_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "view_descriptor_i64 requires source storage")
      return
    end if

    call assign_descriptor_metadata(array, shape, strides, offset, .false., &
      local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    ! Managed views retain the backing allocation, independently of the source descriptor.
    array%backing => source%backing
    if (associated(array%backing)) array%backing%references = array%backing%references + 1_int64
    array%data => source%data
    call set_optional_status(status, FRUMPY_STATUS_OK)
  end function view_descriptor_i64

  !> Release this descriptor's reference; other managed aliases remain valid.
  subroutine ndarray_i64_release(array)
    class(ndarray_i64), intent(inout) :: array

    nullify(array%data)
    if (associated(array%backing)) then
      array%backing%references = array%backing%references - 1_int64
      if (array%backing%references == 0_int64) then
        if (associated(array%backing%values)) deallocate(array%backing%values)
        deallocate(array%backing)
      end if
      nullify(array%backing)
    end if
    if (allocated(array%shape)) deallocate(array%shape)
    if (allocated(array%strides)) deallocate(array%strides)
    array%dtype_id = FRUMPY_DTYPE_I64
    array%rank = 0_int32
    array%offset = 1_int64
    array%owns_data = .false.
    array%is_c_contiguous = .false.
    array%is_f_contiguous = .false.
  end subroutine ndarray_i64_release

  impure elemental subroutine ndarray_i64_finalize(array)
    type(ndarray_i64), intent(inout) :: array

    call array%release()
  end subroutine ndarray_i64_finalize

  subroutine ndarray_i64_assign(destination, source)
    class(ndarray_i64), intent(inout) :: destination
    type(ndarray_i64), intent(in) :: source

    call destination%share_from(source)
  end subroutine ndarray_i64_assign

  subroutine share_descriptors_i64(destination, source, status)
    class(ndarray_i64), intent(inout) :: destination(:)
    type(ndarray_i64), intent(in) :: source(:)
    type(ndarray_i64), allocatable :: retained(:)
    type(frumpy_status), intent(out), optional :: status
    type(frumpy_status) :: local_status
    integer :: alloc_stat
    integer(int64) :: item1

    if (size(destination) /= size(source)) then
      call set_optional_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "descriptor vectors must have equal lengths")
      return
    end if
    allocate(retained(size(source)), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_optional_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "descriptor vector snapshot allocation failed")
      return
    end if
    ! Snapshot every RHS descriptor before replacing overlapping array sections.
    do item1 = 1_int64, size(source, kind=int64)
      call retained(item1)%share_from(source(item1), local_status)
      if (local_status%is_failure()) then
        call set_optional_status_value(status, local_status)
        return
      end if
    end do
    ! Commit already-staged metadata without allocation: failure cannot leave a prefix updated.
    do item1 = 1_int64, size(destination, kind=int64)
      call move_descriptor_i64(destination(item1), retained(item1))
    end do
    call set_optional_status(status, FRUMPY_STATUS_OK)
  end subroutine share_descriptors_i64

  !> Copy descriptor metadata and retain storage; failure leaves destination unchanged.
  subroutine ndarray_i64_share_from(destination, source, status)
    class(ndarray_i64), intent(inout) :: destination
    type(ndarray_i64), intent(in) :: source
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: retained
    integer :: alloc_stat

    ! Avoid invalidating metadata in GFortran's shallow self-assignment temporary.
    if (same_descriptor(destination, source)) then
      call set_optional_status(status, FRUMPY_STATUS_OK)
      return
    end if

    ! Snapshot and retain before releasing: source can alias destination's buffer.
    if (allocated(source%shape)) then
      allocate(retained%shape, source=source%shape, stat=alloc_stat)
      if (alloc_stat /= 0) then
        call set_optional_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
          "ndarray_i64 assignment shape allocation failed")
        return
      end if
    end if
    if (allocated(source%strides)) then
      allocate(retained%strides, source=source%strides, stat=alloc_stat)
      if (alloc_stat /= 0) then
        call set_optional_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
          "ndarray_i64 assignment strides allocation failed")
        return
      end if
    end if
    retained%dtype_id = source%dtype_id
    retained%rank = source%rank
    retained%offset = source%offset
    retained%owns_data = source%owns_data
    retained%is_c_contiguous = source%is_c_contiguous
    retained%is_f_contiguous = source%is_f_contiguous
    retained%data => source%data
    retained%backing => source%backing
    if (associated(retained%backing)) then
      retained%backing%references = retained%backing%references + 1_int64
    end if

    call move_descriptor_i64(destination, retained)
    call set_optional_status(status, FRUMPY_STATUS_OK)
  end subroutine ndarray_i64_share_from

  ! The source is a private staged descriptor, distinct from destination.
  subroutine move_descriptor_i64(destination, retained)
    class(ndarray_i64), intent(inout) :: destination
    type(ndarray_i64), intent(inout) :: retained

    call destination%release()
    call move_alloc(retained%shape, destination%shape)
    call move_alloc(retained%strides, destination%strides)
    destination%dtype_id = retained%dtype_id
    destination%rank = retained%rank
    destination%offset = retained%offset
    destination%owns_data = retained%owns_data
    destination%is_c_contiguous = retained%is_c_contiguous
    destination%is_f_contiguous = retained%is_f_contiguous
    destination%data => retained%data
    destination%backing => retained%backing
    nullify(retained%backing, retained%data)
  end subroutine move_descriptor_i64

  logical function same_descriptor(lhs, rhs) result(same)
    class(ndarray_i64), intent(in) :: lhs
    type(ndarray_i64), intent(in) :: rhs

    same = .false.
    if (associated(lhs%backing) .neqv. associated(rhs%backing)) return
    if (associated(lhs%backing)) then
      if (.not. associated(lhs%backing, rhs%backing)) return
    else
      if (associated(lhs%data) .neqv. associated(rhs%data)) return
      if (associated(lhs%data)) then
        ! ASSOCIATED(a,b) is false for zero-sized targets, including a itself.
        if (size(lhs%data, kind=int64) /= 0_int64 .or. &
            size(rhs%data, kind=int64) /= 0_int64) then
          if (.not. associated(lhs%data, rhs%data)) return
        end if
      end if
    end if
    if (lhs%dtype_id /= rhs%dtype_id .or. lhs%rank /= rhs%rank) return
    if (lhs%offset /= rhs%offset) return
    if (lhs%owns_data .neqv. rhs%owns_data) return
    if (lhs%is_c_contiguous .neqv. rhs%is_c_contiguous) return
    if (lhs%is_f_contiguous .neqv. rhs%is_f_contiguous) return
    if (allocated(lhs%shape) .neqv. allocated(rhs%shape)) return
    if (allocated(lhs%strides) .neqv. allocated(rhs%strides)) return
    if (allocated(lhs%shape)) then
      if (size(lhs%shape) /= size(rhs%shape)) return
      if (any(lhs%shape /= rhs%shape)) return
    end if
    if (allocated(lhs%strides)) then
      if (size(lhs%strides) /= size(rhs%strides)) return
      if (any(lhs%strides /= rhs%strides)) return
    end if
    same = .true.
  end function same_descriptor

  function ndarray_i64_size(array) result(count)
    class(ndarray_i64), intent(in) :: array
    integer(int64) :: count

    if (.not. allocated(array%shape)) then
      count = 0_int64
    else
      count = element_count(array%shape)
    end if
  end function ndarray_i64_size

  function ndarray_i64_storage_size(array) result(count)
    class(ndarray_i64), intent(in) :: array
    integer(int64) :: count

    if (associated(array%data)) then
      count = int(size(array%data), int64)
    else
      count = 0_int64
    end if
  end function ndarray_i64_storage_size

  logical function ndarray_i64_has_storage(array)
    class(ndarray_i64), intent(in) :: array

    ndarray_i64_has_storage = associated(array%data)
  end function ndarray_i64_has_storage

  subroutine assign_descriptor_metadata(array, shape, strides, offset, &
      owns_data, status)
    type(ndarray_i64), intent(out) :: array
    integer(int64), intent(in) :: shape(:)
    integer(int64), intent(in) :: strides(:)
    integer(int64), intent(in) :: offset
    logical, intent(in) :: owns_data
    type(frumpy_status), intent(out) :: status
    integer :: alloc_stat

    if (.not. is_valid_shape(shape)) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "ndarray_i64 shape must be valid")
      return
    end if

    if (size(shape) /= size(strides)) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "ndarray_i64 shape and stride ranks must match")
      return
    end if

    if (offset < 1_int64) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "ndarray_i64 offset is 1-based and must be positive")
      return
    end if

    allocate(array%shape(size(shape)), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "ndarray_i64 shape allocation failed")
      return
    end if

    allocate(array%strides(size(strides)), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "ndarray_i64 stride allocation failed")
      return
    end if

    array%dtype_id = FRUMPY_DTYPE_I64
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
end module frumpy_ndarray_i64
