!> Same-dtype selection with shared metadata traversal and exact typed copies.
module frumpy_selection
  use iso_fortran_env, only: int8, int32, int64
  use frumpy_constants, only: FRUMPY_MAX_RANK, FRUMPY_ORDER_C, FRUMPY_ORDER_F
  use frumpy_operands, only: operand, bind_operand, descriptor_dtype
  use frumpy_shape, only: element_count
  use frumpy_strides, only: flat_offset, is_c_contiguous, is_f_contiguous
  use frumpy_dtypes, only: dtype_byte_size
  use frumpy_selection_r64, only: where_r64, take_r64, concatenate_r64, stack_r64
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_INVALID_AXIS, FRUMPY_STATUS_OVERFLOW, &
    FRUMPY_STATUS_UNSUPPORTED_DTYPE, FRUMPY_STATUS_ALLOCATION_FAILED
  use frumpy_ndarray_bool, only: ndarray_bool, owned_descriptor_bool
  use frumpy_ndarray_i32, only: ndarray_i32, owned_descriptor_i32
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64
  use frumpy_ndarray_r32, only: ndarray_r32, owned_descriptor_r32
  implicit none
  private
  public :: where, where_bool, where_i32, where_i64, where_r32
  interface where
    module procedure where_bool, where_i32, where_i64, where_r32
    procedure :: where_r64
  end interface where
  public :: take, take_bool, take_i32, take_i64, take_r32
  interface take
    module procedure take_bool, take_i32, take_i64, take_r32
    procedure :: take_r64
  end interface take
  public :: concatenate, concatenate_bool, concatenate_i32, concatenate_i64, concatenate_r32
  interface concatenate
    module procedure concatenate_bool, concatenate_i32, concatenate_i64, concatenate_r32
    procedure :: concatenate_r64
  end interface concatenate
  public :: stack, stack_bool, stack_i32, stack_i64, stack_r32
  interface stack
    module procedure stack_bool, stack_i32, stack_i64, stack_r32
    procedure :: stack_r64
  end interface stack
contains
  function where_bool(condition, lhs, rhs, status) result(array)
    type(ndarray_bool), target, intent(in) :: condition
    type(ndarray_bool), target, intent(in) :: lhs, rhs
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_bool), target :: array
    type(frumpy_status) :: local

    call select_where(condition, lhs, rhs, array, local)
    if (present(status)) status = local
  end function where_bool

  function take_bool(source, indices, axis0, status) result(array)
    type(ndarray_bool), target, intent(in) :: source
    integer(int64), intent(in) :: indices(:)
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_bool), target :: array
    type(frumpy_status) :: local

    call select_take(source, indices, array, axis0, local)
    if (present(status)) status = local
  end function take_bool

  function concatenate_bool(arrays, axis0, status) result(array)
    type(ndarray_bool), target, intent(in) :: arrays(:)
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_bool), target :: array
    type(frumpy_status) :: local

    call select_join(arrays, array, .false., axis0, local)
    if (present(status)) status = local
  end function concatenate_bool

  function stack_bool(arrays, axis0, status) result(array)
    type(ndarray_bool), target, intent(in) :: arrays(:)
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_bool), target :: array
    type(frumpy_status) :: local

    call select_join(arrays, array, .true., axis0, local)
    if (present(status)) status = local
  end function stack_bool

  function where_i32(condition, lhs, rhs, status) result(array)
    type(ndarray_bool), target, intent(in) :: condition
    type(ndarray_i32), target, intent(in) :: lhs, rhs
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i32), target :: array
    type(frumpy_status) :: local

    call select_where(condition, lhs, rhs, array, local)
    if (present(status)) status = local
  end function where_i32

  function take_i32(source, indices, axis0, status) result(array)
    type(ndarray_i32), target, intent(in) :: source
    integer(int64), intent(in) :: indices(:)
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i32), target :: array
    type(frumpy_status) :: local

    call select_take(source, indices, array, axis0, local)
    if (present(status)) status = local
  end function take_i32

  function concatenate_i32(arrays, axis0, status) result(array)
    type(ndarray_i32), target, intent(in) :: arrays(:)
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i32), target :: array
    type(frumpy_status) :: local

    call select_join(arrays, array, .false., axis0, local)
    if (present(status)) status = local
  end function concatenate_i32

  function stack_i32(arrays, axis0, status) result(array)
    type(ndarray_i32), target, intent(in) :: arrays(:)
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i32), target :: array
    type(frumpy_status) :: local

    call select_join(arrays, array, .true., axis0, local)
    if (present(status)) status = local
  end function stack_i32

  function where_i64(condition, lhs, rhs, status) result(array)
    type(ndarray_bool), target, intent(in) :: condition
    type(ndarray_i64), target, intent(in) :: lhs, rhs
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i64), target :: array
    type(frumpy_status) :: local

    call select_where(condition, lhs, rhs, array, local)
    if (present(status)) status = local
  end function where_i64

  function take_i64(source, indices, axis0, status) result(array)
    type(ndarray_i64), target, intent(in) :: source
    integer(int64), intent(in) :: indices(:)
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i64), target :: array
    type(frumpy_status) :: local

    call select_take(source, indices, array, axis0, local)
    if (present(status)) status = local
  end function take_i64

  function concatenate_i64(arrays, axis0, status) result(array)
    type(ndarray_i64), target, intent(in) :: arrays(:)
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i64), target :: array
    type(frumpy_status) :: local

    call select_join(arrays, array, .false., axis0, local)
    if (present(status)) status = local
  end function concatenate_i64

  function stack_i64(arrays, axis0, status) result(array)
    type(ndarray_i64), target, intent(in) :: arrays(:)
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i64), target :: array
    type(frumpy_status) :: local

    call select_join(arrays, array, .true., axis0, local)
    if (present(status)) status = local
  end function stack_i64

  function where_r32(condition, lhs, rhs, status) result(array)
    type(ndarray_bool), target, intent(in) :: condition
    type(ndarray_r32), target, intent(in) :: lhs, rhs
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_r32), target :: array
    type(frumpy_status) :: local

    call select_where(condition, lhs, rhs, array, local)
    if (present(status)) status = local
  end function where_r32

  function take_r32(source, indices, axis0, status) result(array)
    type(ndarray_r32), target, intent(in) :: source
    integer(int64), intent(in) :: indices(:)
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_r32), target :: array
    type(frumpy_status) :: local

    call select_take(source, indices, array, axis0, local)
    if (present(status)) status = local
  end function take_r32

  function concatenate_r32(arrays, axis0, status) result(array)
    type(ndarray_r32), target, intent(in) :: arrays(:)
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_r32), target :: array
    type(frumpy_status) :: local

    call select_join(arrays, array, .false., axis0, local)
    if (present(status)) status = local
  end function concatenate_r32

  function stack_r32(arrays, axis0, status) result(array)
    type(ndarray_r32), target, intent(in) :: arrays(:)
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_r32), target :: array
    type(frumpy_status) :: local

    call select_join(arrays, array, .true., axis0, local)
    if (present(status)) status = local
  end function stack_r32

  subroutine select_where(condition, lhs, rhs, array, status)
    type(ndarray_bool), target, intent(in) :: condition
    class(*), target, intent(in) :: lhs, rhs
    class(*), target, intent(inout) :: array
    type(frumpy_status), intent(out) :: status
    type(operand) :: mask, left, right, output
    integer(int64) :: shape(FRUMPY_MAX_RANK), coordinates(FRUMPY_MAX_RANK)
    integer(int64) :: i, count, position
    integer(int32) :: rank

    call bind_operand(condition, mask, status)
    if (status%is_ok()) call bind_operand(lhs, left, status)
    if (status%is_ok()) call bind_operand(rhs, right, status)
    if (status%is_failure()) return
    if (left%dtype_id /= right%dtype_id) then
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, 'where requires matching value dtypes')
      return
    end if
    rank = max(size(mask%shape), size(left%shape), size(right%shape))
    shape = 1_int64
    call broadcast_shape(mask, shape(:rank), status)
    if (status%is_ok()) call broadcast_shape(left, shape(:rank), status)
    if (status%is_ok()) call broadcast_shape(right, shape(:rank), status)
    if (status%is_failure()) return
    call create_output(array, shape(:rank), FRUMPY_ORDER_C, output, status)
    if (status%is_failure()) return
    count = element_count(shape(:rank))
    do i = 0_int64, count - 1_int64
      call coordinates_of(i, shape(:rank), coordinates(:rank))
      position = broadcast_position(mask, coordinates(:rank))
      if (mask%values_bool(position) /= 0_int8) then
        call copy_value(left, broadcast_position(left, coordinates(:rank)), output, i + 1_int64)
      else
        call copy_value(right, broadcast_position(right, coordinates(:rank)), output, i + 1_int64)
      end if
    end do
  end subroutine select_where

  subroutine select_take(source, indices, array, axis0, status)
    class(*), target, intent(in) :: source
    integer(int64), intent(in) :: indices(:)
    class(*), target, intent(inout) :: array
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), intent(out) :: status
    type(operand) :: input, output
    integer(int64) :: shape(FRUMPY_MAX_RANK), coordinates(FRUMPY_MAX_RANK)
    integer(int64) :: extent, i, index0, position, count
    integer(int32) :: rank, dim1, output_rank

    call bind_operand(source, input, status)
    if (status%is_failure()) return
    rank = size(input%shape)
    dim1 = 0
    extent = element_count(input%shape, status)
    if (status%is_failure()) return
    if (present(axis0)) then
      dim1 = axis_dimension(axis0, max(1, rank), status)
      if (status%is_failure()) return
      if (rank == 0) then
        dim1 = 0
      else
        extent = input%shape(dim1)
      end if
    end if
    ! Validate even when another dimension makes the output empty.
    do i = 1_int64, size(indices, kind=int64)
      if (indices(i) < -extent .or. indices(i) >= extent) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, 'take index out of bounds')
        return
      end if
    end do
    output_rank = max(1, rank)
    if (dim1 == 0) then
      output_rank = 1
      shape(1) = size(indices, kind=int64)
    else
      shape(:rank) = input%shape
      shape(dim1) = size(indices, kind=int64)
    end if
    call create_output(array, shape(:output_rank), FRUMPY_ORDER_C, output, status)
    if (status%is_failure()) return
    count = element_count(shape(:output_rank))
    do i = 0_int64, count - 1_int64
      call coordinates_of(i, shape(:output_rank), coordinates(:output_rank))
      index0 = indices(coordinates(max(1, dim1)) + 1_int64)
      if (index0 < 0_int64) index0 = index0 + extent
      if (dim1 == 0) then
        position = flat_offset(input%shape, input%strides, input%offset, index0)
      else
        coordinates(dim1) = index0
        position = input%offset + sum(coordinates(:rank) * input%strides)
      end if
      call copy_value(input, position, output, i + 1_int64)
    end do
  end subroutine select_take

  subroutine select_join(arrays, array, stacking, axis0, status)
    class(*), target, intent(in) :: arrays(:)
    class(*), target, intent(inout) :: array
    logical, intent(in) :: stacking
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), intent(out) :: status
    type(operand), allocatable :: inputs(:)
    type(operand) :: output
    integer(int64) :: shape(FRUMPY_MAX_RANK), coordinates(FRUMPY_MAX_RANK)
    integer(int64) :: destination(FRUMPY_MAX_RANK), start, i, count, position
    integer(int32) :: rank, output_rank, dim1, axis, item, j, order
    integer :: alloc_stat
    logical :: all_fortran, any_non_c

    call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, 'join requires inputs')
    if (size(arrays) == 0) return
    allocate(inputs(size(arrays)), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED)
      return
    end if
    do item = 1, size(arrays)
      call bind_operand(arrays(item), inputs(item), status)
      if (status%is_failure()) return
    end do
    rank = size(inputs(1)%shape)
    output_rank = rank
    if (stacking) output_rank = rank + 1
    if (output_rank == 0 .or. output_rank > FRUMPY_MAX_RANK) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, 'unsupported join rank')
      return
    end if
    axis = 0
    if (present(axis0)) axis = axis0
    dim1 = axis_dimension(axis, output_rank, status)
    if (status%is_failure()) return
    shape(:rank) = inputs(1)%shape
    start = 0_int64
    all_fortran = .true.
    any_non_c = .false.
    do item = 1, size(arrays)
      if (inputs(item)%dtype_id /= inputs(1)%dtype_id) then
        call set_status(status, FRUMPY_STATUS_UNSUPPORTED_DTYPE)
        return
      end if
      if (size(inputs(item)%shape) /= rank) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, 'join ranks differ')
        return
      end if
      do j = 1, rank
        if (.not. stacking .and. j == dim1) cycle
        if (inputs(item)%shape(j) /= inputs(1)%shape(j)) then
          call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, 'join shapes differ')
          return
        end if
      end do
      if (.not. stacking) then
        if (inputs(item)%shape(dim1) > huge(start) - start) then
          call set_status(status, FRUMPY_STATUS_OVERFLOW, 'join axis extent overflow')
          return
        end if
        start = start + inputs(item)%shape(dim1)
      end if
      all_fortran = all_fortran .and. is_f_contiguous(inputs(item)%shape, inputs(item)%strides)
      any_non_c = any_non_c .or. .not. is_c_contiguous(inputs(item)%shape, inputs(item)%strides)
    end do
    order = FRUMPY_ORDER_C
    if (stacking) then
      shape(:dim1-1) = inputs(1)%shape(:dim1-1)
      shape(dim1) = size(arrays, kind=int64)
      shape(dim1+1:output_rank) = inputs(1)%shape(dim1:rank)
    else
      shape(dim1) = start
      if (all_fortran .and. any_non_c) order = FRUMPY_ORDER_F
    end if
    call create_output(array, shape(:output_rank), order, output, status)
    if (status%is_failure()) return
    start = 0_int64
    do item = 1, size(arrays)
      count = element_count(inputs(item)%shape)
      do i = 0_int64, count - 1_int64
        call coordinates_of(i, inputs(item)%shape, coordinates(:rank))
        if (stacking) then
          destination(:dim1-1) = coordinates(:dim1-1)
          destination(dim1) = int(item - 1, int64)
          destination(dim1+1:output_rank) = coordinates(dim1:rank)
        else
          destination(:rank) = coordinates(:rank)
          destination(dim1) = destination(dim1) + start
        end if
        position = output%offset + sum(destination(:output_rank) * output%strides)
        call copy_value(inputs(item), flat_offset(inputs(item)%shape, inputs(item)%strides, &
          inputs(item)%offset, i), output, position)
      end do
      if (.not. stacking) start = start + inputs(item)%shape(dim1)
    end do
  end subroutine select_join

  integer(int32) function axis_dimension(axis0, rank, status) result(dim1)
    integer(int32), intent(in) :: axis0, rank
    type(frumpy_status), intent(out) :: status
    integer(int64) :: axis

    axis = int(axis0, int64)
    if (axis < 0_int64) axis = axis + int(rank, int64)
    dim1 = 0
    call set_status(status, FRUMPY_STATUS_INVALID_AXIS)
    if (axis < 0_int64 .or. axis >= int(rank, int64)) return
    dim1 = int(axis, int32) + 1_int32
    call set_status(status, FRUMPY_STATUS_OK)
  end function axis_dimension

  subroutine coordinates_of(index0, shape, coordinates)
    integer(int64), intent(in) :: index0, shape(:)
    integer(int64), intent(out) :: coordinates(:)
    integer(int64) :: remaining
    integer :: dim1

    remaining = index0
    do dim1 = size(shape), 1, -1
      coordinates(dim1) = modulo(remaining, shape(dim1))
      remaining = remaining / shape(dim1)
    end do
  end subroutine coordinates_of

  subroutine broadcast_shape(input, shape, status)
    type(operand), intent(in) :: input
    integer(int64), intent(inout) :: shape(:)
    type(frumpy_status), intent(out) :: status
    integer :: dim1, mapped

    call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, 'incompatible where shapes')
    do dim1 = 1, size(input%shape)
      mapped = size(shape) - size(input%shape) + dim1
      if (shape(mapped) == 1_int64) then
        shape(mapped) = input%shape(dim1)
      else if (input%shape(dim1) /= 1_int64 .and. input%shape(dim1) /= shape(mapped)) then
        return
      end if
    end do
    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine broadcast_shape

  integer(int64) function broadcast_position(input, coordinates) result(position)
    type(operand), intent(in) :: input
    integer(int64), intent(in) :: coordinates(:)
    integer :: dim1, mapped

    position = input%offset
    do dim1 = 1, size(input%shape)
      mapped = size(coordinates) - size(input%shape) + dim1
      if (input%shape(dim1) /= 1_int64) &
        position = position + coordinates(mapped) * input%strides(dim1)
    end do
  end function broadcast_position

  subroutine create_output(array, shape, order, output, status)
    class(*), target, intent(inout) :: array
    integer(int64), intent(in) :: shape(:)
    integer(int32), intent(in) :: order
    type(operand), intent(out) :: output
    type(frumpy_status), intent(out) :: status
    integer(int64) :: count, bytes

    count = element_count(shape, status)
    if (status%is_failure()) return
    bytes = dtype_byte_size(descriptor_dtype(array))
    if (count > huge(count) / bytes) then
      call set_status(status, FRUMPY_STATUS_OVERFLOW, 'selection output byte count overflow')
      return
    end if
    select type (array)
    type is (ndarray_bool)
      array = owned_descriptor_bool(shape, order, status)
    type is (ndarray_i32)
      array = owned_descriptor_i32(shape, order, status)
    type is (ndarray_i64)
      array = owned_descriptor_i64(shape, order, status)
    type is (ndarray_r32)
      array = owned_descriptor_r32(shape, order, status)
    end select
    if (status%is_ok()) call bind_operand(array, output, status)
  end subroutine create_output

  subroutine copy_value(input, source_position, output, output_position)
    type(operand), intent(in) :: input, output
    integer(int64), intent(in) :: source_position, output_position

    select case (input%dtype_id)
    case (1)
      output%values_bool(output_position) = merge(1_int8, 0_int8, input%values_bool(source_position) /= 0_int8)
    case (2)
      output%values_i32(output_position) = input%values_i32(source_position)
    case (3)
      output%values_i64(output_position) = input%values_i64(source_position)
    case (4)
      output%values_r32(output_position) = input%values_r32(source_position)
    end select
  end subroutine copy_value
end module frumpy_selection
