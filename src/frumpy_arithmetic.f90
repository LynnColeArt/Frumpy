!> Arithmetic across registered descriptors, with transactional, caller-typed results.
module frumpy_arithmetic
  use iso_fortran_env, only: int8, int32, int64, real32, real64
  use frumpy_broadcast, only: broadcast_plan, broadcast_plan_from_metadata
  use frumpy_promotion, only: binary_result_dtype
  use frumpy_integer_scalars, only: wrap_i32, wrapped_add_i64, &
    wrapped_subtract_i64, wrapped_multiply_i64
  use frumpy_dtypes, only: FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_I32, FRUMPY_DTYPE_I64, &
    FRUMPY_DTYPE_R32, FRUMPY_DTYPE_R64, FRUMPY_DTYPE_UNSUPPORTED
  use frumpy_strides, only: storage_bounds_are_valid
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_UNSUPPORTED_DTYPE, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_ALLOCATION_FAILED
  use frumpy_ndarray_bool, only: ndarray_bool, owned_descriptor_bool
  use frumpy_ndarray_i32, only: ndarray_i32, owned_descriptor_i32
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64
  use frumpy_ndarray_r32, only: ndarray_r32, owned_descriptor_r32
  use frumpy_ndarray_r64, only: ndarray_r64, owned_descriptor_r64
  implicit none
  private
  public :: add, subtract, multiply, divide

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

  subroutine add(lhs, rhs, result, status)
    class(*), target, intent(in) :: lhs, rhs
    class(*), intent(inout) :: result
    type(frumpy_status), intent(out), optional :: status

    call arithmetic(lhs, rhs, result, 'add', status)
  end subroutine add

  subroutine subtract(lhs, rhs, result, status)
    class(*), target, intent(in) :: lhs, rhs
    class(*), intent(inout) :: result
    type(frumpy_status), intent(out), optional :: status

    call arithmetic(lhs, rhs, result, 'subtract', status)
  end subroutine subtract

  subroutine multiply(lhs, rhs, result, status)
    class(*), target, intent(in) :: lhs, rhs
    class(*), intent(inout) :: result
    type(frumpy_status), intent(out), optional :: status

    call arithmetic(lhs, rhs, result, 'multiply', status)
  end subroutine multiply

  subroutine divide(lhs, rhs, result, status)
    class(*), target, intent(in) :: lhs, rhs
    class(*), intent(inout) :: result
    type(frumpy_status), intent(out), optional :: status

    call arithmetic(lhs, rhs, result, 'divide', status)
  end subroutine divide

  subroutine arithmetic(lhs, rhs, result, operation, status)
    class(*), target, intent(in) :: lhs, rhs
    class(*), intent(inout) :: result
    character(len=*), intent(in) :: operation
    type(frumpy_status), intent(out), optional :: status
    type(operand) :: left, right
    type(broadcast_plan) :: plan
    type(frumpy_status) :: local_status
    integer(int64), allocatable :: index0(:)
    integer(int64) :: item1, left_position, right_position, left_integer, right_integer
    integer(int32) :: dtype_id, alloc_stat

    call bind_operand(lhs, left, local_status)
    if (local_status%is_ok()) call bind_operand(rhs, right, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    dtype_id = binary_result_dtype(left%dtype_id, right%dtype_id, operation, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    if (dtype_id /= descriptor_dtype(result)) then
      call set_status(local_status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
        "result descriptor dtype does not match binary_result_dtype")
      if (present(status)) status = local_status
      return
    end if
    plan = broadcast_plan_from_metadata(left%shape, left%strides, right%shape, &
      right%strides, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    allocate(index0(plan%rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(local_status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "mixed arithmetic index allocation failed")
      if (present(status)) status = local_status
      return
    end if
    index0 = 0_int64
    select type (result)
    type is (ndarray_bool)
      block
        type(ndarray_bool) :: computed

        computed = owned_descriptor_bool(plan%shape, status=local_status)
        if (local_status%is_ok()) then
          do item1 = 1_int64, computed%size()
            left_position = left%offset + sum(index0 * plan%lhs_strides)
            right_position = right%offset + sum(index0 * plan%rhs_strides)
            left_integer = integer_value(left, left_position)
            right_integer = integer_value(right, right_position)
            select case (operation)
            case ('add')
              computed%data(item1) = merge(1_int8, 0_int8, &
                left_integer /= 0_int64 .or. right_integer /= 0_int64)
            case ('multiply')
              computed%data(item1) = merge(1_int8, 0_int8, &
                left_integer /= 0_int64 .and. right_integer /= 0_int64)
            end select
            call advance_index(index0, plan%shape)
          end do
          call result%share_from(computed, local_status)
        end if
      end block
    type is (ndarray_i32)
      block
        type(ndarray_i32) :: computed

        computed = owned_descriptor_i32(plan%shape, status=local_status)
        if (local_status%is_ok()) then
          do item1 = 1_int64, computed%size()
            left_position = left%offset + sum(index0 * plan%lhs_strides)
            right_position = right%offset + sum(index0 * plan%rhs_strides)
            left_integer = integer_value(left, left_position)
            right_integer = integer_value(right, right_position)
            select case (operation)
            case ('add')
              computed%data(item1) = wrap_i32(left_integer + right_integer)
            case ('subtract')
              computed%data(item1) = wrap_i32(left_integer - right_integer)
            case ('multiply')
              computed%data(item1) = wrap_i32(left_integer * right_integer)
            end select
            call advance_index(index0, plan%shape)
          end do
          call result%share_from(computed, local_status)
        end if
      end block
    type is (ndarray_i64)
      block
        type(ndarray_i64) :: computed

        computed = owned_descriptor_i64(plan%shape, status=local_status)
        if (local_status%is_ok()) then
          do item1 = 1_int64, computed%size()
            left_position = left%offset + sum(index0 * plan%lhs_strides)
            right_position = right%offset + sum(index0 * plan%rhs_strides)
            left_integer = integer_value(left, left_position)
            right_integer = integer_value(right, right_position)
            select case (operation)
            case ('add')
              computed%data(item1) = wrapped_add_i64(left_integer, right_integer)
            case ('subtract')
              computed%data(item1) = wrapped_subtract_i64(left_integer, right_integer)
            case ('multiply')
              computed%data(item1) = wrapped_multiply_i64(left_integer, right_integer)
            end select
            call advance_index(index0, plan%shape)
          end do
          call result%share_from(computed, local_status)
        end if
      end block
    type is (ndarray_r32)
      block
        type(ndarray_r32) :: computed

        computed = owned_descriptor_r32(plan%shape, status=local_status)
        if (local_status%is_ok()) then
          do item1 = 1_int64, computed%size()
            left_position = left%offset + sum(index0 * plan%lhs_strides)
            right_position = right%offset + sum(index0 * plan%rhs_strides)
            select case (operation)
            case ('add')
              computed%data(item1) = real32_value(left, left_position) + &
                real32_value(right, right_position)
            case ('subtract')
              computed%data(item1) = real32_value(left, left_position) - &
                real32_value(right, right_position)
            case ('multiply')
              computed%data(item1) = real32_value(left, left_position) * &
                real32_value(right, right_position)
            case ('divide')
              computed%data(item1) = real32_value(left, left_position) / &
                real32_value(right, right_position)
            end select
            call advance_index(index0, plan%shape)
          end do
          call result%share_from(computed, local_status)
        end if
      end block
    type is (ndarray_r64)
      block
        type(ndarray_r64) :: computed

        computed = owned_descriptor_r64(plan%shape, status=local_status)
        if (local_status%is_ok()) then
          do item1 = 1_int64, computed%size()
            left_position = left%offset + sum(index0 * plan%lhs_strides)
            right_position = right%offset + sum(index0 * plan%rhs_strides)
            select case (operation)
            case ('add')
              computed%data(item1) = real64_value(left, left_position) + &
                real64_value(right, right_position)
            case ('subtract')
              computed%data(item1) = real64_value(left, left_position) - &
                real64_value(right, right_position)
            case ('multiply')
              computed%data(item1) = real64_value(left, left_position) * &
                real64_value(right, right_position)
            case ('divide')
              computed%data(item1) = real64_value(left, left_position) / &
                real64_value(right, right_position)
            end select
            call advance_index(index0, plan%shape)
          end do
          call result%share_from(computed, local_status)
        end if
      end block
    end select
    if (present(status)) status = local_status
  end subroutine arithmetic

  subroutine advance_index(index0, shape)
    integer(int64), intent(inout) :: index0(:)
    integer(int64), intent(in) :: shape(:)
    integer(int32) :: dim1

    do dim1 = int(size(shape), int32), 1_int32, -1_int32
      index0(dim1) = index0(dim1) + 1_int64
      if (index0(dim1) < shape(dim1)) exit
      index0(dim1) = 0_int64
    end do
  end subroutine advance_index

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
end module frumpy_arithmetic
