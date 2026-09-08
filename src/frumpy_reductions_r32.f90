!> Float32 reductions over all axes or one NumPy-facing axis, with signed strides.
module frumpy_reductions_r32
  use iso_fortran_env, only: int32, int64, real32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_nan, ieee_quiet_nan, ieee_value
  use frumpy_ndarray_r32, only: ndarray_r32, owned_descriptor_r32
  use frumpy_strides, only: storage_bounds_are_valid
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_INVALID_AXIS, FRUMPY_STATUS_INVALID_SHAPE, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, FRUMPY_STATUS_ALLOCATION_FAILED
  implicit none
  private
  public :: sum_r32, prod_r32, mean_r32, min_r32, max_r32

  integer(int64), parameter :: SUM_LEAF_SIZE = 8_int64
  integer(int32), parameter :: REDUCE_SUM = 1_int32, REDUCE_PROD = 2_int32
  integer(int32), parameter :: REDUCE_MEAN = 3_int32, REDUCE_MIN = 4_int32, REDUCE_MAX = 5_int32

contains

  function sum_r32(source, axis0, keepdims, status) result(array)
    type(ndarray_r32), intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: array

    array = reduce_r32(source, REDUCE_SUM, axis0, keepdims, status)
  end function sum_r32

  function prod_r32(source, axis0, keepdims, status) result(array)
    type(ndarray_r32), intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: array

    array = reduce_r32(source, REDUCE_PROD, axis0, keepdims, status)
  end function prod_r32

  function mean_r32(source, axis0, keepdims, status) result(array)
    type(ndarray_r32), intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: array

    array = reduce_r32(source, REDUCE_MEAN, axis0, keepdims, status)
  end function mean_r32

  function min_r32(source, axis0, keepdims, status) result(array)
    type(ndarray_r32), intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: array

    array = reduce_r32(source, REDUCE_MIN, axis0, keepdims, status)
  end function min_r32

  function max_r32(source, axis0, keepdims, status) result(array)
    type(ndarray_r32), intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: array

    array = reduce_r32(source, REDUCE_MAX, axis0, keepdims, status)
  end function max_r32

  function reduce_r32(source, operation, axis0, keepdims, status) result(array)
    type(ndarray_r32), intent(in) :: source
    integer(int32), intent(in) :: operation
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: array
    type(frumpy_status) :: local_status
    integer(int64), allocatable :: output_shape(:), index0(:)
    integer(int64) :: item1, source_position, output_position, reduction_extent
    integer(int32) :: dim1, source_dim1, output_dim1, output_rank, alloc_stat
    logical :: preserve_dims, first_value

    call validate_source(source, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    dim1 = 0_int32
    if (present(axis0)) then
      call resolve_axis(axis0, source%rank, operation, dim1, local_status)
      if (local_status%is_failure()) then
        if (present(status)) status = local_status
        return
      end if
    end if
    preserve_dims = .false.
    if (present(keepdims)) preserve_dims = keepdims
    if (dim1 == 0_int32) then
      reduction_extent = source%size()
      output_rank = 0_int32
      if (preserve_dims) output_rank = source%rank
    else
      reduction_extent = source%shape(dim1)
      output_rank = source%rank - 1_int32
      if (preserve_dims) output_rank = source%rank
    end if
    ! NumPy rejects an empty min/max axis even when the output itself is empty.
    if (reduction_extent == 0_int64 .and. &
        (operation == REDUCE_MIN .or. operation == REDUCE_MAX)) then
      if (present(status)) call set_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "float32 min/max have no identity for an empty reduction axis")
      return
    end if
    allocate(output_shape(output_rank), index0(source%rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      if (present(status)) call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "float32 reduction metadata allocation failed")
      return
    end if
    output_shape = 1_int64
    if (dim1 /= 0_int32) then
      output_dim1 = 0_int32
      do source_dim1 = 1_int32, source%rank
        if (source_dim1 == dim1 .and. .not. preserve_dims) cycle
        output_dim1 = output_dim1 + 1_int32
        if (source_dim1 /= dim1) output_shape(output_dim1) = source%shape(source_dim1)
      end do
    end if
    array = owned_descriptor_r32(output_shape, status=local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    array%data = 0.0_real32
    if (operation == REDUCE_PROD) array%data = 1.0_real32
    index0 = 0_int64
    if (operation == REDUCE_SUM .or. operation == REDUCE_MEAN) then
      call sum_outputs(source, dim1, reduction_extent, array)
    else
      do item1 = 1_int64, source%size()
        source_position = source%offset
        output_position = 1_int64
        output_dim1 = 0_int32
        do source_dim1 = 1_int32, source%rank
          source_position = source_position + index0(source_dim1) * source%strides(source_dim1)
          if (dim1 == 0_int32) cycle
          if (source_dim1 == dim1 .and. .not. preserve_dims) cycle
          output_dim1 = output_dim1 + 1_int32
          if (source_dim1 /= dim1) then
            output_position = output_position + index0(source_dim1) * array%strides(output_dim1)
          end if
        end do
        first_value = item1 == 1_int64
        if (dim1 /= 0_int32) first_value = index0(dim1) == 0_int64
        call accumulate(operation, array%data(output_position), &
          source%data(source_position), first_value)
        do source_dim1 = source%rank, 1_int32, -1_int32
          index0(source_dim1) = index0(source_dim1) + 1_int64
          if (index0(source_dim1) < source%shape(source_dim1)) exit
          index0(source_dim1) = 0_int64
        end do
      end do
    end if
    if (operation == REDUCE_MEAN) then
      if (reduction_extent == 0_int64) then
        array%data = ieee_value(0.0_real32, ieee_quiet_nan)
      else
        array%data = array%data / real(reduction_extent, real32)
      end if
    end if
    if (present(status)) call set_status(status, FRUMPY_STATUS_OK)
  end function reduce_r32

  subroutine sum_outputs(source, dim1, extent, array)
    type(ndarray_r32), intent(in) :: source
    integer(int32), intent(in) :: dim1
    integer(int64), intent(in) :: extent
    type(ndarray_r32), intent(inout) :: array
    integer(int64) :: item1, remaining, base_position
    integer(int32) :: source_dim1

    do item1 = 1_int64, array%size()
      base_position = source%offset
      remaining = item1 - 1_int64
      if (dim1 /= 0_int32) then
        do source_dim1 = source%rank, 1_int32, -1_int32
          if (source_dim1 == dim1) cycle
          base_position = base_position + modulo(remaining, source%shape(source_dim1)) &
            * source%strides(source_dim1)
          remaining = remaining / source%shape(source_dim1)
        end do
      end if
      array%data(item1) = pairwise_sum(source, dim1, base_position, 0_int64, extent)
    end do
  end subroutine sum_outputs

  ! Bound sequential rounding to short leaves; recursion uses no input buffer copies.
  recursive function pairwise_sum(source, dim1, base_position, first0, count) result(value)
    type(ndarray_r32), intent(in) :: source
    integer(int32), intent(in) :: dim1
    integer(int64), intent(in) :: base_position, first0, count
    real(real32) :: value
    integer(int64) :: item0, half, remaining, position
    integer(int32) :: source_dim1

    if (count > SUM_LEAF_SIZE) then
      half = count / 2_int64
      value = pairwise_sum(source, dim1, base_position, first0, half) &
        + pairwise_sum(source, dim1, base_position, first0 + half, count - half)
      return
    end if
    value = 0.0_real32
    do item0 = first0, first0 + count - 1_int64
      position = base_position
      if (dim1 /= 0_int32) then
        position = position + item0 * source%strides(dim1)
      else
        remaining = item0
        do source_dim1 = source%rank, 1_int32, -1_int32
          position = position + modulo(remaining, source%shape(source_dim1)) &
            * source%strides(source_dim1)
          remaining = remaining / source%shape(source_dim1)
        end do
      end if
      value = value + source%data(position)
    end do
  end function pairwise_sum

  subroutine resolve_axis(axis0, rank, operation, dim1, status)
    integer(int32), intent(in) :: axis0, rank, operation
    integer(int32), intent(out) :: dim1
    type(frumpy_status), intent(out) :: status

    dim1 = 0_int32
    call set_status(status, FRUMPY_STATUS_INVALID_AXIS, "float32 reduction axis is out of bounds")
    if (rank == 0_int32) then
      ! NumPy's ufunc reductions accept scalar axes 0/-1; mean rejects explicit axes.
      if (operation == REDUCE_MEAN) return
      if (axis0 /= 0_int32 .and. axis0 /= -1_int32) return
    else
      ! Range-check before normalizing so extreme integer axes cannot overflow.
      if (axis0 < -rank .or. axis0 >= rank) return
      dim1 = axis0 + 1_int32
      if (axis0 < 0_int32) dim1 = axis0 + rank + 1_int32
    end if
    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine resolve_axis

  subroutine accumulate(operation, running, value, first_value)
    integer(int32), intent(in) :: operation
    real(real32), intent(inout) :: running
    real(real32), intent(in) :: value
    logical, intent(in) :: first_value

    select case (operation)
    case (REDUCE_PROD)
      running = running * value
    case (REDUCE_MIN, REDUCE_MAX)
      if (first_value .or. ieee_is_nan(value)) then
        running = value
      else if (.not. ieee_is_nan(running)) then
        ! A NaN stays sticky; equal extrema select the later value, including zero.
        if (operation == REDUCE_MIN .and. value <= running) running = value
        if (operation == REDUCE_MAX .and. value >= running) running = value
      end if
    end select
  end subroutine accumulate

  subroutine validate_source(source, status)
    type(ndarray_r32), intent(in) :: source
    type(frumpy_status), intent(out) :: status

    if (.not. source%has_storage()) then
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "float32 reductions require source storage")
      return
    end if
    call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
      "float32 reduction metadata or reachable storage is invalid")
    if (.not. allocated(source%shape) .or. .not. allocated(source%strides)) return
    if (source%rank /= size(source%shape)) return
    if (.not. storage_bounds_are_valid(source%shape, source%strides, source%offset, &
        source%storage_size())) return
    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine validate_source
end module frumpy_reductions_r32
