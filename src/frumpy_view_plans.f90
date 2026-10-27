!> Dtype-independent metadata plans; these routines never allocate or touch array payloads.
module frumpy_view_plans
  use iso_fortran_env, only: int32, int64
  use frumpy_shape, only: element_count
  use frumpy_slices, only: slice_spec, slice_length
  use frumpy_strides, only: c_order_strides, is_c_contiguous, storage_bounds_are_valid
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_INVALID_AXIS, FRUMPY_STATUS_ALLOCATION_FAILED, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, FRUMPY_STATUS_OVERFLOW
  implicit none
  private
  public :: array_layout, make_layout, reshape_layout, transpose_layout, swapaxes_layout
  public :: squeeze_layout, expand_dims_layout, slice_layout
  type :: array_layout
    integer(int32) :: rank = 0_int32
    integer(int64), allocatable :: shape(:), strides(:)
    integer(int64) :: offset = 1_int64, storage_count = 0_int64
    logical :: is_c_contiguous = .false.
  end type array_layout
contains
  function make_layout(shape, strides, offset, storage_count, status) result(layout)
    integer(int64), intent(in) :: shape(:), strides(:), offset, storage_count
    type(frumpy_status), intent(out) :: status
    type(array_layout) :: layout
    integer(int32) :: alloc_stat

    call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, "invalid view layout")
    if (.not. storage_bounds_are_valid(shape, strides, offset, storage_count)) return
    allocate(layout%shape(size(shape)), layout%strides(size(strides)), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, "layout allocation failed")
      return
    end if
    layout%rank = int(size(shape), int32)
    layout%shape = shape
    layout%strides = strides
    layout%offset = offset
    layout%storage_count = storage_count
    layout%is_c_contiguous = is_c_contiguous(shape, strides)
    call set_status(status, FRUMPY_STATUS_OK)
  end function make_layout

  function view_descriptor_layout(source, shape, strides, offset, status) result(layout)
    type(array_layout), intent(in) :: source
    integer(int64), intent(in) :: shape(:), strides(:), offset
    type(frumpy_status), intent(out) :: status
    type(array_layout) :: layout

    layout = make_layout(shape, strides, offset, source%storage_count, status)
  end function view_descriptor_layout

  subroutine validate_view_source(source, status)
    type(array_layout), intent(in) :: source
    type(frumpy_status), intent(out) :: status

    call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, "invalid view source layout")
    if (.not. allocated(source%shape) .or. .not. allocated(source%strides)) return
    if (source%rank /= size(source%shape)) return
    if (.not. storage_bounds_are_valid(source%shape, source%strides, source%offset, &
        source%storage_count)) return
    call set_status(status, FRUMPY_STATUS_OK)
  end subroutine validate_view_source

  integer(int64) function checked_product(lhs, rhs, status) result(value)
    integer(int64), intent(in) :: lhs, rhs
    type(frumpy_status), intent(out) :: status
    integer(int64), parameter :: LOW = -huge(1_int64) - 1_int64, HIGH = huge(1_int64)
    logical :: overflow

    overflow = .false.
    value = 0_int64
    if (rhs > 0_int64) then
      overflow = lhs > HIGH / rhs .or. lhs < LOW / rhs
    else if (rhs < 0_int64) then
      if (lhs > 0_int64) overflow = rhs < LOW / lhs
      if (lhs < 0_int64) overflow = lhs < HIGH / rhs
    end if
    if (overflow) then
      call set_status(status, FRUMPY_STATUS_OVERFLOW, "slice stride product overflows")
    else
      value = lhs * rhs
      call set_status(status, FRUMPY_STATUS_OK)
    end if
  end function checked_product

  function reshape_layout(source, new_shape, status) result(view)
    type(array_layout), intent(in) :: source
    integer(int64), intent(in) :: new_shape(:)
    type(frumpy_status), intent(out), optional :: status
    type(array_layout) :: view
    type(frumpy_status) :: local_status
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

    if (new_count /= element_count(source%shape)) then
      call set_optional_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "reshape_layout new shape element count must match source size")
      return
    end if

    if (.not. source%is_c_contiguous) then
      call set_optional_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "reshape_layout currently returns views only for C-contiguous sources")
      return
    end if

    new_strides = c_order_strides(new_shape, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    view = view_descriptor_layout(source, new_shape, new_strides, &
      source%offset, local_status)
    call set_optional_status_value(status, local_status)
  end function reshape_layout

  function transpose_layout(source, status) result(view)
    type(array_layout), intent(in) :: source
    type(frumpy_status), intent(out), optional :: status
    type(array_layout) :: view
    type(frumpy_status) :: local_status
    integer(int64), allocatable :: new_shape(:)
    integer(int64), allocatable :: new_strides(:)
    integer(int32) :: dim1
    integer(int32) :: alloc_stat

    call validate_view_source(source, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    allocate(new_shape(source%rank), new_strides(source%rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_optional_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "transpose_layout metadata allocation failed")
      return
    end if

    do dim1 = 1_int32, source%rank
      new_shape(dim1) = source%shape(source%rank - dim1 + 1_int32)
      new_strides(dim1) = source%strides(source%rank - dim1 + 1_int32)
    end do

    view = view_descriptor_layout(source, new_shape, new_strides, &
      source%offset, local_status)
    call set_optional_status_value(status, local_status)
  end function transpose_layout

  function swapaxes_layout(source, axis0_a, axis0_b, status) result(view)
    type(array_layout), intent(in) :: source
    integer(int32), intent(in) :: axis0_a
    integer(int32), intent(in) :: axis0_b
    type(frumpy_status), intent(out), optional :: status
    type(array_layout) :: view
    type(frumpy_status) :: local_status
    integer(int64), allocatable :: new_shape(:)
    integer(int64), allocatable :: new_strides(:)
    integer(int64) :: saved_value
    integer(int32) :: dim1_a
    integer(int32) :: dim1_b
    integer(int32) :: alloc_stat

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
      call set_optional_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "swapaxes_layout metadata allocation failed")
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

    view = view_descriptor_layout(source, new_shape, new_strides, &
      source%offset, local_status)
    call set_optional_status_value(status, local_status)
  end function swapaxes_layout

  function squeeze_layout(source, axis0, status) result(view)
    type(array_layout), intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    type(frumpy_status), intent(out), optional :: status
    type(array_layout) :: view
    type(frumpy_status) :: local_status
    integer(int64), allocatable :: new_shape(:)
    integer(int64), allocatable :: new_strides(:)
    integer(int32) :: dim1
    integer(int32) :: squeezed_dim1
    integer(int32) :: output_dim1
    integer(int32) :: output_rank
    integer(int32) :: alloc_stat

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
        call set_optional_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
          "squeeze_layout axis0 must reference a singleton dimension")
        return
      end if
      output_rank = source%rank - 1_int32
    else
      output_rank = count(source%shape /= 1_int64)
    end if

    allocate(new_shape(output_rank), new_strides(output_rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_optional_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "squeeze_layout metadata allocation failed")
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

    view = view_descriptor_layout(source, new_shape, new_strides, &
      source%offset, local_status)
    call set_optional_status_value(status, local_status)
  end function squeeze_layout

  function expand_dims_layout(source, axis0, status) result(view)
    type(array_layout), intent(in) :: source
    integer(int32), intent(in) :: axis0
    type(frumpy_status), intent(out), optional :: status
    type(array_layout) :: view
    type(frumpy_status) :: local_status
    integer(int64), allocatable :: new_shape(:)
    integer(int64), allocatable :: new_strides(:)
    integer(int32) :: dim1
    integer(int32) :: insert_dim1
    integer(int32) :: source_dim1
    integer(int32) :: alloc_stat

    call validate_view_source(source, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    if (axis0 < 0_int32 .or. axis0 > source%rank) then
      call set_optional_status(status, FRUMPY_STATUS_INVALID_AXIS, &
        "expand_dims_layout axis0 must be between 0 and rank")
      return
    end if

    insert_dim1 = axis0 + 1_int32
    allocate(new_shape(source%rank + 1_int32), &
      new_strides(source%rank + 1_int32), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_optional_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "expand_dims_layout metadata allocation failed")
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

    view = view_descriptor_layout(source, new_shape, new_strides, &
      source%offset, local_status)
    call set_optional_status_value(status, local_status)
  end function expand_dims_layout

  function slice_layout(source, specs, status) result(view)
    type(array_layout), intent(in) :: source
    type(slice_spec), intent(in) :: specs(:)
    type(frumpy_status), intent(out), optional :: status
    type(array_layout) :: view
    type(frumpy_status) :: local_status
    integer(int64), allocatable :: new_shape(:)
    integer(int64), allocatable :: new_strides(:)
    integer(int64) :: new_offset
    integer(int64) :: contribution
    integer(int64) :: start0
    integer(int64) :: resolved_length
    integer(int32) :: dim1
    integer(int32) :: alloc_stat

    call validate_view_source(source, local_status)
    if (local_status%is_failure()) then
      call set_optional_status_value(status, local_status)
      return
    end if

    if (int(size(specs), int32) /= source%rank) then
      call set_optional_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "slice_layout requires one slice_spec per source dimension")
      return
    end if

    allocate(new_shape(source%rank), new_strides(source%rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_optional_status(status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "slice_layout metadata allocation failed")
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
        new_strides(dim1) = checked_product(source%strides(dim1), specs(dim1)%step, local_status)
      end if

      if (local_status%is_failure()) then
        call set_optional_status_value(status, local_status)
        return
      end if
      new_shape(dim1) = resolved_length
    end do

    if (.not. any(new_shape == 0_int64)) then
      do dim1 = 1_int32, source%rank
        if (specs(dim1)%uses_full_extent) cycle
        start0 = specs(dim1)%start0
        contribution = checked_product(start0, source%strides(dim1), local_status)
        if (local_status%is_failure()) then
          call set_optional_status_value(status, local_status)
          return
        end if
        if (contribution > 0_int64) then
          if (new_offset > huge(1_int64) - contribution) then
            call set_optional_status(status, FRUMPY_STATUS_OVERFLOW, "slice offset overflow")
            return
          end if
        else
          if (contribution < -new_offset + 1_int64) then
            call set_optional_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
              "slice offset out of bounds")
            return
          end if
        end if
        new_offset = new_offset + contribution
      end do
    end if
    if (any(new_shape == 0_int64)) new_offset = source%offset
    if (.not. storage_bounds_are_valid(new_shape, new_strides, new_offset, &
        source%storage_count)) then
      call set_optional_status(status, FRUMPY_STATUS_INVALID_SHAPE, &
        "slice_layout view references storage out of bounds")
      return
    end if

    view = view_descriptor_layout(source, new_shape, new_strides, new_offset, &
      local_status)
    call set_optional_status_value(status, local_status)
  end function slice_layout

  integer(int32) function axis0_to_dim1(axis0, rank, status) result(dim1)
    integer(int32), intent(in) :: axis0
    integer(int32), intent(in) :: rank
    type(frumpy_status), intent(out) :: status

    if (axis0 < 0_int32 .or. axis0 >= rank) then
      dim1 = -1_int32
      call set_status(status, FRUMPY_STATUS_INVALID_AXIS, &
        "axis0 is out of bounds for ndarray rank")
      return
    end if

    dim1 = axis0 + 1_int32
    call set_status(status, FRUMPY_STATUS_OK)
  end function axis0_to_dim1

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
end module frumpy_view_plans
