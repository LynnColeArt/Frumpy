!> Concrete bool views backed by shared metadata planning and retained typed storage.
module frumpy_views_bool
  use iso_fortran_env, only: int32, int64
  use frumpy_ndarray_bool, only: ndarray_bool, view_descriptor_bool
  use frumpy_constructors_bool, only: empty_bool
  use frumpy_constructors_bool, only: validate_source => validate_bool
  use frumpy_strides, only: flat_offset, is_c_contiguous
  use frumpy_slices, only: slice_spec
  use frumpy_view_plans, only: array_layout, make_layout, reshape_layout, transpose_layout, &
    swapaxes_layout, squeeze_layout, expand_dims_layout, slice_layout
  use frumpy_statuses, only: frumpy_status
  implicit none
  private
  public :: reshape_bool, ravel_bool, flatten_bool, transpose_bool, swapaxes_bool
  public :: squeeze_bool, expand_dims_bool, slice_bool
contains
  function reshape_bool(source, new_shape, status) result(view)
    type(ndarray_bool), intent(in) :: source
    integer(int64), intent(in) :: new_shape(:)
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: view
    type(frumpy_status) :: local_status
    type(array_layout) :: layout, planned

    call validate_source(source, local_status)
    if (local_status%is_ok()) layout = make_layout(source%shape, source%strides, &
      source%offset, source%storage_size(), local_status)
    if (local_status%is_ok()) planned = reshape_layout(layout, new_shape, local_status)
    if (local_status%is_ok()) view = view_descriptor_bool(source, planned%shape, &
      planned%strides, planned%offset, local_status)
    if (present(status)) status = local_status
  end function reshape_bool

  function transpose_bool(source, status) result(view)
    type(ndarray_bool), intent(in) :: source
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: view
    type(frumpy_status) :: local_status
    type(array_layout) :: layout, planned

    call validate_source(source, local_status)
    if (local_status%is_ok()) layout = make_layout(source%shape, source%strides, &
      source%offset, source%storage_size(), local_status)
    if (local_status%is_ok()) planned = transpose_layout(layout, local_status)
    if (local_status%is_ok()) view = view_descriptor_bool(source, planned%shape, &
      planned%strides, planned%offset, local_status)
    if (present(status)) status = local_status
  end function transpose_bool

  function swapaxes_bool(source, axis0_a, axis0_b, status) result(view)
    type(ndarray_bool), intent(in) :: source
    integer(int32), intent(in) :: axis0_a, axis0_b
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: view
    type(frumpy_status) :: local_status
    type(array_layout) :: layout, planned

    call validate_source(source, local_status)
    if (local_status%is_ok()) layout = make_layout(source%shape, source%strides, &
      source%offset, source%storage_size(), local_status)
    if (local_status%is_ok()) planned = swapaxes_layout(layout, axis0_a, axis0_b, local_status)
    if (local_status%is_ok()) view = view_descriptor_bool(source, planned%shape, &
      planned%strides, planned%offset, local_status)
    if (present(status)) status = local_status
  end function swapaxes_bool

  function squeeze_bool(source, axis0, status) result(view)
    type(ndarray_bool), intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: view
    type(frumpy_status) :: local_status
    type(array_layout) :: layout, planned

    call validate_source(source, local_status)
    if (local_status%is_ok()) layout = make_layout(source%shape, source%strides, &
      source%offset, source%storage_size(), local_status)
    if (local_status%is_ok()) planned = squeeze_layout(layout, axis0, local_status)
    if (local_status%is_ok()) view = view_descriptor_bool(source, planned%shape, &
      planned%strides, planned%offset, local_status)
    if (present(status)) status = local_status
  end function squeeze_bool

  function expand_dims_bool(source, axis0, status) result(view)
    type(ndarray_bool), intent(in) :: source
    integer(int32), intent(in) :: axis0
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: view
    type(frumpy_status) :: local_status
    type(array_layout) :: layout, planned

    call validate_source(source, local_status)
    if (local_status%is_ok()) layout = make_layout(source%shape, source%strides, &
      source%offset, source%storage_size(), local_status)
    if (local_status%is_ok()) planned = expand_dims_layout(layout, axis0, local_status)
    if (local_status%is_ok()) view = view_descriptor_bool(source, planned%shape, &
      planned%strides, planned%offset, local_status)
    if (present(status)) status = local_status
  end function expand_dims_bool

  function slice_bool(source, specs, status) result(view)
    type(ndarray_bool), intent(in) :: source
    type(slice_spec), intent(in) :: specs(:)
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: view
    type(frumpy_status) :: local_status
    type(array_layout) :: layout, planned

    call validate_source(source, local_status)
    if (local_status%is_ok()) layout = make_layout(source%shape, source%strides, &
      source%offset, source%storage_size(), local_status)
    if (local_status%is_ok()) planned = slice_layout(layout, specs, local_status)
    if (local_status%is_ok()) view = view_descriptor_bool(source, planned%shape, &
      planned%strides, planned%offset, local_status)
    if (present(status)) status = local_status
  end function slice_bool

  function ravel_bool(source, status) result(array)
    type(ndarray_bool), intent(in) :: source
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: array
    type(frumpy_status) :: local_status

    call validate_source(source, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    if (is_c_contiguous(source%shape, source%strides)) then
      array = reshape_bool(source, [source%size()], status)
    else
      array = flatten_bool(source, status)
    end if
  end function ravel_bool

  function flatten_bool(source, status) result(array)
    type(ndarray_bool), intent(in) :: source
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_bool) :: array
    type(frumpy_status) :: local_status
    integer(int64) :: i0, position

    call validate_source(source, local_status)
    if (local_status%is_ok()) array = empty_bool([source%size()], status=local_status)
    if (present(status)) status = local_status
    if (local_status%is_failure()) return
    do i0 = 0_int64, source%size() - 1_int64
      position = flat_offset(source%shape, source%strides, source%offset, i0)
      array%data(i0 + 1_int64) = source%data(position)
    end do
  end function flatten_bool
end module frumpy_views_bool
