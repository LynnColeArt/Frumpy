!> Concrete r32 views backed by shared metadata planning and retained typed storage.
module frumpy_views_r32
  use iso_fortran_env, only: int32, int64
  use frumpy_ndarray_r32, only: ndarray_r32, view_descriptor_r32
  use frumpy_constructors_r32, only: empty_r32
  use frumpy_constructors_r32, only: validate_source => validate_r32
  use frumpy_strides, only: flat_offset, is_c_contiguous
  use frumpy_slices, only: slice_spec
  use frumpy_view_plans, only: array_layout, make_layout, reshape_layout, transpose_layout, &
    swapaxes_layout, squeeze_layout, expand_dims_layout, slice_layout
  use frumpy_statuses, only: frumpy_status
  implicit none
  private
  public :: reshape_r32, ravel_r32, flatten_r32, transpose_r32, swapaxes_r32
  public :: squeeze_r32, expand_dims_r32, slice_r32
contains
  function reshape_r32(source, new_shape, status) result(view)
    type(ndarray_r32), intent(in) :: source
    integer(int64), intent(in) :: new_shape(:)
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: view
    type(frumpy_status) :: local_status
    type(array_layout) :: layout, planned

    call validate_source(source, local_status)
    if (local_status%is_ok()) layout = make_layout(source%shape, source%strides, &
      source%offset, source%storage_size(), local_status)
    if (local_status%is_ok()) planned = reshape_layout(layout, new_shape, local_status)
    if (local_status%is_ok()) view = view_descriptor_r32(source, planned%shape, &
      planned%strides, planned%offset, local_status)
    if (present(status)) status = local_status
  end function reshape_r32

  function transpose_r32(source, status) result(view)
    type(ndarray_r32), intent(in) :: source
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: view
    type(frumpy_status) :: local_status
    type(array_layout) :: layout, planned

    call validate_source(source, local_status)
    if (local_status%is_ok()) layout = make_layout(source%shape, source%strides, &
      source%offset, source%storage_size(), local_status)
    if (local_status%is_ok()) planned = transpose_layout(layout, local_status)
    if (local_status%is_ok()) view = view_descriptor_r32(source, planned%shape, &
      planned%strides, planned%offset, local_status)
    if (present(status)) status = local_status
  end function transpose_r32

  function swapaxes_r32(source, axis0_a, axis0_b, status) result(view)
    type(ndarray_r32), intent(in) :: source
    integer(int32), intent(in) :: axis0_a, axis0_b
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: view
    type(frumpy_status) :: local_status
    type(array_layout) :: layout, planned

    call validate_source(source, local_status)
    if (local_status%is_ok()) layout = make_layout(source%shape, source%strides, &
      source%offset, source%storage_size(), local_status)
    if (local_status%is_ok()) planned = swapaxes_layout(layout, axis0_a, axis0_b, local_status)
    if (local_status%is_ok()) view = view_descriptor_r32(source, planned%shape, &
      planned%strides, planned%offset, local_status)
    if (present(status)) status = local_status
  end function swapaxes_r32

  function squeeze_r32(source, axis0, status) result(view)
    type(ndarray_r32), intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: view
    type(frumpy_status) :: local_status
    type(array_layout) :: layout, planned

    call validate_source(source, local_status)
    if (local_status%is_ok()) layout = make_layout(source%shape, source%strides, &
      source%offset, source%storage_size(), local_status)
    if (local_status%is_ok()) planned = squeeze_layout(layout, axis0, local_status)
    if (local_status%is_ok()) view = view_descriptor_r32(source, planned%shape, &
      planned%strides, planned%offset, local_status)
    if (present(status)) status = local_status
  end function squeeze_r32

  function expand_dims_r32(source, axis0, status) result(view)
    type(ndarray_r32), intent(in) :: source
    integer(int32), intent(in) :: axis0
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: view
    type(frumpy_status) :: local_status
    type(array_layout) :: layout, planned

    call validate_source(source, local_status)
    if (local_status%is_ok()) layout = make_layout(source%shape, source%strides, &
      source%offset, source%storage_size(), local_status)
    if (local_status%is_ok()) planned = expand_dims_layout(layout, axis0, local_status)
    if (local_status%is_ok()) view = view_descriptor_r32(source, planned%shape, &
      planned%strides, planned%offset, local_status)
    if (present(status)) status = local_status
  end function expand_dims_r32

  function slice_r32(source, specs, status) result(view)
    type(ndarray_r32), intent(in) :: source
    type(slice_spec), intent(in) :: specs(:)
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: view
    type(frumpy_status) :: local_status
    type(array_layout) :: layout, planned

    call validate_source(source, local_status)
    if (local_status%is_ok()) layout = make_layout(source%shape, source%strides, &
      source%offset, source%storage_size(), local_status)
    if (local_status%is_ok()) planned = slice_layout(layout, specs, local_status)
    if (local_status%is_ok()) view = view_descriptor_r32(source, planned%shape, &
      planned%strides, planned%offset, local_status)
    if (present(status)) status = local_status
  end function slice_r32

  function ravel_r32(source, status) result(array)
    type(ndarray_r32), intent(in) :: source
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: array
    type(frumpy_status) :: local_status

    call validate_source(source, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    if (is_c_contiguous(source%shape, source%strides)) then
      array = reshape_r32(source, [source%size()], status)
    else
      array = flatten_r32(source, status)
    end if
  end function ravel_r32

  function flatten_r32(source, status) result(array)
    type(ndarray_r32), intent(in) :: source
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: array
    type(frumpy_status) :: local_status
    integer(int64) :: i0, position

    call validate_source(source, local_status)
    if (local_status%is_ok()) array = empty_r32([source%size()], status=local_status)
    if (present(status)) status = local_status
    if (local_status%is_failure()) return
    do i0 = 0_int64, source%size() - 1_int64
      position = flat_offset(source%shape, source%strides, source%offset, i0)
      array%data(i0 + 1_int64) = source%data(position)
    end do
  end function flatten_r32
end module frumpy_views_r32
