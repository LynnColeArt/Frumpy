!> Initial r64 elementwise kernels with strided broadcast fallbacks.
module fenum_elementwise_r64
  use iso_fortran_env, only: int32, int64, real64
  use fenum_broadcast, only: broadcast_plan, broadcast_plan_r64
  use fenum_constants, only: FENUM_ORDER_C
  use fenum_constructors_r64, only: empty_r64
  use fenum_ndarray_r64, only: ndarray_r64
  use fenum_statuses, only: FENUM_STATUS_ALLOCATION_FAILED, &
    FENUM_STATUS_INVALID_SHAPE, FENUM_STATUS_OK, &
    FENUM_STATUS_UNSUPPORTED_BEHAVIOR, fenum_status, set_status

  implicit none

  private

  public :: add_r64
  public :: subtract_r64
  public :: multiply_r64
  public :: divide_r64
  public :: negate_r64
  public :: abs_r64
  public :: exp_r64
  public :: log_r64
  public :: sqrt_r64
  public :: sin_r64
  public :: cos_r64

  integer(int32), parameter :: OP_ADD = 1_int32
  integer(int32), parameter :: OP_SUBTRACT = 2_int32
  integer(int32), parameter :: OP_MULTIPLY = 3_int32
  integer(int32), parameter :: OP_DIVIDE = 4_int32
  integer(int32), parameter :: OP_NEGATE = 5_int32
  integer(int32), parameter :: OP_ABS = 6_int32
  integer(int32), parameter :: OP_EXP = 7_int32
  integer(int32), parameter :: OP_LOG = 8_int32
  integer(int32), parameter :: OP_SQRT = 9_int32
  integer(int32), parameter :: OP_SIN = 10_int32
  integer(int32), parameter :: OP_COS = 11_int32

contains

  function add_r64(lhs, rhs, status) result(array)
    type(ndarray_r64), intent(in) :: lhs
    type(ndarray_r64), intent(in) :: rhs
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = binary_r64(lhs, rhs, OP_ADD, status)
  end function add_r64

  function subtract_r64(lhs, rhs, status) result(array)
    type(ndarray_r64), intent(in) :: lhs
    type(ndarray_r64), intent(in) :: rhs
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = binary_r64(lhs, rhs, OP_SUBTRACT, status)
  end function subtract_r64

  function multiply_r64(lhs, rhs, status) result(array)
    type(ndarray_r64), intent(in) :: lhs
    type(ndarray_r64), intent(in) :: rhs
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = binary_r64(lhs, rhs, OP_MULTIPLY, status)
  end function multiply_r64

  function divide_r64(lhs, rhs, status) result(array)
    type(ndarray_r64), intent(in) :: lhs
    type(ndarray_r64), intent(in) :: rhs
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = binary_r64(lhs, rhs, OP_DIVIDE, status)
  end function divide_r64

  function negate_r64(source, status) result(array)
    type(ndarray_r64), intent(in) :: source
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = unary_r64(source, OP_NEGATE, status)
  end function negate_r64

  function abs_r64(source, status) result(array)
    type(ndarray_r64), intent(in) :: source
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = unary_r64(source, OP_ABS, status)
  end function abs_r64

  function exp_r64(source, status) result(array)
    type(ndarray_r64), intent(in) :: source
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = unary_r64(source, OP_EXP, status)
  end function exp_r64

  function log_r64(source, status) result(array)
    type(ndarray_r64), intent(in) :: source
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = unary_r64(source, OP_LOG, status)
  end function log_r64

  function sqrt_r64(source, status) result(array)
    type(ndarray_r64), intent(in) :: source
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = unary_r64(source, OP_SQRT, status)
  end function sqrt_r64

  function sin_r64(source, status) result(array)
    type(ndarray_r64), intent(in) :: source
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = unary_r64(source, OP_SIN, status)
  end function sin_r64

  function cos_r64(source, status) result(array)
    type(ndarray_r64), intent(in) :: source
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = unary_r64(source, OP_COS, status)
  end function cos_r64

  function binary_r64(lhs, rhs, op, status) result(array)
    type(ndarray_r64), intent(in) :: lhs
    type(ndarray_r64), intent(in) :: rhs
    integer(int32), intent(in) :: op
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(broadcast_plan) :: plan
    type(fenum_status) :: local_status
    integer(int64), allocatable :: index0(:)
    integer(int64) :: item1
    integer(int64) :: lhs_position
    integer(int64) :: rhs_position

    if (.not. has_accessible_storage(lhs) .or. &
        .not. has_accessible_storage(rhs)) then
      call set_optional_status(status, FENUM_STATUS_UNSUPPORTED_BEHAVIOR, &
        "binary r64 kernels require accessible source storage")
      return
    end if

    plan = broadcast_plan_r64(lhs, rhs, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    array = empty_r64(plan%shape, FENUM_ORDER_C, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    if (array%size() == 0_int64) then
      call set_optional_status(status, FENUM_STATUS_OK)
      return
    end if

    if (plan%rank == 0_int32) then
      if (.not. valid_position(lhs, lhs%offset) .or. &
          .not. valid_position(rhs, rhs%offset)) then
        call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
          "binary scalar source offset is out of bounds")
        return
      end if

      array%data(1) = apply_binary(op, lhs%data(lhs%offset), &
        rhs%data(rhs%offset))
      call set_optional_status(status, FENUM_STATUS_OK)
      return
    end if

    if (.not. allocate_index_vector(index0, plan%rank, local_status)) then
      call set_optional_status_value(status, local_status)
      return
    end if
    index0 = 0_int64

    do item1 = 1_int64, array%size()
      lhs_position = storage_position(lhs, plan%lhs_strides, index0)
      rhs_position = storage_position(rhs, plan%rhs_strides, index0)

      if (.not. valid_position(lhs, lhs_position) .or. &
          .not. valid_position(rhs, rhs_position)) then
        call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
          "binary broadcast source position is out of bounds")
        return
      end if

      array%data(item1) = apply_binary(op, lhs%data(lhs_position), &
        rhs%data(rhs_position))
      call advance_c_order_index(index0, plan%shape)
    end do

    call set_optional_status(status, FENUM_STATUS_OK)
  end function binary_r64

  function unary_r64(source, op, status) result(array)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in) :: op
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(fenum_status) :: local_status
    integer(int64), allocatable :: index0(:)
    integer(int64) :: item1
    integer(int64) :: source_position

    if (.not. has_accessible_storage(source)) then
      call set_optional_status(status, FENUM_STATUS_UNSUPPORTED_BEHAVIOR, &
        "unary r64 kernels require accessible source storage")
      return
    end if

    if (.not. allocated(source%shape) .or. .not. allocated(source%strides)) then
      call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "unary r64 source descriptor has incomplete metadata")
      return
    end if

    array = empty_r64(source%shape, FENUM_ORDER_C, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    if (array%size() == 0_int64) then
      call set_optional_status(status, FENUM_STATUS_OK)
      return
    end if

    if (source%rank == 0_int32) then
      if (.not. valid_position(source, source%offset)) then
        call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
          "unary scalar source offset is out of bounds")
        return
      end if

      array%data(1) = apply_unary(op, source%data(source%offset))
      call set_optional_status(status, FENUM_STATUS_OK)
      return
    end if

    if (.not. allocate_index_vector(index0, source%rank, local_status)) then
      call set_optional_status_value(status, local_status)
      return
    end if
    index0 = 0_int64

    do item1 = 1_int64, array%size()
      source_position = storage_position(source, source%strides, index0)

      if (.not. valid_position(source, source_position)) then
        call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
          "unary source position is out of bounds")
        return
      end if

      array%data(item1) = apply_unary(op, source%data(source_position))
      call advance_c_order_index(index0, source%shape)
    end do

    call set_optional_status(status, FENUM_STATUS_OK)
  end function unary_r64

  real(real64) function apply_binary(op, lhs, rhs) result(value)
    integer(int32), intent(in) :: op
    real(real64), intent(in) :: lhs
    real(real64), intent(in) :: rhs

    select case (op)
    case (OP_ADD)
      value = lhs + rhs
    case (OP_SUBTRACT)
      value = lhs - rhs
    case (OP_MULTIPLY)
      value = lhs * rhs
    case (OP_DIVIDE)
      value = lhs / rhs
    case default
      value = 0.0_real64
    end select
  end function apply_binary

  real(real64) function apply_unary(op, source) result(value)
    integer(int32), intent(in) :: op
    real(real64), intent(in) :: source

    select case (op)
    case (OP_NEGATE)
      value = -source
    case (OP_ABS)
      value = abs(source)
    case (OP_EXP)
      value = exp(source)
    case (OP_LOG)
      value = log(source)
    case (OP_SQRT)
      value = sqrt(source)
    case (OP_SIN)
      value = sin(source)
    case (OP_COS)
      value = cos(source)
    case default
      value = 0.0_real64
    end select
  end function apply_unary

  logical function has_accessible_storage(array)
    type(ndarray_r64), intent(in) :: array

    has_accessible_storage = array%has_storage()
  end function has_accessible_storage

  integer(int64) function storage_position(array, strides, index0) &
      result(position)
    type(ndarray_r64), intent(in) :: array
    integer(int64), intent(in) :: strides(:)
    integer(int64), intent(in) :: index0(:)
    integer(int32) :: dim1

    position = array%offset
    do dim1 = 1_int32, int(size(index0), int32)
      position = position + index0(dim1) * strides(dim1)
    end do
  end function storage_position

  logical function valid_position(array, position)
    type(ndarray_r64), intent(in) :: array
    integer(int64), intent(in) :: position

    valid_position = position >= 1_int64 .and. &
      position <= array%storage_size()
  end function valid_position

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
    type(fenum_status), intent(out) :: status
    integer :: alloc_stat

    allocate(index0(rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      allocate_index_vector = .false.
      call set_status(status, FENUM_STATUS_ALLOCATION_FAILED, &
        "elementwise index vector allocation failed")
      return
    end if

    allocate_index_vector = .true.
    call set_status(status, FENUM_STATUS_OK)
  end function allocate_index_vector

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

  subroutine set_optional_status_value(status, source_status)
    type(fenum_status), intent(out), optional :: status
    type(fenum_status), intent(in) :: source_status

    if (.not. present(status)) return

    status = source_status
  end subroutine set_optional_status_value
end module fenum_elementwise_r64
