!> Shape validation and element-count helpers for ndarray descriptors.
module fenum_shape
  use iso_fortran_env, only: int32, int64
  use fenum_constants, only: FENUM_MAX_RANK
  use fenum_statuses, only: FENUM_STATUS_INVALID_SHAPE, &
    FENUM_STATUS_OK, FENUM_STATUS_OVERFLOW, fenum_status, set_status

  implicit none

  private

  public :: shape_rank
  public :: validate_shape
  public :: is_valid_shape
  public :: is_scalar_shape
  public :: has_zero_extent
  public :: element_count

contains

  function shape_rank(shape, status) result(rank)
    integer(int64), intent(in) :: shape(:)
    type(fenum_status), intent(out), optional :: status
    integer(int32) :: rank

    call validate_shape(shape, status)

    if (is_valid_shape(shape)) then
      rank = int(size(shape), int32)
    else
      rank = -1_int32
    end if
  end function shape_rank

  subroutine validate_shape(shape, status)
    integer(int64), intent(in) :: shape(:)
    type(fenum_status), intent(out), optional :: status

    if (size(shape) > FENUM_MAX_RANK) then
      call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "shape rank exceeds FENUM_MAX_RANK")
      return
    end if

    if (any(shape < 0_int64)) then
      call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "shape entries must be non-negative")
      return
    end if

    call set_optional_status(status, FENUM_STATUS_OK)
  end subroutine validate_shape

  logical function is_valid_shape(shape)
    integer(int64), intent(in) :: shape(:)

    is_valid_shape = size(shape) <= FENUM_MAX_RANK .and. &
      all(shape >= 0_int64)
  end function is_valid_shape

  logical function is_scalar_shape(shape)
    integer(int64), intent(in) :: shape(:)

    is_scalar_shape = size(shape) == 0
  end function is_scalar_shape

  logical function has_zero_extent(shape)
    integer(int64), intent(in) :: shape(:)

    has_zero_extent = any(shape == 0_int64)
  end function has_zero_extent

  function element_count(shape, status) result(count)
    integer(int64), intent(in) :: shape(:)
    type(fenum_status), intent(out), optional :: status
    integer(int64) :: count
    integer(int32) :: dim1
    integer(int32) :: rank

    if (.not. is_valid_shape(shape)) then
      count = 0_int64
      call validate_shape(shape, status)
      return
    end if

    if (has_zero_extent(shape)) then
      count = 0_int64
      call set_optional_status(status, FENUM_STATUS_OK)
      return
    end if

    count = 1_int64
    rank = int(size(shape), int32)

    do dim1 = 1_int32, rank
      if (.not. can_multiply_int64(count, shape(dim1))) then
        count = 0_int64
        call set_optional_status(status, FENUM_STATUS_OVERFLOW, &
          "shape element count overflows int64")
        return
      end if

      count = count * shape(dim1)
    end do

    call set_optional_status(status, FENUM_STATUS_OK)
  end function element_count

  logical function can_multiply_int64(lhs, rhs)
    integer(int64), intent(in) :: lhs
    integer(int64), intent(in) :: rhs

    if (lhs == 0_int64 .or. rhs == 0_int64) then
      can_multiply_int64 = .true.
    else
      can_multiply_int64 = lhs <= huge(lhs) / rhs
    end if
  end function can_multiply_int64

  subroutine set_optional_status(status, code, message)
    type(fenum_status), intent(out), optional :: status
    integer(int32), intent(in) :: code
    character(len=*), intent(in), optional :: message

    if (.not. present(status)) return

    if (present(message)) then
      call set_status(status, code, message)
    else
      call set_status(status, code)
    end if
  end subroutine set_optional_status
end module fenum_shape
