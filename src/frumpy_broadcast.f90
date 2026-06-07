!> NumPy-style trailing-dimension broadcast planning.
module frumpy_broadcast
  use iso_fortran_env, only: int32, int64
  use frumpy_ndarray_r64, only: ndarray_r64
  use frumpy_shape, only: element_count, is_valid_shape
  use frumpy_statuses, only: FRUMPY_STATUS_ALLOCATION_FAILED, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OK, frumpy_status, set_status

  implicit none

  private

  public :: broadcast_plan
  public :: broadcast_plan_r64

  type :: broadcast_plan
    integer(int32) :: rank = 0_int32
    integer(int64), allocatable :: shape(:)
    integer(int64), allocatable :: lhs_strides(:)
    integer(int64), allocatable :: rhs_strides(:)
  contains
    procedure :: size => broadcast_plan_size
  end type broadcast_plan

contains

  function broadcast_plan_r64(lhs, rhs, status) result(plan)
    type(ndarray_r64), intent(in) :: lhs
    type(ndarray_r64), intent(in) :: rhs
    type(frumpy_status), intent(out), optional :: status
    type(broadcast_plan) :: plan
    integer(int32) :: result_rank
    integer(int32) :: result_dim1
    integer(int32) :: lhs_dim1
    integer(int32) :: rhs_dim1
    integer(int64) :: lhs_extent
    integer(int64) :: rhs_extent
    integer(int64) :: result_extent

    if (.not. has_descriptor_metadata(lhs) .or. &
        .not. has_descriptor_metadata(rhs)) then
      call set_optional_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "broadcast inputs must have shape and stride metadata")
      return
    end if

    if (.not. is_valid_shape(lhs%shape) .or. &
        .not. is_valid_shape(rhs%shape)) then
      call set_optional_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "broadcast input shape must be valid")
      return
    end if

    result_rank = max(lhs%rank, rhs%rank)
    if (.not. allocate_plan_vectors(plan, result_rank, status)) return

    plan%rank = result_rank
    plan%shape = 1_int64
    plan%lhs_strides = 0_int64
    plan%rhs_strides = 0_int64

    do result_dim1 = result_rank, 1_int32, -1_int32
      lhs_dim1 = lhs%rank - (result_rank - result_dim1)
      rhs_dim1 = rhs%rank - (result_rank - result_dim1)

      lhs_extent = extent_or_one(lhs, lhs_dim1)
      rhs_extent = extent_or_one(rhs, rhs_dim1)

      if (.not. broadcast_extents_match(lhs_extent, rhs_extent)) then
        call set_optional_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
          "broadcast dimensions are incompatible")
        return
      end if

      result_extent = broadcast_result_extent(lhs_extent, rhs_extent)
      plan%shape(result_dim1) = result_extent
      plan%lhs_strides(result_dim1) = broadcast_stride(lhs, lhs_dim1)
      plan%rhs_strides(result_dim1) = broadcast_stride(rhs, rhs_dim1)
    end do

    call set_optional_status(status, FRUMPY_STATUS_OK)
  end function broadcast_plan_r64

  function broadcast_plan_size(plan, status) result(count)
    class(broadcast_plan), intent(in) :: plan
    type(frumpy_status), intent(out), optional :: status
    integer(int64) :: count

    if (.not. allocated(plan%shape)) then
      count = 0_int64
      call set_optional_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "broadcast plan shape is not allocated")
      return
    end if

    count = element_count(plan%shape, status)
  end function broadcast_plan_size

  logical function has_descriptor_metadata(array)
    type(ndarray_r64), intent(in) :: array

    has_descriptor_metadata = allocated(array%shape) .and. &
      allocated(array%strides) .and. &
      size(array%shape) == size(array%strides) .and. &
      array%rank == int(size(array%shape), int32)
  end function has_descriptor_metadata

  integer(int64) function extent_or_one(array, dim1) result(extent)
    type(ndarray_r64), intent(in) :: array
    integer(int32), intent(in) :: dim1

    if (dim1 < 1_int32) then
      extent = 1_int64
    else
      extent = array%shape(dim1)
    end if
  end function extent_or_one

  logical function broadcast_extents_match(lhs_extent, rhs_extent)
    integer(int64), intent(in) :: lhs_extent
    integer(int64), intent(in) :: rhs_extent

    broadcast_extents_match = lhs_extent == rhs_extent .or. &
      lhs_extent == 1_int64 .or. rhs_extent == 1_int64
  end function broadcast_extents_match

  integer(int64) function broadcast_result_extent(lhs_extent, rhs_extent) &
      result(extent)
    integer(int64), intent(in) :: lhs_extent
    integer(int64), intent(in) :: rhs_extent

    if (lhs_extent == rhs_extent) then
      extent = lhs_extent
    else if (lhs_extent == 1_int64) then
      extent = rhs_extent
    else
      extent = lhs_extent
    end if
  end function broadcast_result_extent

  integer(int64) function broadcast_stride(array, dim1) result(stride)
    type(ndarray_r64), intent(in) :: array
    integer(int32), intent(in) :: dim1

    if (dim1 < 1_int32) then
      stride = 0_int64
    else if (array%shape(dim1) == 1_int64) then
      stride = 0_int64
    else
      stride = array%strides(dim1)
    end if
  end function broadcast_stride

  logical function allocate_plan_vectors(plan, rank, status)
    type(broadcast_plan), intent(out) :: plan
    integer(int32), intent(in) :: rank
    type(frumpy_status), intent(out), optional :: status
    integer :: alloc_stat

    allocate(plan%shape(rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      allocate_plan_vectors = .false.
      call set_optional_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "broadcast shape allocation failed")
      return
    end if

    allocate(plan%lhs_strides(rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      allocate_plan_vectors = .false.
      call set_optional_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "broadcast lhs stride allocation failed")
      return
    end if

    allocate(plan%rhs_strides(rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      allocate_plan_vectors = .false.
      call set_optional_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "broadcast rhs stride allocation failed")
      return
    end if

    allocate_plan_vectors = .true.
    call set_optional_status(status, FRUMPY_STATUS_OK)
  end function allocate_plan_vectors

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
end module frumpy_broadcast
