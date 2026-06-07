!> Initial r64 view operations.
module fenum_views_r64
  use iso_fortran_env, only: int32, int64
  use fenum_constants, only: FENUM_ORDER_C
  use fenum_constructors_r64, only: empty_r64
  use fenum_ndarray_r64, only: ndarray_r64, view_descriptor_r64
  use fenum_shape, only: element_count
  use fenum_slices, only: slice_length, slice_spec
  use fenum_statuses, only: FENUM_STATUS_ALLOCATION_FAILED, &
    FENUM_STATUS_INVALID_AXIS, FENUM_STATUS_INVALID_SHAPE, FENUM_STATUS_OK, &
    FENUM_STATUS_UNSUPPORTED_BEHAVIOR, fenum_status, set_status
  use fenum_strides, only: c_order_strides

  implicit none

  private

  public :: reshape_r64
  public :: ravel_r64
  public :: flatten_r64
  public :: transpose_r64
  public :: swapaxes_r64
  public :: squeeze_r64
  public :: expand_dims_r64
  public :: slice_r64

contains

  function reshape_r64(source, new_shape, status) result(view)
    type(ndarray_r64), intent(in) :: source
    integer(int64), intent(in) :: new_shape(:)
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: view
    type(fenum_status) :: local_status
    integer(int64) :: new_count
    integer(int64), allocatable :: new_strides(:)

    call validate_view_source(source, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    new_count = element_count(new_shape, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    if (new_count /= source%size()) then
      call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "reshape_r64 new shape element count must match source size")
      return
    end if

    if (.not. source%is_c_contiguous) then
      call set_optional_status(status, FENUM_STATUS_UNSUPPORTED_BEHAVIOR, &
        "reshape_r64 currently returns views only for C-contiguous sources")
      return
    end if

    new_strides = c_order_strides(new_shape, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    view = view_descriptor_r64(source, new_shape, new_strides, &
      source%offset, local_status)
    call set_optional_status_value(status, local_status)
  end function reshape_r64

  function ravel_r64(source, status) result(array)
    type(ndarray_r64), intent(in) :: source
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(fenum_status) :: local_status

    call validate_view_source(source, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    if (source%is_c_contiguous) then
      array = reshape_r64(source, [source%size()], local_status)
    else
      array = flat_copy_r64(source, local_status)
    end if

    call set_optional_status_value(status, local_status)
  end function ravel_r64

  function flatten_r64(source, status) result(array)
    type(ndarray_r64), intent(in) :: source
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(fenum_status) :: local_status

    array = flat_copy_r64(source, local_status)
    call set_optional_status_value(status, local_status)
  end function flatten_r64

  function transpose_r64(source, status) result(view)
    type(ndarray_r64), intent(in) :: source
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: view
    type(fenum_status) :: local_status
    integer(int64), allocatable :: new_shape(:)
    integer(int64), allocatable :: new_strides(:)
    integer(int32) :: dim1
    integer :: alloc_stat

    call validate_view_source(source, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    allocate(new_shape(source%rank), new_strides(source%rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_optional_status(status, FENUM_STATUS_ALLOCATION_FAILED, &
        "transpose_r64 metadata allocation failed")
      return
    end if

    do dim1 = 1_int32, source%rank
      new_shape(dim1) = source%shape(source%rank - dim1 + 1_int32)
      new_strides(dim1) = source%strides(source%rank - dim1 + 1_int32)
    end do

    view = view_descriptor_r64(source, new_shape, new_strides, &
      source%offset, local_status)
    call set_optional_status_value(status, local_status)
  end function transpose_r64

  function swapaxes_r64(source, axis0_a, axis0_b, status) result(view)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in) :: axis0_a
    integer(int32), intent(in) :: axis0_b
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: view
    type(fenum_status) :: local_status
    integer(int64), allocatable :: new_shape(:)
    integer(int64), allocatable :: new_strides(:)
    integer(int64) :: saved_value
    integer(int32) :: dim1_a
    integer(int32) :: dim1_b
    integer :: alloc_stat

    call validate_view_source(source, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    dim1_a = axis0_to_dim1(axis0_a, source%rank, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    dim1_b = axis0_to_dim1(axis0_b, source%rank, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    allocate(new_shape(source%rank), new_strides(source%rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_optional_status(status, FENUM_STATUS_ALLOCATION_FAILED, &
        "swapaxes_r64 metadata allocation failed")
      return
    end if

    new_shape = source%shape
    new_strides = source%strides

    saved_value = new_shape(dim1_a)
    new_shape(dim1_a) = new_shape(dim1_b)
    new_shape(dim1_b) = saved_value

    saved_value = new_strides(dim1_a)
    new_strides(dim1_a) = new_strides(dim1_b)
    new_strides(dim1_b) = saved_value

    view = view_descriptor_r64(source, new_shape, new_strides, &
      source%offset, local_status)
    call set_optional_status_value(status, local_status)
  end function swapaxes_r64

  function squeeze_r64(source, axis0, status) result(view)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: view
    type(fenum_status) :: local_status
    integer(int64), allocatable :: new_shape(:)
    integer(int64), allocatable :: new_strides(:)
    integer(int32) :: dim1
    integer(int32) :: squeezed_dim1
    integer(int32) :: output_dim1
    integer(int32) :: output_rank
    integer :: alloc_stat

    call validate_view_source(source, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    squeezed_dim1 = -1_int32
    if (present(axis0)) then
      squeezed_dim1 = axis0_to_dim1(axis0, source%rank, local_status)
      if (local_status%is_failure()) then
        call set_optional_status_value(status, local_status)
        return
      end if
      if (source%shape(squeezed_dim1) /= 1_int64) then
        call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
          "squeeze_r64 axis0 must reference a singleton dimension")
        return
      end if
      output_rank = source%rank - 1_int32
    else
      output_rank = count(source%shape /= 1_int64)
    end if

    allocate(new_shape(output_rank), new_strides(output_rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_optional_status(status, FENUM_STATUS_ALLOCATION_FAILED, &
        "squeeze_r64 metadata allocation failed")
      return
    end if

    output_dim1 = 1_int32
    do dim1 = 1_int32, source%rank
      if (present(axis0)) then
        if (dim1 == squeezed_dim1) cycle
      else
        if (source%shape(dim1) == 1_int64) cycle
      end if

      new_shape(output_dim1) = source%shape(dim1)
      new_strides(output_dim1) = source%strides(dim1)
      output_dim1 = output_dim1 + 1_int32
    end do

    view = view_descriptor_r64(source, new_shape, new_strides, &
      source%offset, local_status)
    call set_optional_status_value(status, local_status)
  end function squeeze_r64

  function expand_dims_r64(source, axis0, status) result(view)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in) :: axis0
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: view
    type(fenum_status) :: local_status
    integer(int64), allocatable :: new_shape(:)
    integer(int64), allocatable :: new_strides(:)
    integer(int32) :: dim1
    integer(int32) :: insert_dim1
    integer(int32) :: source_dim1
    integer :: alloc_stat

    call validate_view_source(source, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    if (axis0 < 0_int32 .or. axis0 > source%rank) then
      call set_optional_status(status, FENUM_STATUS_INVALID_AXIS, &
        "expand_dims_r64 axis0 must be between 0 and rank")
      return
    end if

    insert_dim1 = axis0 + 1_int32
    allocate(new_shape(source%rank + 1_int32), &
      new_strides(source%rank + 1_int32), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_optional_status(status, FENUM_STATUS_ALLOCATION_FAILED, &
        "expand_dims_r64 metadata allocation failed")
      return
    end if

    source_dim1 = 1_int32
    do dim1 = 1_int32, source%rank + 1_int32
      if (dim1 == insert_dim1) then
        new_shape(dim1) = 1_int64
        new_strides(dim1) = 0_int64
      else
        new_shape(dim1) = source%shape(source_dim1)
        new_strides(dim1) = source%strides(source_dim1)
        source_dim1 = source_dim1 + 1_int32
      end if
    end do

    view = view_descriptor_r64(source, new_shape, new_strides, &
      source%offset, local_status)
    call set_optional_status_value(status, local_status)
  end function expand_dims_r64

  function slice_r64(source, specs, status) result(view)
    type(ndarray_r64), intent(in) :: source
    type(slice_spec), intent(in) :: specs(:)
    type(fenum_status), intent(out), optional :: status
    type(ndarray_r64) :: view
    type(fenum_status) :: local_status
    integer(int64), allocatable :: new_shape(:)
    integer(int64), allocatable :: new_strides(:)
    integer(int64) :: new_offset
    integer(int64) :: start0
    integer(int64) :: resolved_length
    integer(int32) :: dim1
    integer :: alloc_stat

    call validate_view_source(source, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    if (int(size(specs), int32) /= source%rank) then
      call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "slice_r64 requires one slice_spec per source dimension")
      return
    end if

    allocate(new_shape(source%rank), new_strides(source%rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_optional_status(status, FENUM_STATUS_ALLOCATION_FAILED, &
        "slice_r64 metadata allocation failed")
      return
    end if

    new_offset = source%offset
    do dim1 = 1_int32, source%rank
      resolved_length = slice_length(specs(dim1), source%shape(dim1), &
        local_status)
      if (local_status%is_failure()) then
        call set_optional_status_value(status, local_status)
        return
      end if

      if (specs(dim1)%uses_full_extent) then
        start0 = 0_int64
        new_strides(dim1) = source%strides(dim1)
      else
        start0 = specs(dim1)%start0
        new_strides(dim1) = source%strides(dim1) * specs(dim1)%step
      end if

      new_offset = new_offset + start0 * source%strides(dim1)
      new_shape(dim1) = resolved_length
    end do

    if (.not. view_bounds_are_valid(source, new_shape, new_strides, &
        new_offset)) then
      call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "slice_r64 view references storage out of bounds")
      return
    end if

    view = view_descriptor_r64(source, new_shape, new_strides, new_offset, &
      local_status)
    call set_optional_status_value(status, local_status)
  end function slice_r64

  function flat_copy_r64(source, status) result(array)
    type(ndarray_r64), intent(in) :: source
    type(fenum_status), intent(out) :: status
    type(ndarray_r64) :: array
    integer(int64), allocatable :: index0(:)
    integer(int64) :: item1
    integer(int64) :: source_position

    call validate_view_source(source, status)
    if (status%is_failure()) return

    array = empty_r64([source%size()], FENUM_ORDER_C, status)
    if (status%is_failure()) return

    if (source%size() == 0_int64) then
      call set_status(status, FENUM_STATUS_OK)
      return
    end if

    if (source%rank == 0_int32) then
      if (.not. valid_position(source, source%offset)) then
        call set_status(status, FENUM_STATUS_INVALID_SHAPE, &
          "flat copy scalar source offset is out of bounds")
        return
      end if
      array%data(1) = source%data(source%offset)
      call set_status(status, FENUM_STATUS_OK)
      return
    end if

    if (.not. allocate_index_vector(index0, source%rank, status)) return
    index0 = 0_int64

    do item1 = 1_int64, source%size()
      source_position = storage_position(source, index0)
      if (.not. valid_position(source, source_position)) then
        call set_status(status, FENUM_STATUS_INVALID_SHAPE, &
          "flat copy source position is out of bounds")
        return
      end if

      array%data(item1) = source%data(source_position)
      call advance_c_order_index(index0, source%shape)
    end do

    call set_status(status, FENUM_STATUS_OK)
  end function flat_copy_r64

  subroutine validate_view_source(source, status)
    type(ndarray_r64), intent(in) :: source
    type(fenum_status), intent(out) :: status

    if (.not. source%has_storage()) then
      call set_status(status, FENUM_STATUS_UNSUPPORTED_BEHAVIOR, &
        "view operation requires accessible source storage")
      return
    end if

    if (.not. allocated(source%shape) .or. .not. allocated(source%strides)) then
      call set_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "view operation source descriptor has incomplete metadata")
      return
    end if

    if (source%rank /= int(size(source%shape), int32) .or. &
        source%rank /= int(size(source%strides), int32)) then
      call set_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "view operation source rank does not match metadata")
      return
    end if

    call set_status(status, FENUM_STATUS_OK)
  end subroutine validate_view_source

  integer(int32) function axis0_to_dim1(axis0, rank, status) result(dim1)
    integer(int32), intent(in) :: axis0
    integer(int32), intent(in) :: rank
    type(fenum_status), intent(out) :: status

    if (axis0 < 0_int32 .or. axis0 >= rank) then
      dim1 = -1_int32
      call set_status(status, FENUM_STATUS_INVALID_AXIS, &
        "axis0 is out of bounds for ndarray rank")
      return
    end if

    dim1 = axis0 + 1_int32
    call set_status(status, FENUM_STATUS_OK)
  end function axis0_to_dim1

  logical function view_bounds_are_valid(source, shape, strides, offset)
    type(ndarray_r64), intent(in) :: source
    integer(int64), intent(in) :: shape(:)
    integer(int64), intent(in) :: strides(:)
    integer(int64), intent(in) :: offset
    integer(int64) :: min_position
    integer(int64) :: max_position
    integer(int64) :: contribution
    integer(int32) :: dim1

    if (element_count(shape) == 0_int64) then
      view_bounds_are_valid = .true.
      return
    end if

    min_position = offset
    max_position = offset
    do dim1 = 1_int32, int(size(shape), int32)
      contribution = (shape(dim1) - 1_int64) * strides(dim1)
      if (contribution < 0_int64) then
        min_position = min_position + contribution
      else
        max_position = max_position + contribution
      end if
    end do

    view_bounds_are_valid = min_position >= 1_int64 .and. &
      max_position <= source%storage_size()
  end function view_bounds_are_valid

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
        "view index vector allocation failed")
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
end module fenum_views_r64
