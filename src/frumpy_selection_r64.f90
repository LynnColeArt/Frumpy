!> Initial r64 selection helpers for concatenation, stacking, where, and take.
module frumpy_selection_r64
  use iso_fortran_env, only: int8, int32, int64
  use frumpy_strides, only: storage_bounds_are_valid
  use frumpy_constants, only: FRUMPY_ORDER_C, FRUMPY_ORDER_F
  use frumpy_constructors_r64, only: empty_r64
  use frumpy_ndarray_bool, only: ndarray_bool
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64
  use frumpy_ndarray_r64, only: ndarray_r64
  use frumpy_statuses, only: FRUMPY_STATUS_ALLOCATION_FAILED, &
    FRUMPY_STATUS_INVALID_AXIS, FRUMPY_STATUS_INVALID_SHAPE, &
    FRUMPY_STATUS_OK, FRUMPY_STATUS_OVERFLOW, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, frumpy_status, set_status

  implicit none

  private

  public :: nonzero_bool
  public :: where_r64
  public :: take_r64
  public :: concatenate_r64
  public :: stack_r64

contains

  function nonzero_bool(source, status) result(array)
    type(ndarray_bool), intent(in) :: source
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_i64) :: array
    type(frumpy_status) :: local_status
    integer(int64) :: count

    call validate_selection_source_bool(source, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    call count_nonzero_values_bool(source, count, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    array = owned_descriptor_i64([count], FRUMPY_ORDER_C, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    call copy_nonzero_values_bool(source, array, local_status)
    call set_optional_status_value(status, local_status)
  end function nonzero_bool

  function where_r64(condition, lhs, rhs, status) result(array)
    type(ndarray_bool), intent(in) :: condition
    type(ndarray_r64), intent(in) :: lhs
    type(ndarray_r64), intent(in) :: rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(frumpy_status) :: local_status
    integer(int64), allocatable :: output_shape(:)
    integer(int64), allocatable :: condition_strides(:)
    integer(int64), allocatable :: lhs_strides(:)
    integer(int64), allocatable :: rhs_strides(:)

    call validate_selection_source_bool(condition, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    call validate_selection_source_r64(lhs, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    call validate_selection_source_r64(rhs, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    call resolve_where_broadcast(condition, lhs, rhs, output_shape, &
      condition_strides, lhs_strides, rhs_strides, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    array = empty_r64(output_shape, FRUMPY_ORDER_C, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    call copy_where_values(condition, lhs, rhs, condition_strides, lhs_strides, &
      rhs_strides, array, local_status)
    call set_optional_status_value(status, local_status)
  end function where_r64

  function take_r64(source, indices, axis0, status) result(array)
    type(ndarray_r64), intent(in) :: source
    integer(int64), intent(in) :: indices(:)
    integer(int32), intent(in), optional :: axis0
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(frumpy_status) :: local_status
    integer(int32) :: resolved_axis0
    integer(int32) :: axis_dim1
    integer(int64) :: axis_extent
    integer(int64), allocatable :: output_shape(:)
    integer(int64), allocatable :: normalized_indices(:)
    integer :: alloc_stat

    resolved_axis0 = 0_int32
    if (present(axis0)) resolved_axis0 = axis0

    call validate_selection_source_r64(source, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    ! An omitted axis follows NumPy take: index the logical C-order flattening.
    axis_dim1 = 0_int32
    axis_extent = source%size()
    if (present(axis0)) then
      axis_dim1 = selection_axis0_to_dim1(resolved_axis0, max(1_int32, source%rank), &
        local_status)
      if (local_status%is_failure()) then
        call set_optional_status_value(status, local_status)
        return
      end if
      if (source%rank == 0_int32) then
        axis_dim1 = 0_int32
      else
        axis_extent = source%shape(axis_dim1)
      end if
    end if

    call normalize_take_indices(indices, axis_extent, normalized_indices, &
      local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    allocate(output_shape(merge(source%rank, 1_int32, axis_dim1 /= 0_int32)), &
      stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_optional_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "take_r64 output shape allocation failed")
      return
    end if

    if (axis_dim1 == 0_int32) then
      output_shape = int(size(indices), int64)
    else
      output_shape = source%shape
      output_shape(axis_dim1) = int(size(indices), int64)
    end if

    array = empty_r64(output_shape, FRUMPY_ORDER_C, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    call copy_taken_values(source, axis_dim1, normalized_indices, array, &
      local_status)
    call set_optional_status_value(status, local_status)
  end function take_r64

  function concatenate_r64(arrays, axis0, status) result(array)
    type(ndarray_r64), intent(in) :: arrays(:)
    integer(int32), intent(in), optional :: axis0
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(frumpy_status) :: local_status
    integer(int32) :: resolved_axis0
    integer(int32) :: dim1
    integer(int32) :: source_rank
    integer(int32) :: item1
    integer(int64), allocatable :: output_shape(:)
    integer(int32) :: order

    resolved_axis0 = 0_int32
    if (present(axis0)) resolved_axis0 = axis0

    if (size(arrays) == 0) then
      call set_optional_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "concatenate_r64 requires at least one input array")
      return
    end if

    do item1 = 1_int32, int(size(arrays), int32)
      call validate_selection_source_r64(arrays(item1), local_status)
      if (local_status%is_failure()) then
        call set_optional_status_value(status, local_status)
        return
      end if
    end do

    source_rank = arrays(1)%rank
    if (source_rank < 1_int32) then
      call set_optional_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "concatenate_r64 requires arrays with rank at least 1")
      return
    end if

    dim1 = selection_axis0_to_dim1(resolved_axis0, source_rank, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    call concatenate_metadata(arrays, dim1, output_shape, order, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    array = empty_r64(output_shape, order, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    call copy_concatenated_values(arrays, dim1, array, local_status)
    call set_optional_status_value(status, local_status)
  end function concatenate_r64

  function stack_r64(arrays, axis0, status) result(array)
    type(ndarray_r64), intent(in) :: arrays(:)
    integer(int32), intent(in), optional :: axis0
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(frumpy_status) :: local_status
    integer(int32) :: resolved_axis0
    integer(int32) :: insert_dim1
    integer(int32) :: source_rank
    integer(int32) :: item1
    integer(int64), allocatable :: output_shape(:)

    resolved_axis0 = 0_int32
    if (present(axis0)) resolved_axis0 = axis0

    if (size(arrays) == 0) then
      call set_optional_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "stack_r64 requires at least one input array")
      return
    end if

    do item1 = 1_int32, int(size(arrays), int32)
      call validate_selection_source_r64(arrays(item1), local_status)
      if (local_status%is_failure()) then
        call set_optional_status_value(status, local_status)
        return
      end if
      if (.not. same_shape(arrays(1)%shape, arrays(item1)%shape)) then
        call set_optional_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
          "stack_r64 input shapes must match")
        return
      end if
    end do

    source_rank = arrays(1)%rank
    insert_dim1 = selection_axis0_to_dim1(resolved_axis0, source_rank + 1_int32, &
      local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    call stack_metadata(arrays, insert_dim1, output_shape, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    array = empty_r64(output_shape, FRUMPY_ORDER_C, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    call copy_stacked_values(arrays, insert_dim1, array, local_status)
    call set_optional_status_value(status, local_status)
  end function stack_r64

  subroutine validate_selection_source_r64(source, status)
    type(ndarray_r64), intent(in) :: source
    type(frumpy_status), intent(out) :: status

    if (.not. source%has_storage()) then
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "selection operation requires accessible r64 storage")
      return
    end if

    if (.not. allocated(source%shape) .or. .not. allocated(source%strides)) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "selection operation source descriptor has incomplete metadata")
      return
    end if

    if (source%rank /= int(size(source%shape), int32) .or. &
        source%rank /= int(size(source%strides), int32)) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "selection operation source rank does not match metadata")
      return
    end if

    if (.not. storage_bounds_are_valid(source%shape, source%strides, &
        source%offset, source%storage_size())) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "selection descriptor has invalid shape or storage bounds")
      return
    end if

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine validate_selection_source_r64

  subroutine validate_selection_source_bool(source, status)
    type(ndarray_bool), intent(in) :: source
    type(frumpy_status), intent(out) :: status

    if (.not. source%has_storage()) then
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "selection operation requires accessible bool storage")
      return
    end if

    if (.not. allocated(source%shape) .or. .not. allocated(source%strides)) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "selection operation condition descriptor has incomplete metadata")
      return
    end if

    if (source%rank /= int(size(source%shape), int32) .or. &
        source%rank /= int(size(source%strides), int32)) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "selection operation condition rank does not match metadata")
      return
    end if

    if (.not. storage_bounds_are_valid(source%shape, source%strides, &
        source%offset, source%storage_size())) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "selection descriptor has invalid shape or storage bounds")
      return
    end if

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine validate_selection_source_bool


  subroutine count_nonzero_values_bool(source, count, status)
    type(ndarray_bool), intent(in) :: source
    integer(int64), intent(out) :: count
    type(frumpy_status), intent(out) :: status
    integer(int64), allocatable :: index0(:)
    integer(int64) :: storage_index

    if (.not. allocate_index_vector(index0, source%rank, status)) return

    if (source%size() == 0_int64) then
      count = 0_int64
      call set_status(status, FRUMPY_STATUS_OK)
      return
    end if

    count = 0_int64
    index0 = 0_int64
    do
      storage_index = storage_position_bool(source%offset, index0, &
        source%strides)
      if (source%data(storage_index) /= 0_int8) then
        count = count + 1_int64
      end if

      call advance_c_order_index(index0, source%shape)
      if (all(index0 == 0_int64)) exit
    end do

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine count_nonzero_values_bool

  subroutine copy_nonzero_values_bool(source, output, status)
    type(ndarray_bool), intent(in) :: source
    type(ndarray_i64), intent(inout) :: output
    type(frumpy_status), intent(out) :: status
    integer(int64), allocatable :: index0(:)
    integer(int64) :: storage_index
    integer(int64) :: linear_index
    integer(int64) :: item1

    if (.not. allocate_index_vector(index0, source%rank, status)) return

    if (output%size() == 0_int64) then
      call set_status(status, FRUMPY_STATUS_OK)
      return
    end if

    index0 = 0_int64
    linear_index = 0_int64
    item1 = 1_int64
    do
      storage_index = storage_position_bool(source%offset, index0, &
        source%strides)
      if (source%data(storage_index) /= 0_int8) then
        if (item1 > int(size(output%data), int64)) then
          call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
            "nonzero_bool internal output overflow")
          return
        end if

        output%data(item1) = linear_index
        item1 = item1 + 1_int64
      end if

      linear_index = linear_index + 1_int64
      call advance_c_order_index(index0, source%shape)
      if (all(index0 == 0_int64)) exit
    end do

    if (item1 - 1_int64 /= int(size(output%data), int64)) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "nonzero_bool output count mismatch")
      return
    end if

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine copy_nonzero_values_bool

  subroutine resolve_where_broadcast(condition, lhs, rhs, output_shape, &
      condition_strides, lhs_strides, rhs_strides, status)
    type(ndarray_bool), intent(in) :: condition
    type(ndarray_r64), intent(in) :: lhs
    type(ndarray_r64), intent(in) :: rhs
    integer(int64), allocatable, intent(out) :: output_shape(:)
    integer(int64), allocatable, intent(out) :: condition_strides(:)
    integer(int64), allocatable, intent(out) :: lhs_strides(:)
    integer(int64), allocatable, intent(out) :: rhs_strides(:)
    type(frumpy_status), intent(out) :: status
    integer(int32) :: condition_dim1
    integer(int32) :: lhs_dim1
    integer(int32) :: output_dim1
    integer(int32) :: rhs_dim1
    integer(int32) :: output_rank
    integer(int64) :: condition_extent
    integer(int64) :: lhs_extent
    integer(int64) :: rhs_extent
    integer :: alloc_stat

    output_rank = max(condition%rank, max(lhs%rank, rhs%rank))

    allocate(output_shape(output_rank), condition_strides(output_rank), &
      lhs_strides(output_rank), rhs_strides(output_rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "where_r64 broadcast metadata allocation failed")
      return
    end if

    output_shape = 0_int64
    condition_strides = 0_int64
    lhs_strides = 0_int64
    rhs_strides = 0_int64

    do output_dim1 = 1_int32, output_rank
      condition_dim1 = aligned_dim1(condition%rank, output_rank, output_dim1)
      lhs_dim1 = aligned_dim1(lhs%rank, output_rank, output_dim1)
      rhs_dim1 = aligned_dim1(rhs%rank, output_rank, output_dim1)

      condition_extent = extent_or_one(condition%shape, condition_dim1)
      lhs_extent = extent_or_one(lhs%shape, lhs_dim1)
      rhs_extent = extent_or_one(rhs%shape, rhs_dim1)

      if (.not. broadcast_extents_match(condition_extent, lhs_extent) .or. &
          .not. broadcast_extents_match(condition_extent, rhs_extent) .or. &
          .not. broadcast_extents_match(lhs_extent, rhs_extent)) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
          "where_r64 input shapes are not broadcast-compatible")
        return
      end if

      ! A zero extent broadcast with one stays zero, rather than becoming one.
      output_shape(output_dim1) = 1_int64
      if (condition_extent /= 1_int64) output_shape(output_dim1) = condition_extent
      if (lhs_extent /= 1_int64) output_shape(output_dim1) = lhs_extent
      if (rhs_extent /= 1_int64) output_shape(output_dim1) = rhs_extent
      condition_strides(output_dim1) = broadcast_stride(condition%shape, &
        condition%strides, condition_dim1, output_shape(output_dim1))
      lhs_strides(output_dim1) = broadcast_stride(lhs%shape, lhs%strides, &
        lhs_dim1, output_shape(output_dim1))
      rhs_strides(output_dim1) = broadcast_stride(rhs%shape, rhs%strides, &
        rhs_dim1, output_shape(output_dim1))
    end do

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine resolve_where_broadcast

  subroutine copy_where_values(condition, lhs, rhs, condition_strides, &
      lhs_strides, rhs_strides, output, status)
    type(ndarray_bool), intent(in) :: condition
    type(ndarray_r64), intent(in) :: lhs
    type(ndarray_r64), intent(in) :: rhs
    integer(int64), intent(in) :: condition_strides(:)
    integer(int64), intent(in) :: lhs_strides(:)
    integer(int64), intent(in) :: rhs_strides(:)
    type(ndarray_r64), intent(inout) :: output
    type(frumpy_status), intent(out) :: status
    integer(int64), allocatable :: index0(:)
    integer(int64) :: condition_position
    integer(int64) :: lhs_position
    integer(int64) :: output_position
    integer(int64) :: rhs_position

    if (.not. allocate_index_vector(index0, output%rank, status)) return

    if (output%size() == 0_int64) then
      call set_status(status, FRUMPY_STATUS_OK)
      return
    end if

    index0 = 0_int64
    do
      condition_position = storage_position_broadcast(condition%offset, index0, &
        condition_strides)
      lhs_position = storage_position_broadcast(lhs%offset, index0, lhs_strides)
      rhs_position = storage_position_broadcast(rhs%offset, index0, rhs_strides)
      output_position = storage_position(output, index0)

      if (condition%data(condition_position) /= 0_int8) then
        output%data(output_position) = lhs%data(lhs_position)
      else
        output%data(output_position) = rhs%data(rhs_position)
      end if

      call advance_c_order_index(index0, output%shape)
      if (all(index0 == 0_int64)) exit
    end do

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine copy_where_values

  subroutine normalize_take_indices(indices, axis_extent, normalized_indices, &
      status)
    integer(int64), intent(in) :: indices(:)
    integer(int64), intent(in) :: axis_extent
    integer(int64), allocatable, intent(out) :: normalized_indices(:)
    type(frumpy_status), intent(out) :: status
    integer(int32) :: item1
    integer :: alloc_stat

    allocate(normalized_indices(size(indices)), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "take_r64 normalized index allocation failed")
      return
    end if

    if (size(indices) == 0) then
      call set_status(status, FRUMPY_STATUS_OK)
      return
    end if

    if (axis_extent == 0_int64) then
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "take_r64 cannot index into a zero-extent axis")
      return
    end if

    do item1 = 1_int32, int(size(indices), int32)
      if (indices(item1) < -axis_extent .or. indices(item1) >= axis_extent) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
          "take_r64 index is out of bounds for the selected axis")
        return
      end if

      if (indices(item1) < 0_int64) then
        normalized_indices(item1) = indices(item1) + axis_extent
      else
        normalized_indices(item1) = indices(item1)
      end if
    end do

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine normalize_take_indices

  subroutine copy_taken_values(source, axis_dim1, normalized_indices, output, &
      status)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in) :: axis_dim1
    integer(int64), intent(in) :: normalized_indices(:)
    type(ndarray_r64), intent(inout) :: output
    type(frumpy_status), intent(out) :: status
    integer(int64), allocatable :: output_index0(:)
    integer(int64), allocatable :: source_index0(:)
    integer(int64) :: output_position
    integer(int64) :: source_position
    integer(int64) :: item1, flat_index0
    integer(int32) :: dim1

    if (.not. allocate_index_vector(output_index0, output%rank, status)) return
    if (.not. allocate_index_vector(source_index0, source%rank, status)) return

    if (output%size() == 0_int64) then
      call set_status(status, FRUMPY_STATUS_OK)
      return
    end if

    output_index0 = 0_int64
    do
      item1 = output_index0(max(1_int32, axis_dim1)) + 1_int64
      if (item1 < 1_int32 .or. item1 > int(size(normalized_indices), int32)) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
          "take_r64 internal axis mapping failed")
        return
      end if

      if (axis_dim1 == 0_int32) then
        flat_index0 = normalized_indices(item1)
        do dim1 = source%rank, 1_int32, -1_int32
          source_index0(dim1) = modulo(flat_index0, source%shape(dim1))
          flat_index0 = flat_index0 / source%shape(dim1)
        end do
      else
        source_index0 = output_index0
        source_index0(axis_dim1) = normalized_indices(item1)
      end if

      output_position = storage_position(output, output_index0)
      source_position = storage_position(source, source_index0)
      output%data(output_position) = source%data(source_position)

      call advance_c_order_index(output_index0, output%shape)
      if (all(output_index0 == 0_int64)) exit
    end do

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine copy_taken_values

  subroutine concatenate_metadata(arrays, axis_dim1, output_shape, order, &
      status)
    type(ndarray_r64), intent(in) :: arrays(:)
    integer(int32), intent(in) :: axis_dim1
    integer(int64), allocatable, intent(out) :: output_shape(:)
    integer(int32), intent(out) :: order
    type(frumpy_status), intent(out) :: status
    integer(int32) :: item1
    integer(int32) :: dim1
    integer(int64) :: axis_extent
    logical :: all_fortran
    logical :: any_non_c
    integer :: alloc_stat

    allocate(output_shape(size(arrays(1)%shape)), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "concatenate_r64 metadata allocation failed")
      return
    end if

    output_shape = arrays(1)%shape
    axis_extent = 0_int64
    all_fortran = .true.
    any_non_c = .false.

    do item1 = 1_int32, int(size(arrays), int32)
      if (.not. arrays(item1)%has_storage()) then
        call set_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
          "concatenate_r64 requires accessible source storage")
        return
      end if

      if (arrays(item1)%rank /= arrays(1)%rank) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
          "concatenate_r64 input ranks must match")
        return
      end if

      do dim1 = 1_int32, arrays(1)%rank
        if (dim1 == axis_dim1) cycle
        if (arrays(item1)%shape(dim1) /= arrays(1)%shape(dim1)) then
          call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
            "concatenate_r64 input shapes must match except along axis0")
          return
        end if
      end do

      if (arrays(item1)%shape(axis_dim1) > huge(axis_extent) - axis_extent) then
        call set_status(status, FRUMPY_STATUS_OVERFLOW, &
          "concatenate_r64 axis extent overflows int64")
        return
      end if

      axis_extent = axis_extent + arrays(item1)%shape(axis_dim1)
      all_fortran = all_fortran .and. arrays(item1)%is_f_contiguous
      any_non_c = any_non_c .or. (.not. arrays(item1)%is_c_contiguous)
    end do

    output_shape(axis_dim1) = axis_extent

    if (all_fortran .and. any_non_c) then
      order = FRUMPY_ORDER_F
    else
      order = FRUMPY_ORDER_C
    end if

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine concatenate_metadata

  subroutine stack_metadata(arrays, insert_dim1, output_shape, status)
    type(ndarray_r64), intent(in) :: arrays(:)
    integer(int32), intent(in) :: insert_dim1
    integer(int64), allocatable, intent(out) :: output_shape(:)
    type(frumpy_status), intent(out) :: status
    integer(int32) :: item1
    integer(int32) :: output_rank
    integer :: alloc_stat

    output_rank = arrays(1)%rank + 1_int32
    allocate(output_shape(output_rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "stack_r64 metadata allocation failed")
      return
    end if

    output_shape = 0_int64
    output_shape(insert_dim1) = int(size(arrays), int64)

    do item1 = 1_int32, arrays(1)%rank
      if (item1 < insert_dim1) then
        output_shape(item1) = arrays(1)%shape(item1)
      else
        output_shape(item1 + 1_int32) = arrays(1)%shape(item1)
      end if
    end do

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine stack_metadata

  subroutine copy_concatenated_values(arrays, axis_dim1, output, status)
    type(ndarray_r64), intent(in) :: arrays(:)
    integer(int32), intent(in) :: axis_dim1
    type(ndarray_r64), intent(inout) :: output
    type(frumpy_status), intent(out) :: status
    integer(int64), allocatable :: output_index0(:)
    integer(int64), allocatable :: source_index0(:)
    integer(int64) :: axis0_value
    integer(int64) :: axis_offset
    integer(int64) :: output_position
    integer(int64) :: source_position
    integer(int32) :: item1

    if (.not. allocate_index_vector(output_index0, output%rank, status)) return
    if (.not. allocate_index_vector(source_index0, output%rank, status)) return

    if (output%size() == 0_int64) then
      call set_status(status, FRUMPY_STATUS_OK)
      return
    end if

    output_index0 = 0_int64
    do
      axis0_value = output_index0(axis_dim1)
      axis_offset = 0_int64
      do item1 = 1_int32, int(size(arrays), int32)
        if (axis0_value < axis_offset + arrays(item1)%shape(axis_dim1)) exit
        axis_offset = axis_offset + arrays(item1)%shape(axis_dim1)
      end do

      if (item1 > int(size(arrays), int32)) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
          "concatenate_r64 internal axis mapping failed")
        return
      end if

      source_index0 = output_index0
      source_index0(axis_dim1) = axis0_value - axis_offset
      output_position = storage_position(output, output_index0)
      source_position = storage_position(arrays(item1), source_index0)
      output%data(output_position) = arrays(item1)%data(source_position)

      call advance_c_order_index(output_index0, output%shape)
      if (all(output_index0 == 0_int64)) exit
    end do

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine copy_concatenated_values

  subroutine copy_stacked_values(arrays, insert_dim1, output, status)
    type(ndarray_r64), intent(in) :: arrays(:)
    integer(int32), intent(in) :: insert_dim1
    type(ndarray_r64), intent(inout) :: output
    type(frumpy_status), intent(out) :: status
    integer(int64), allocatable :: output_index0(:)
    integer(int64), allocatable :: source_index0(:)
    integer(int64) :: output_position
    integer(int64) :: source_position
    integer(int32) :: item1
    integer(int32) :: source_dim1
    integer(int32) :: output_dim1

    if (.not. allocate_index_vector(output_index0, output%rank, status)) return
    if (.not. allocate_index_vector(source_index0, arrays(1)%rank, status)) return

    if (output%size() == 0_int64) then
      call set_status(status, FRUMPY_STATUS_OK)
      return
    end if

    output_index0 = 0_int64
    do
      item1 = int(output_index0(insert_dim1), int32) + 1_int32
      if (item1 < 1_int32 .or. item1 > int(size(arrays), int32)) then
        call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
          "stack_r64 internal axis mapping failed")
        return
      end if

      source_dim1 = 1_int32
      do output_dim1 = 1_int32, output%rank
        if (output_dim1 == insert_dim1) cycle
        source_index0(source_dim1) = output_index0(output_dim1)
        source_dim1 = source_dim1 + 1_int32
      end do

      output_position = storage_position(output, output_index0)
      source_position = storage_position(arrays(item1), source_index0)
      output%data(output_position) = arrays(item1)%data(source_position)

      call advance_c_order_index(output_index0, output%shape)
      if (all(output_index0 == 0_int64)) exit
    end do

    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine copy_stacked_values

  integer(int32) function selection_axis0_to_dim1(axis0, rank, status) result(dim1)
    integer(int32), intent(in) :: axis0
    integer(int32), intent(in) :: rank
    type(frumpy_status), intent(out) :: status

    if (axis0 < -rank .or. axis0 >= rank) then
      dim1 = -1_int32
      call set_status(status, FRUMPY_STATUS_INVALID_AXIS, &
        "axis0 is out of bounds for selection array rank")
      return
    end if

    dim1 = axis0 + 1_int32
    if (axis0 < 0_int32) dim1 = dim1 + rank
    call set_status(status, FRUMPY_STATUS_OK)
  end function selection_axis0_to_dim1

  logical function same_shape(lhs, rhs)
    integer(int64), intent(in) :: lhs(:)
    integer(int64), intent(in) :: rhs(:)

    same_shape = size(lhs) == size(rhs)
    if (.not. same_shape) return
    same_shape = all(lhs == rhs)
  end function same_shape

  integer(int64) function storage_position(array, index0) result(position)
    type(ndarray_r64), intent(in) :: array
    integer(int64), intent(in) :: index0(:)
    integer(int32) :: dim1

    position = array%offset
    do dim1 = 1_int32, int(size(index0), int32)
      position = position + index0(dim1) * array%strides(dim1)
    end do
  end function storage_position

  integer(int64) function storage_position_bool(offset, index0, strides) &
      result(position)
    integer(int64), intent(in) :: offset
    integer(int64), intent(in) :: index0(:)
    integer(int64), intent(in) :: strides(:)
    integer(int32) :: dim1

    position = offset
    do dim1 = 1_int32, int(size(index0), int32)
      position = position + index0(dim1) * strides(dim1)
    end do
  end function storage_position_bool

  integer(int64) function storage_position_broadcast(offset, index0, strides) &
      result(position)
    integer(int64), intent(in) :: offset
    integer(int64), intent(in) :: index0(:)
    integer(int64), intent(in) :: strides(:)
    integer(int32) :: dim1

    position = offset
    do dim1 = 1_int32, int(size(index0), int32)
      position = position + index0(dim1) * strides(dim1)
    end do
  end function storage_position_broadcast

  integer(int32) function aligned_dim1(source_rank, output_rank, output_dim1) &
      result(dim1)
    integer(int32), intent(in) :: source_rank
    integer(int32), intent(in) :: output_rank
    integer(int32), intent(in) :: output_dim1

    dim1 = source_rank - (output_rank - output_dim1)
    if (dim1 < 1_int32) dim1 = -1_int32
  end function aligned_dim1

  integer(int64) function extent_or_one(shape, dim1) result(extent)
    integer(int64), intent(in) :: shape(:)
    integer(int32), intent(in) :: dim1

    if (dim1 < 1_int32) then
      extent = 1_int64
    else
      extent = shape(dim1)
    end if
  end function extent_or_one

  logical function broadcast_extents_match(lhs_extent, rhs_extent)
    integer(int64), intent(in) :: lhs_extent
    integer(int64), intent(in) :: rhs_extent

    broadcast_extents_match = lhs_extent == rhs_extent .or. &
      lhs_extent == 1_int64 .or. rhs_extent == 1_int64
  end function broadcast_extents_match

  integer(int64) function broadcast_stride(shape, strides, dim1, output_extent) &
      result(stride)
    integer(int64), intent(in) :: shape(:)
    integer(int64), intent(in) :: strides(:)
    integer(int32), intent(in) :: dim1
    integer(int64), intent(in) :: output_extent

    if (dim1 < 1_int32) then
      stride = 0_int64
    else if (shape(dim1) == 1_int64 .and. output_extent /= 1_int64) then
      stride = 0_int64
    else
      stride = strides(dim1)
    end if
  end function broadcast_stride

  subroutine advance_c_order_index(index0, shape)
    integer(int64), intent(inout) :: index0(:)
    integer(int64), intent(in) :: shape(:)
    integer(int32) :: dim1

    if (size(index0) == 0) return

    do dim1 = size(index0), 1, -1
      index0(dim1) = index0(dim1) + 1_int64
      if (index0(dim1) < shape(dim1)) return
      index0(dim1) = 0_int64
    end do
  end subroutine advance_c_order_index

  logical function allocate_index_vector(index0, rank, status)
    integer(int64), allocatable, intent(out) :: index0(:)
    integer(int32), intent(in) :: rank
    type(frumpy_status), intent(out) :: status
    integer :: alloc_stat

    allocate(index0(rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      allocate_index_vector = .false.
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "selection index vector allocation failed")
      return
    end if

    allocate_index_vector = .true.
    call set_status(status, FRUMPY_STATUS_OK)
  end function allocate_index_vector


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
end module frumpy_selection_r64
