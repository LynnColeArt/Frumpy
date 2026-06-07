!> Initial r64 reductions with explicit NumPy-facing axis0 semantics.
module fenum_reductions_r64
  use, intrinsic :: ieee_arithmetic, only: ieee_quiet_nan, ieee_value
  use iso_fortran_env, only: int32, int64, real64
  use fenum_constants, only: FENUM_ORDER_C
  use fenum_constructors_r64, only: empty_r64
  use fenum_ndarray_r64, only: ndarray_r64
  use fenum_shape, only: element_count
  use fenum_statuses, only: FENUM_STATUS_ALLOCATION_FAILED, &
    FENUM_STATUS_INVALID_AXIS, FENUM_STATUS_INVALID_SHAPE, FENUM_STATUS_OK, &
    FENUM_STATUS_UNSUPPORTED_BEHAVIOR, fenum_status, set_status

  implicit none

  private

  public :: axis0_to_dim1
  public :: sum_r64
  public :: prod_r64
  public :: min_r64
  public :: max_r64
  public :: mean_r64

  integer(int32), parameter :: REDUCE_SUM = 1_int32
  integer(int32), parameter :: REDUCE_PROD = 2_int32
  integer(int32), parameter :: REDUCE_MIN = 3_int32
  integer(int32), parameter :: REDUCE_MAX = 4_int32
  integer(int32), parameter :: REDUCE_MEAN = 5_int32

contains

  ! Empty-reduction policy follows NumPy for this subset: sum/prod use their
  ! identities, mean returns NaN, and min/max fail when a non-empty result would
  ! require reducing an empty slice.

  function axis0_to_dim1(axis0, rank, status) result(dim1)
    integer(int32), intent(in) :: axis0
    integer(int32), intent(in) :: rank
    type(fenum_status), intent(out), optional :: status
    integer(int32) :: dim1

    if (axis0 < 0_int32 .or. axis0 >= rank) then
      dim1 = -1_int32
      call set_optional_status(status, FENUM_STATUS_INVALID_AXIS, &
        "axis0 is out of bounds for ndarray rank")
      return
    end if

    dim1 = axis0 + 1_int32
    call set_optional_status(status, FENUM_STATUS_OK)
  end function axis0_to_dim1

  function sum_r64(source, axis0, keepdims, status) result(array)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = reduce_r64(source, REDUCE_SUM, axis0, keepdims, status)
  end function sum_r64

  function prod_r64(source, axis0, keepdims, status) result(array)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = reduce_r64(source, REDUCE_PROD, axis0, keepdims, status)
  end function prod_r64

  function min_r64(source, axis0, keepdims, status) result(array)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = reduce_r64(source, REDUCE_MIN, axis0, keepdims, status)
  end function min_r64

  function max_r64(source, axis0, keepdims, status) result(array)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = reduce_r64(source, REDUCE_MAX, axis0, keepdims, status)
  end function max_r64

  function mean_r64(source, axis0, keepdims, status) result(array)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    array = reduce_r64(source, REDUCE_MEAN, axis0, keepdims, status)
  end function mean_r64

  function reduce_r64(source, operation, axis0, keepdims, status) result(array)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in) :: operation
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(fenum_status) :: local_status
    integer(int64), allocatable :: output_shape(:)
    integer(int64), allocatable :: output_index0(:)
    integer(int64), allocatable :: source_index0(:)
    integer(int64) :: item1
    integer(int64) :: reduction_extent
    real(real64) :: reduced_value
    integer(int32) :: dim1
    logical :: preserve_reduced_dims
    logical :: reduce_all_axes

    call validate_source(source, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    preserve_reduced_dims = .false.
    if (present(keepdims)) preserve_reduced_dims = keepdims

    reduce_all_axes = .not. present(axis0)
    dim1 = -1_int32
    if (present(axis0)) then
      dim1 = axis0_to_dim1(axis0, source%rank, local_status)
      if (local_status%is_failure()) then
        call set_optional_status_value(status, local_status)
        return
      end if
    end if

    call reduction_output_shape(source%shape, dim1, reduce_all_axes, &
      preserve_reduced_dims, output_shape, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    array = empty_r64(output_shape, FENUM_ORDER_C, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    if (array%size() == 0_int64) then
      call set_optional_status(status, FENUM_STATUS_OK)
      return
    end if

    reduction_extent = resolved_reduction_extent(source, dim1, reduce_all_axes)
    if (reduction_extent == 0_int64 .and. &
        operation_has_no_empty_identity(operation)) then
      call set_optional_status(status, FENUM_STATUS_UNSUPPORTED_BEHAVIOR, &
        "min_r64 and max_r64 have no identity for empty reductions")
      return
    end if

    if (reduce_all_axes) then
      call reduce_all_values(source, operation, reduced_value, local_status)
      if (local_status%is_failure()) then
        call set_optional_status_value(status, local_status)
        return
      end if
      array%data = reduced_value
      call set_optional_status(status, FENUM_STATUS_OK)
      return
    end if

    if (.not. allocate_index_vector(source_index0, source%rank, local_status)) then
      call set_optional_status_value(status, local_status)
      return
    end if

    if (.not. allocate_index_vector(output_index0, array%rank, &
        local_status)) then
      call set_optional_status_value(status, local_status)
      return
    end if
    if (array%rank > 0_int32) then
      output_index0 = 0_int64
    end if

    do item1 = 1_int64, array%size()
      call source_index_from_output(output_index0, source_index0, dim1, &
        preserve_reduced_dims)
      call reduce_axis_values(source, dim1, source_index0, operation, &
        reduced_value, local_status)
      if (local_status%is_failure()) then
        call set_optional_status_value(status, local_status)
        return
      end if

      array%data(item1) = reduced_value
      if (array%rank > 0_int32) then
        call advance_c_order_index(output_index0, array%shape)
      end if
    end do

    call set_optional_status(status, FENUM_STATUS_OK)
  end function reduce_r64

  subroutine validate_source(source, status)
    type(ndarray_r64), intent(in) :: source
    type(fenum_status), intent(out) :: status

    if (.not. source%has_storage()) then
      call set_status(status, FENUM_STATUS_UNSUPPORTED_BEHAVIOR, &
        "r64 reductions require accessible source storage")
      return
    end if

    if (.not. allocated(source%shape) .or. .not. allocated(source%strides)) then
      call set_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "r64 reduction source descriptor has incomplete metadata")
      return
    end if

    if (source%rank /= int(size(source%shape), int32) .or. &
        source%rank /= int(size(source%strides), int32)) then
      call set_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "r64 reduction source rank does not match metadata")
      return
    end if

    call set_status(status, FENUM_STATUS_OK)
  end subroutine validate_source

  subroutine reduction_output_shape(source_shape, dim1, reduce_all_axes, &
      keepdims, output_shape, status)
    integer(int64), intent(in) :: source_shape(:)
    integer(int32), intent(in) :: dim1
    logical, intent(in) :: reduce_all_axes
    logical, intent(in) :: keepdims
    integer(int64), allocatable, intent(out) :: output_shape(:)
    type(fenum_status), intent(out) :: status
    integer(int32) :: source_dim1
    integer(int32) :: output_dim1
    integer(int32) :: output_rank
    integer :: alloc_stat

    if (reduce_all_axes) then
      if (keepdims .and. size(source_shape) > 0) then
        allocate(output_shape(size(source_shape)), stat=alloc_stat)
        if (alloc_stat /= 0) then
          call set_status(status, FENUM_STATUS_ALLOCATION_FAILED, &
            "reduction keepdims shape allocation failed")
          return
        end if
        output_shape = 1_int64
      else
        allocate(output_shape(0), stat=alloc_stat)
        if (alloc_stat /= 0) then
          call set_status(status, FENUM_STATUS_ALLOCATION_FAILED, &
            "reduction scalar shape allocation failed")
          return
        end if
      end if

      call set_status(status, FENUM_STATUS_OK)
      return
    end if

    if (keepdims) then
      allocate(output_shape(size(source_shape)), stat=alloc_stat)
      if (alloc_stat /= 0) then
        call set_status(status, FENUM_STATUS_ALLOCATION_FAILED, &
          "reduction axis keepdims shape allocation failed")
        return
      end if

      output_shape = source_shape
      output_shape(dim1) = 1_int64
      call set_status(status, FENUM_STATUS_OK)
      return
    end if

    output_rank = int(size(source_shape), int32) - 1_int32
    allocate(output_shape(output_rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(status, FENUM_STATUS_ALLOCATION_FAILED, &
        "reduction axis output shape allocation failed")
      return
    end if

    output_dim1 = 1_int32
    do source_dim1 = 1_int32, int(size(source_shape), int32)
      if (source_dim1 == dim1) cycle
      output_shape(output_dim1) = source_shape(source_dim1)
      output_dim1 = output_dim1 + 1_int32
    end do

    call set_status(status, FENUM_STATUS_OK)
  end subroutine reduction_output_shape

  integer(int64) function resolved_reduction_extent(source, dim1, &
      reduce_all_axes) result(reduction_extent)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in) :: dim1
    logical, intent(in) :: reduce_all_axes

    if (reduce_all_axes) then
      reduction_extent = source%size()
    else
      reduction_extent = source%shape(dim1)
    end if
  end function resolved_reduction_extent

  logical function operation_has_no_empty_identity(operation)
    integer(int32), intent(in) :: operation

    operation_has_no_empty_identity = operation == REDUCE_MIN .or. &
      operation == REDUCE_MAX
  end function operation_has_no_empty_identity

  subroutine reduce_all_values(source, operation, reduced_value, status)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in) :: operation
    real(real64), intent(out) :: reduced_value
    type(fenum_status), intent(out) :: status
    integer(int64), allocatable :: index0(:)
    integer(int64) :: item1
    integer(int64) :: source_position
    real(real64) :: running_value

    if (source%size() == 0_int64) then
      reduced_value = empty_reduction_value(operation)
      call set_status(status, FENUM_STATUS_OK)
      return
    end if

    if (source%rank == 0_int32) then
      if (.not. valid_position(source, source%offset)) then
        call set_status(status, FENUM_STATUS_INVALID_SHAPE, &
          "scalar reduction source offset is out of bounds")
        return
      end if

      reduced_value = source%data(source%offset)
      call set_status(status, FENUM_STATUS_OK)
      return
    end if

    if (.not. allocate_index_vector(index0, source%rank, status)) return
    index0 = 0_int64
    running_value = initial_reduction_value(operation)

    do item1 = 1_int64, source%size()
      source_position = storage_position(source, index0)
      if (.not. valid_position(source, source_position)) then
        call set_status(status, FENUM_STATUS_INVALID_SHAPE, &
          "all-axis reduction source position is out of bounds")
        return
      end if

      call update_reduction_value(operation, running_value, &
        source%data(source_position), item1)
      call advance_c_order_index(index0, source%shape)
    end do

    reduced_value = finalize_reduction_value(operation, running_value, &
      source%size())
    call set_status(status, FENUM_STATUS_OK)
  end subroutine reduce_all_values

  subroutine reduce_axis_values(source, dim1, source_index0, operation, &
      reduced_value, status)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in) :: dim1
    integer(int64), intent(inout) :: source_index0(:)
    integer(int32), intent(in) :: operation
    real(real64), intent(out) :: reduced_value
    type(fenum_status), intent(out) :: status
    integer(int64) :: reduction_index0
    integer(int64) :: source_position
    integer(int64) :: reduction_extent
    real(real64) :: running_value

    reduction_extent = source%shape(dim1)
    if (reduction_extent == 0_int64) then
      reduced_value = empty_reduction_value(operation)
      call set_status(status, FENUM_STATUS_OK)
      return
    end if

    running_value = initial_reduction_value(operation)
    do reduction_index0 = 0_int64, reduction_extent - 1_int64
      source_index0(dim1) = reduction_index0
      source_position = storage_position(source, source_index0)
      if (.not. valid_position(source, source_position)) then
        call set_status(status, FENUM_STATUS_INVALID_SHAPE, &
          "axis reduction source position is out of bounds")
        return
      end if

      call update_reduction_value(operation, running_value, &
        source%data(source_position), reduction_index0 + 1_int64)
    end do

    reduced_value = finalize_reduction_value(operation, running_value, &
      reduction_extent)
    call set_status(status, FENUM_STATUS_OK)
  end subroutine reduce_axis_values

  subroutine source_index_from_output(output_index0, source_index0, dim1, &
      keepdims)
    integer(int64), intent(in) :: output_index0(:)
    integer(int64), intent(out) :: source_index0(:)
    integer(int32), intent(in) :: dim1
    logical, intent(in) :: keepdims
    integer(int32) :: source_dim1
    integer(int32) :: output_dim1

    source_index0 = 0_int64
    if (size(output_index0) == 0) return

    if (keepdims) then
      source_index0 = output_index0
      source_index0(dim1) = 0_int64
      return
    end if

    output_dim1 = 1_int32
    do source_dim1 = 1_int32, int(size(source_index0), int32)
      if (source_dim1 == dim1) cycle
      source_index0(source_dim1) = output_index0(output_dim1)
      output_dim1 = output_dim1 + 1_int32
    end do
  end subroutine source_index_from_output

  real(real64) function initial_reduction_value(operation) result(value)
    integer(int32), intent(in) :: operation

    select case (operation)
    case (REDUCE_SUM, REDUCE_MEAN)
      value = 0.0_real64
    case (REDUCE_PROD)
      value = 1.0_real64
    case default
      value = 0.0_real64
    end select
  end function initial_reduction_value

  real(real64) function empty_reduction_value(operation) result(value)
    integer(int32), intent(in) :: operation

    select case (operation)
    case (REDUCE_SUM)
      value = 0.0_real64
    case (REDUCE_PROD)
      value = 1.0_real64
    case (REDUCE_MEAN)
      value = ieee_value(0.0_real64, ieee_quiet_nan)
    case default
      value = 0.0_real64
    end select
  end function empty_reduction_value

  subroutine update_reduction_value(operation, running_value, source_value, &
      item1)
    integer(int32), intent(in) :: operation
    real(real64), intent(inout) :: running_value
    real(real64), intent(in) :: source_value
    integer(int64), intent(in) :: item1

    select case (operation)
    case (REDUCE_SUM, REDUCE_MEAN)
      running_value = running_value + source_value
    case (REDUCE_PROD)
      running_value = running_value * source_value
    case (REDUCE_MIN)
      if (item1 == 1_int64 .or. source_value < running_value) then
        running_value = source_value
      end if
    case (REDUCE_MAX)
      if (item1 == 1_int64 .or. source_value > running_value) then
        running_value = source_value
      end if
    end select
  end subroutine update_reduction_value

  real(real64) function finalize_reduction_value(operation, running_value, &
      reduction_extent) result(value)
    integer(int32), intent(in) :: operation
    real(real64), intent(in) :: running_value
    integer(int64), intent(in) :: reduction_extent

    if (operation == REDUCE_MEAN) then
      if (reduction_extent == 0_int64) then
        value = ieee_value(0.0_real64, ieee_quiet_nan)
      else
        value = running_value / real(reduction_extent, real64)
      end if
    else
      value = running_value
    end if
  end function finalize_reduction_value

  integer(int64) function storage_position(source, index0) result(position)
    type(ndarray_r64), intent(in) :: source
    integer(int64), intent(in) :: index0(:)
    integer(int32) :: dim1

    position = source%offset
    do dim1 = 1_int32, int(size(index0), int32)
      position = position + index0(dim1) * source%strides(dim1)
    end do
  end function storage_position

  logical function valid_position(source, position)
    type(ndarray_r64), intent(in) :: source
    integer(int64), intent(in) :: position

    valid_position = position >= 1_int64 .and. &
      position <= source%storage_size()
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
        "reduction index vector allocation failed")
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
end module fenum_reductions_r64
