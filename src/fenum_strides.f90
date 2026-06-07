!> Signed element-stride and contiguity helpers for ndarray descriptors.
module fenum_strides
  use iso_fortran_env, only: int32, int64
  use fenum_shape, only: has_zero_extent, is_valid_shape
  use fenum_statuses, only: FENUM_STATUS_ALLOCATION_FAILED, &
    FENUM_STATUS_INVALID_SHAPE, FENUM_STATUS_OK, FENUM_STATUS_OVERFLOW, &
    fenum_status, set_status

  implicit none

  private

  public :: c_order_strides
  public :: f_order_strides
  public :: is_c_contiguous
  public :: is_f_contiguous
  public :: has_negative_stride

contains

  function c_order_strides(shape, status) result(strides)
    integer(int64), intent(in) :: shape(:)
    type(fenum_status), intent(out), optional :: status
    integer(int64), allocatable :: strides(:)
    integer(int32) :: dim1
    integer(int32) :: rank
    integer(int64) :: stride_elements

    call allocate_stride_vector(strides, size(shape), status)
    if (.not. allocated(strides)) return

    strides = 0_int64

    if (.not. is_valid_shape(shape)) then
      call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "cannot compute strides for invalid shape")
      return
    end if

    if (has_zero_extent(shape)) then
      call set_optional_status(status, FENUM_STATUS_OK)
      return
    end if

    stride_elements = 1_int64
    rank = int(size(shape), int32)

    do dim1 = rank, 1_int32, -1_int32
      strides(dim1) = stride_elements

      if (dim1 > 1_int32) then
        if (.not. can_multiply_int64(stride_elements, shape(dim1))) then
          strides = 0_int64
          call set_optional_status(status, FENUM_STATUS_OVERFLOW, &
            "C-order stride computation overflows int64")
          return
        end if

        stride_elements = stride_elements * shape(dim1)
      end if
    end do

    call set_optional_status(status, FENUM_STATUS_OK)
  end function c_order_strides

  function f_order_strides(shape, status) result(strides)
    integer(int64), intent(in) :: shape(:)
    type(fenum_status), intent(out), optional :: status
    integer(int64), allocatable :: strides(:)
    integer(int32) :: dim1
    integer(int32) :: rank
    integer(int64) :: stride_elements

    call allocate_stride_vector(strides, size(shape), status)
    if (.not. allocated(strides)) return

    strides = 0_int64

    if (.not. is_valid_shape(shape)) then
      call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "cannot compute strides for invalid shape")
      return
    end if

    if (has_zero_extent(shape)) then
      call set_optional_status(status, FENUM_STATUS_OK)
      return
    end if

    stride_elements = 1_int64
    rank = int(size(shape), int32)

    do dim1 = 1_int32, rank
      strides(dim1) = stride_elements

      if (dim1 < rank) then
        if (.not. can_multiply_int64(stride_elements, shape(dim1))) then
          strides = 0_int64
          call set_optional_status(status, FENUM_STATUS_OVERFLOW, &
            "Fortran-order stride computation overflows int64")
          return
        end if

        stride_elements = stride_elements * shape(dim1)
      end if
    end do

    call set_optional_status(status, FENUM_STATUS_OK)
  end function f_order_strides

  logical function is_c_contiguous(shape, strides, status)
    integer(int64), intent(in) :: shape(:)
    integer(int64), intent(in) :: strides(:)
    type(fenum_status), intent(out), optional :: status
    integer(int32) :: dim1
    integer(int32) :: rank
    integer(int64) :: expected_stride_elements

    if (.not. validate_contiguity_inputs(shape, strides, status)) then
      is_c_contiguous = .false.
      return
    end if

    if (size(shape) == 0 .or. has_zero_extent(shape)) then
      is_c_contiguous = .true.
      call set_optional_status(status, FENUM_STATUS_OK)
      return
    end if

    expected_stride_elements = 1_int64
    rank = int(size(shape), int32)
    is_c_contiguous = .true.

    do dim1 = rank, 1_int32, -1_int32
      if (shape(dim1) == 1_int64) cycle

      if (strides(dim1) /= expected_stride_elements) then
        is_c_contiguous = .false.
        exit
      end if

      if (dim1 > 1_int32) then
        if (.not. can_multiply_int64(expected_stride_elements, shape(dim1))) then
          is_c_contiguous = .false.
          call set_optional_status(status, FENUM_STATUS_OVERFLOW, &
            "C-contiguity stride expectation overflows int64")
          return
        end if

        expected_stride_elements = expected_stride_elements * shape(dim1)
      end if
    end do

    call set_optional_status(status, FENUM_STATUS_OK)
  end function is_c_contiguous

  logical function is_f_contiguous(shape, strides, status)
    integer(int64), intent(in) :: shape(:)
    integer(int64), intent(in) :: strides(:)
    type(fenum_status), intent(out), optional :: status
    integer(int32) :: dim1
    integer(int32) :: rank
    integer(int64) :: expected_stride_elements

    if (.not. validate_contiguity_inputs(shape, strides, status)) then
      is_f_contiguous = .false.
      return
    end if

    if (size(shape) == 0 .or. has_zero_extent(shape)) then
      is_f_contiguous = .true.
      call set_optional_status(status, FENUM_STATUS_OK)
      return
    end if

    expected_stride_elements = 1_int64
    rank = int(size(shape), int32)
    is_f_contiguous = .true.

    do dim1 = 1_int32, rank
      if (shape(dim1) == 1_int64) cycle

      if (strides(dim1) /= expected_stride_elements) then
        is_f_contiguous = .false.
        exit
      end if

      if (dim1 < rank) then
        if (.not. can_multiply_int64(expected_stride_elements, shape(dim1))) then
          is_f_contiguous = .false.
          call set_optional_status(status, FENUM_STATUS_OVERFLOW, &
            "Fortran-contiguity stride expectation overflows int64")
          return
        end if

        expected_stride_elements = expected_stride_elements * shape(dim1)
      end if
    end do

    call set_optional_status(status, FENUM_STATUS_OK)
  end function is_f_contiguous

  logical function has_negative_stride(strides)
    integer(int64), intent(in) :: strides(:)

    has_negative_stride = any(strides < 0_int64)
  end function has_negative_stride

  subroutine allocate_stride_vector(strides, rank, status)
    integer(int64), allocatable, intent(out) :: strides(:)
    integer, intent(in) :: rank
    type(fenum_status), intent(out), optional :: status
    integer :: alloc_stat

    allocate(strides(rank), stat=alloc_stat)

    if (alloc_stat /= 0) then
      call set_optional_status(status, FENUM_STATUS_ALLOCATION_FAILED, &
        "stride vector allocation failed")
    end if
  end subroutine allocate_stride_vector

  logical function validate_contiguity_inputs(shape, strides, status)
    integer(int64), intent(in) :: shape(:)
    integer(int64), intent(in) :: strides(:)
    type(fenum_status), intent(out), optional :: status

    validate_contiguity_inputs = .false.

    if (.not. is_valid_shape(shape)) then
      call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "cannot check contiguity for invalid shape")
      return
    end if

    if (size(shape) /= size(strides)) then
      call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "shape and stride ranks must match")
      return
    end if

    validate_contiguity_inputs = .true.
  end function validate_contiguity_inputs

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
end module fenum_strides
