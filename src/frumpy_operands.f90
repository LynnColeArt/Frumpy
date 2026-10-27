!> Call-scoped, validated typed borrows shared by mixed arithmetic, casts and comparisons.
module frumpy_operands
  use iso_fortran_env, only: int8, int32, int64, real32, real64
  use frumpy_dtypes, only: FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_I32, FRUMPY_DTYPE_I64, &
    FRUMPY_DTYPE_R32, FRUMPY_DTYPE_R64, FRUMPY_DTYPE_UNSUPPORTED
  use frumpy_strides, only: storage_bounds_are_valid
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_UNSUPPORTED_DTYPE, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, FRUMPY_STATUS_INVALID_SHAPE
  use frumpy_ndarray_bool, only: ndarray_bool
  use frumpy_ndarray_i32, only: ndarray_i32
  use frumpy_ndarray_i64, only: ndarray_i64
  use frumpy_ndarray_r32, only: ndarray_r32
  use frumpy_ndarray_r64, only: ndarray_r64
  implicit none
  private
  public :: operand, descriptor_dtype, bind_operand, integer_value, real32_value, real64_value
  public :: boolean_value
  ! A call-scoped borrow, never returned or stored in an ndarray. The TARGET input
  ! dummies keep these pointers valid until arithmetic has finished reading them.
  type :: operand
    integer(int32) :: dtype_id = FRUMPY_DTYPE_UNSUPPORTED
    integer(int64), pointer :: shape(:) => null(), strides(:) => null()
    integer(int64) :: offset = 1_int64
    integer(int8), pointer :: values_bool(:) => null()
    integer(int32), pointer :: values_i32(:) => null()
    integer(int64), pointer :: values_i64(:) => null()
    real(real32), pointer :: values_r32(:) => null()
    real(real64), pointer :: values_r64(:) => null()
  end type operand

contains
  function descriptor_dtype(source) result(dtype_id)
    class(*), intent(in) :: source
    integer(int32) :: dtype_id

    dtype_id = FRUMPY_DTYPE_UNSUPPORTED
    select type (source)
    type is (ndarray_bool)
      dtype_id = FRUMPY_DTYPE_BOOL
    type is (ndarray_i32)
      dtype_id = FRUMPY_DTYPE_I32
    type is (ndarray_i64)
      dtype_id = FRUMPY_DTYPE_I64
    type is (ndarray_r32)
      dtype_id = FRUMPY_DTYPE_R32
    type is (ndarray_r64)
      dtype_id = FRUMPY_DTYPE_R64
    end select
  end function descriptor_dtype

  subroutine bind_operand(source, borrowed, status)
    class(*), target, intent(in) :: source
    type(operand), intent(out) :: borrowed
    type(frumpy_status), intent(out) :: status

    borrowed%dtype_id = descriptor_dtype(source)
    select type (source)
    type is (ndarray_bool)
      borrowed%values_bool => source%data
      call bind_metadata(borrowed, source%dtype_id, source%rank, source%shape, source%strides, &
        source%offset, source%storage_size(), source%has_storage(), status)
    type is (ndarray_i32)
      borrowed%values_i32 => source%data
      call bind_metadata(borrowed, source%dtype_id, source%rank, source%shape, source%strides, &
        source%offset, source%storage_size(), source%has_storage(), status)
    type is (ndarray_i64)
      borrowed%values_i64 => source%data
      call bind_metadata(borrowed, source%dtype_id, source%rank, source%shape, source%strides, &
        source%offset, source%storage_size(), source%has_storage(), status)
    type is (ndarray_r32)
      borrowed%values_r32 => source%data
      call bind_metadata(borrowed, source%dtype_id, source%rank, source%shape, source%strides, &
        source%offset, source%storage_size(), source%has_storage(), status)
    type is (ndarray_r64)
      borrowed%values_r64 => source%data
      call bind_metadata(borrowed, source%dtype_id, source%rank, source%shape, source%strides, &
        source%offset, source%storage_size(), source%has_storage(), status)
    class default
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
        "unsupported operand descriptor type")
    end select
  end subroutine bind_operand

  subroutine bind_metadata(borrowed, dtype_id, rank, shape, strides, offset, &
      storage_count, has_storage, status)
    type(operand), intent(inout) :: borrowed
    integer(int32), intent(in) :: dtype_id, rank
    integer(int64), allocatable, target, intent(in) :: shape(:), strides(:)
    integer(int64), intent(in) :: offset, storage_count
    logical, intent(in) :: has_storage
    type(frumpy_status), intent(out) :: status

    if (dtype_id /= borrowed%dtype_id) then
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
        "operand dtype_id disagrees with its concrete descriptor type")
      return
    end if
    if (.not. has_storage) then
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "arithmetic requires input storage")
      return
    end if
    call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
      "invalid operand metadata or reachable storage")
    if (.not. allocated(shape) .or. .not. allocated(strides)) return
    if (rank /= size(shape)) return
    if (.not. storage_bounds_are_valid(shape, strides, offset, storage_count)) return
    borrowed%shape => shape
    borrowed%strides => strides
    borrowed%offset = offset
    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine bind_metadata

  function integer_value(source, position) result(value)
    type(operand), intent(in) :: source
    integer(int64), intent(in) :: position
    integer(int64) :: value

    ! Only boolean/integer operands reach an integer result kernel.
    value = 0_int64
    select case (source%dtype_id)
    case (FRUMPY_DTYPE_BOOL)
      value = merge(1_int64, 0_int64, source%values_bool(position) /= 0_int8)
    case (FRUMPY_DTYPE_I32)
      value = int(source%values_i32(position), int64)
    case (FRUMPY_DTYPE_I64)
      value = source%values_i64(position)
    end select
  end function integer_value

  function real32_value(source, position) result(value)
    type(operand), intent(in) :: source
    integer(int64), intent(in) :: position
    real(real32) :: value

    if (source%dtype_id == FRUMPY_DTYPE_R32) then
      value = source%values_r32(position)
    else if (source%dtype_id == FRUMPY_DTYPE_R64) then
      value = real(source%values_r64(position), real32)
    else
      value = real(integer_value(source, position), real32)
    end if
  end function real32_value

  function real64_value(source, position) result(value)
    type(operand), intent(in) :: source
    integer(int64), intent(in) :: position
    real(real64) :: value

    select case (source%dtype_id)
    case (FRUMPY_DTYPE_R32)
      value = real(source%values_r32(position), real64)
    case (FRUMPY_DTYPE_R64)
      value = source%values_r64(position)
    case default
      value = real(integer_value(source, position), real64)
    end select
  end function real64_value

  logical function boolean_value(source, position) result(value)
    type(operand), intent(in) :: source
    integer(int64), intent(in) :: position

    if (source%dtype_id <= FRUMPY_DTYPE_I64) then
      value = integer_value(source, position) /= 0_int64
    else
      ! Unordered comparison makes NaN true, as with NumPy boolean casts.
      value = .not. (abs(real64_value(source, position)) <= 0.0_real64)
    end if
  end function boolean_value
end module frumpy_operands
