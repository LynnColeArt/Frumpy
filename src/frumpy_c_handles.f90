!> ABI-private handle registry. Callers serialize entry; IDs are never reused.
module frumpy_c_handles
  use iso_c_binding, only: c_ptr, c_associated, c_f_pointer, c_int64_t
  use iso_fortran_env, only: int32, int64
  use frumpy, only: ndarray_bool, ndarray_i32, ndarray_i64, ndarray_r32, &
    ndarray_r64, random_generator
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_ALLOCATION_FAILED, FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_INVALID_HANDLE, &
    FRUMPY_STATUS_OVERFLOW, FRUMPY_STATUS_UNSUPPORTED_DTYPE
  use frumpy_constants, only: FRUMPY_MAX_RANK
  implicit none
  private
  public :: handle_slot, new_array_slot, new_rng_slot, lookup, publish, discard, output_pointer
  public :: read_shape, read_parameters, retain_handle, release_handle
  type :: handle_slot
    integer(int64) :: id = 0_int64, references = 1_int64
    integer(int32) :: kind = 1_int32
    class(*), allocatable :: array
    type(random_generator) :: generator
    type(handle_slot), pointer :: next => null()
  end type handle_slot
  type :: handle_bucket
    type(handle_slot), pointer :: first => null()
  end type handle_bucket
  type(handle_bucket), allocatable, save :: buckets(:)
  integer(int64), save :: live_handles = 0_int64
  integer(int64), save :: next_id = 1_int64
contains
  subroutine output_pointer(address, output, status)
    type(c_ptr), intent(in) :: address
    integer(c_int64_t), pointer, intent(out) :: output
    type(frumpy_status), intent(out) :: status

    nullify(output)
    call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, "null output handle pointer")
    if (.not. c_associated(address)) return
    call c_f_pointer(address, output)
    output = 0_c_int64_t
    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine output_pointer

  subroutine read_parameters(address, count, values, status)
    type(c_ptr), intent(in) :: address
    integer(int32), intent(in) :: count
    integer(int64), allocatable, intent(out) :: values(:)
    type(frumpy_status), intent(out) :: status
    integer(c_int64_t), pointer :: input(:)
    integer(int32) :: alloc_stat

    call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, "invalid ABI parameter buffer")
    if (count < 0_int32 .or. count > 3_int32 * FRUMPY_MAX_RANK) return
    if (count > 0_int32 .and. .not. c_associated(address)) return
    allocate(values(count), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, "ABI metadata allocation")
      return
    end if
    if (count > 0_int32) then
      call c_f_pointer(address, input, [count])
      values = input
    end if
    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine read_parameters

  subroutine read_shape(address, rank, shape, status)
    type(c_ptr), intent(in) :: address
    integer(int32), intent(in) :: rank
    integer(int64), allocatable, intent(out) :: shape(:)
    type(frumpy_status), intent(out) :: status

    if (rank < 0_int32 .or. rank > FRUMPY_MAX_RANK) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, "ABI rank out of bounds")
      return
    end if
    call read_parameters(address, rank, shape, status)
  end subroutine read_shape

  subroutine new_rng_slot(slot, status)
    type(handle_slot), pointer, intent(out) :: slot
    type(frumpy_status), intent(out) :: status
    integer(int32) :: alloc_stat

    nullify(slot)
    if (next_id == 0_int64) then
      call set_status(status, FRUMPY_STATUS_OVERFLOW, "handle ID space exhausted")
      return
    end if
    allocate(slot, stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, "handle allocation")
      return
    end if
    slot%kind = 2_int32
    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine new_rng_slot

  subroutine new_array_slot(dtype, slot, status)
    integer(int32), intent(in) :: dtype
    type(handle_slot), pointer, intent(out) :: slot
    type(frumpy_status), intent(out) :: status
    integer(int32) :: alloc_stat

    nullify(slot)
    if (dtype < 1_int32 .or. dtype > 5_int32) then
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, "unknown ABI dtype")
      return
    end if
    call new_rng_slot(slot, status)
    if (status%is_failure()) return
    slot%kind = 1_int32
    select case (dtype)
    case (1)
      allocate(ndarray_bool :: slot%array, stat=alloc_stat)
    case (2)
      allocate(ndarray_i32 :: slot%array, stat=alloc_stat)
    case (3)
      allocate(ndarray_i64 :: slot%array, stat=alloc_stat)
    case (4)
      allocate(ndarray_r32 :: slot%array, stat=alloc_stat)
    case (5)
      allocate(ndarray_r64 :: slot%array, stat=alloc_stat)
    end select
    if (alloc_stat /= 0) then
      call discard(slot)
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, "typed handle allocation")
    end if
  end subroutine new_array_slot

  function lookup(id, kind, status) result(slot)
    integer(int64), intent(in) :: id
    integer(int32), intent(in) :: kind
    type(frumpy_status), intent(out) :: status
    type(handle_slot), pointer :: slot

    if (.not. allocated(buckets)) then
      nullify(slot)
      call set_status(status, FRUMPY_STATUS_INVALID_HANDLE, "invalid or released handle")
      return
    end if
    slot => buckets(bucket_index(id))%first
    do while (associated(slot))
      if (slot%id == id) then
        if (kind == 0_int32 .or. slot%kind == kind) then
          call set_status(status, FRUMPY_STATUS_OK)
          return
        end if
        exit
      end if
      slot => slot%next
    end do
    nullify(slot)
    call set_status(status, FRUMPY_STATUS_INVALID_HANDLE, "invalid, released or wrong-kind handle")
  end function lookup

  subroutine publish(slot, output, status)
    type(handle_slot), pointer, intent(inout) :: slot
    integer(c_int64_t), intent(out) :: output
    type(frumpy_status), intent(inout) :: status

    output = 0_c_int64_t
    if (status%is_failure()) then
      call discard(slot)
      return
    end if
    call reserve_handles(status)
    if (status%is_failure()) then
      call discard(slot)
      return
    end if
    slot%id = next_id
    if (next_id == huge(1_int64)) then
      next_id = 0_int64
    else
      next_id = next_id + 1_int64
    end if
    slot%next => buckets(bucket_index(slot%id))%first
    buckets(bucket_index(slot%id))%first => slot
    live_handles = live_handles + 1_int64
    output = slot%id
    nullify(slot)
  end subroutine publish

  subroutine discard(slot)
    type(handle_slot), pointer, intent(inout) :: slot

    if (.not. associated(slot)) return
    ! Deallocation finalizes the scalar polymorphic component and its typed backing reference.
    if (allocated(slot%array)) deallocate(slot%array)
    deallocate(slot)
    nullify(slot)
  end subroutine discard

  subroutine retain_handle(id, status)
    integer(int64), intent(in) :: id
    type(frumpy_status), intent(out) :: status
    type(handle_slot), pointer :: slot

    slot => lookup(id, 0_int32, status)
    if (status%is_failure()) return
    if (slot%references == huge(1_int64)) then
      call set_status(status, FRUMPY_STATUS_OVERFLOW, "handle retain count overflow")
    else
      slot%references = slot%references + 1_int64
    end if
  end subroutine retain_handle

  subroutine release_handle(id, status)
    integer(int64), intent(in) :: id
    type(frumpy_status), intent(out) :: status
    type(handle_slot), pointer :: slot, previous
    integer :: bucket1

    slot => lookup(id, 0_int32, status)
    if (status%is_failure()) return
    slot%references = slot%references - 1_int64
    if (slot%references > 0_int64) return
    bucket1 = bucket_index(id)
    if (associated(buckets(bucket1)%first, slot)) then
      buckets(bucket1)%first => slot%next
    else
      previous => buckets(bucket1)%first
      do while (associated(previous))
        if (associated(previous%next, slot)) exit
        previous => previous%next
      end do
      previous%next => slot%next
    end if
    call discard(slot)
    live_handles = live_handles - 1_int64
    if (live_handles == 0_int64) deallocate(buckets)
  end subroutine release_handle

  integer function bucket_index(id) result(index1)
    integer(int64), intent(in) :: id

    index1 = int(modulo(id, int(size(buckets), int64))) + 1
  end function bucket_index

  subroutine reserve_handles(status)
    type(frumpy_status), intent(out) :: status
    type(handle_bucket), allocatable :: expanded(:)
    type(handle_slot), pointer :: slot, following
    integer :: bucket1, index1, count, alloc_stat

    call set_status(status, FRUMPY_STATUS_OK)
    if (.not. allocated(buckets)) then
      allocate(buckets(64), stat=alloc_stat)
      if (alloc_stat /= 0) call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "handle index allocation failed")
      return
    end if
    count = size(buckets)
    if (live_handles < 2_int64 * int(count, int64)) return
    if (count > shiftr(huge(count), 1)) return
    allocate(expanded(2 * count), stat=alloc_stat)
    ! Growth is optional: allocation failure keeps the correct, slower old table.
    if (alloc_stat /= 0) return
    do bucket1 = 1, count
      slot => buckets(bucket1)%first
      do while (associated(slot))
        following => slot%next
        index1 = int(modulo(slot%id, int(size(expanded), int64))) + 1
        slot%next => expanded(index1)%first
        expanded(index1)%first => slot
        slot => following
      end do
      nullify(buckets(bucket1)%first)
    end do
    call move_alloc(expanded, buckets)
  end subroutine reserve_handles
end module frumpy_c_handles
