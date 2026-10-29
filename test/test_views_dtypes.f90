!> All concrete view wrappers preserve aliasing and independent flatten copies.
program test_views_dtypes
  use iso_fortran_env, only: int8, int32, int64, real32
  use frumpy, only: frumpy_status, slice_all, slice_range, FRUMPY_STATUS_INVALID_SHAPE
  use frumpy, only: ndarray_bool, asarray_bool, reshape_bool, ravel_bool
  use frumpy, only: flatten_bool, transpose_bool, swapaxes_bool
  use frumpy, only: squeeze_bool, expand_dims_bool, slice_bool
  use frumpy, only: ndarray_i32, asarray_i32, reshape_i32, ravel_i32
  use frumpy, only: flatten_i32, transpose_i32, swapaxes_i32
  use frumpy, only: squeeze_i32, expand_dims_i32, slice_i32
  use frumpy, only: ndarray_i64, asarray_i64, reshape_i64, ravel_i64
  use frumpy, only: flatten_i64, transpose_i64, swapaxes_i64
  use frumpy, only: squeeze_i64, expand_dims_i64, slice_i64
  use frumpy, only: ndarray_r32, asarray_r32, reshape_r32, ravel_r32
  use frumpy, only: flatten_r32, transpose_r32, swapaxes_r32
  use frumpy, only: squeeze_r32, expand_dims_r32, slice_r32
  use frumpy, only: owned_descriptor_i64, view_descriptor_i64
  use frumpy_slices, only: slice_length
  implicit none
  call extreme_slices()
  call exercise_bool()
  call exercise_i32()
  call exercise_i64()
  call exercise_r32()
contains
  subroutine exercise_bool()
    type(ndarray_bool) :: source, view, result, extra
    type(frumpy_status) :: status

    source = asarray_bool([.true.,.true.,.false.,.false.,.false.,.true.], [2_int64, 3_int64])
    view = reshape_bool(source, [3_int64, 2_int64], status)
    call require(status%is_ok() .and. associated(view%data, source%data), 'bool reshape shares')
    call require(all(view%shape == [3_int64, 2_int64]), 'bool reshape shape')
    result = ravel_bool(source, status)
    call require(status%is_ok() .and. associated(result%data, source%data), 'bool ravel shares')
    result = flatten_bool(source, status)
    call require(status%is_ok() .and. .not. associated(result%data, source%data), &
      'bool flatten copy')
    view = transpose_bool(source, status)
    call require(status%is_ok() .and. all(view%shape == [3_int64, 2_int64]), 'bool transpose')
    result = ravel_bool(view, status)
    call require(status%is_ok() .and. result%owns_data, 'bool noncontiguous ravel copies')
    view = swapaxes_bool(source, 0_int32, 1_int32, status)
    call require(status%is_ok() .and. all(view%strides == [1_int64, 3_int64]), 'bool swapaxes')
    extra = expand_dims_bool(source, 1_int32, status)
    call require(status%is_ok() .and. all(extra%shape == [2_int64,1_int64,3_int64]), 'bool expand')
    view = squeeze_bool(extra, status=status)
    call require(status%is_ok() .and. all(view%shape == source%shape), 'bool squeeze')
    view = slice_bool(source, [slice_all(), &
      slice_range(2_int64, -1_int64, -1_int64)], status)
    call require(status%is_ok(), 'bool reverse slice')
    call require(all(view%strides == [3_int64,-1_int64]), 'bool reverse strides')
    call require(view%offset == 3_int64, 'bool reverse offset')
    view%data(view%offset) = 0_int8
    call require(abs(real(source%data(3),real32)) < 1e-6_real32, 'bool shared mutation')
    call source%release()
    call extra%release()
    call require(view%has_storage(), 'bool view survives source')
    result = flatten_bool(view, status)
    call require(status%is_ok() .and. result%owns_data, 'bool flatten surviving view')
    view%offset = huge(1_int64)
    result = transpose_bool(view, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'bool invalid source bounds')
    call require(.not. result%has_storage(), 'bool invalid view no storage')
  end subroutine exercise_bool

  subroutine exercise_i32()
    type(ndarray_i32) :: source, view, result, extra
    type(frumpy_status) :: status

    source = asarray_i32([1_int32,2_int32,3_int32,4_int32,5_int32,6_int32], [2_int64, 3_int64])
    view = reshape_i32(source, [3_int64, 2_int64], status)
    call require(status%is_ok() .and. associated(view%data, source%data), 'i32 reshape shares')
    call require(all(view%shape == [3_int64, 2_int64]), 'i32 reshape shape')
    result = ravel_i32(source, status)
    call require(status%is_ok() .and. associated(result%data, source%data), 'i32 ravel shares')
    result = flatten_i32(source, status)
    call require(status%is_ok() .and. .not. associated(result%data, source%data), &
      'i32 flatten copy')
    view = transpose_i32(source, status)
    call require(status%is_ok() .and. all(view%shape == [3_int64, 2_int64]), 'i32 transpose')
    result = ravel_i32(view, status)
    call require(status%is_ok() .and. result%owns_data, 'i32 noncontiguous ravel copies')
    view = swapaxes_i32(source, 0_int32, 1_int32, status)
    call require(status%is_ok() .and. all(view%strides == [1_int64, 3_int64]), 'i32 swapaxes')
    extra = expand_dims_i32(source, 1_int32, status)
    call require(status%is_ok() .and. all(extra%shape == [2_int64,1_int64,3_int64]), 'i32 expand')
    view = squeeze_i32(extra, status=status)
    call require(status%is_ok() .and. all(view%shape == source%shape), 'i32 squeeze')
    view = slice_i32(source, [slice_all(), &
      slice_range(2_int64, -1_int64, -1_int64)], status)
    call require(status%is_ok(), 'i32 reverse slice')
    call require(all(view%strides == [3_int64,-1_int64]), 'i32 reverse strides')
    call require(view%offset == 3_int64, 'i32 reverse offset')
    view%data(view%offset) = 0_int32
    call require(abs(real(source%data(3),real32)) < 1e-6_real32, 'i32 shared mutation')
    call source%release()
    call extra%release()
    call require(view%has_storage(), 'i32 view survives source')
    result = flatten_i32(view, status)
    call require(status%is_ok() .and. result%owns_data, 'i32 flatten surviving view')
    view%offset = huge(1_int64)
    result = transpose_i32(view, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'i32 invalid source bounds')
    call require(.not. result%has_storage(), 'i32 invalid view no storage')
  end subroutine exercise_i32

  subroutine exercise_i64()
    type(ndarray_i64) :: source, view, result, extra
    type(frumpy_status) :: status

    source = asarray_i64([1_int64,2_int64,3_int64,4_int64,5_int64,6_int64], [2_int64, 3_int64])
    view = reshape_i64(source, [3_int64, 2_int64], status)
    call require(status%is_ok() .and. associated(view%data, source%data), 'i64 reshape shares')
    call require(all(view%shape == [3_int64, 2_int64]), 'i64 reshape shape')
    result = ravel_i64(source, status)
    call require(status%is_ok() .and. associated(result%data, source%data), 'i64 ravel shares')
    result = flatten_i64(source, status)
    call require(status%is_ok() .and. .not. associated(result%data, source%data), &
      'i64 flatten copy')
    view = transpose_i64(source, status)
    call require(status%is_ok() .and. all(view%shape == [3_int64, 2_int64]), 'i64 transpose')
    result = ravel_i64(view, status)
    call require(status%is_ok() .and. result%owns_data, 'i64 noncontiguous ravel copies')
    view = swapaxes_i64(source, 0_int32, 1_int32, status)
    call require(status%is_ok() .and. all(view%strides == [1_int64, 3_int64]), 'i64 swapaxes')
    extra = expand_dims_i64(source, 1_int32, status)
    call require(status%is_ok() .and. all(extra%shape == [2_int64,1_int64,3_int64]), 'i64 expand')
    view = squeeze_i64(extra, status=status)
    call require(status%is_ok() .and. all(view%shape == source%shape), 'i64 squeeze')
    view = slice_i64(source, [slice_all(), &
      slice_range(2_int64, -1_int64, -1_int64)], status)
    call require(status%is_ok(), 'i64 reverse slice')
    call require(all(view%strides == [3_int64,-1_int64]), 'i64 reverse strides')
    call require(view%offset == 3_int64, 'i64 reverse offset')
    view%data(view%offset) = 0_int64
    call require(abs(real(source%data(3),real32)) < 1e-6_real32, 'i64 shared mutation')
    call source%release()
    call extra%release()
    call require(view%has_storage(), 'i64 view survives source')
    result = flatten_i64(view, status)
    call require(status%is_ok() .and. result%owns_data, 'i64 flatten surviving view')
    view%offset = huge(1_int64)
    result = transpose_i64(view, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'i64 invalid source bounds')
    call require(.not. result%has_storage(), 'i64 invalid view no storage')
  end subroutine exercise_i64

  subroutine exercise_r32()
    type(ndarray_r32) :: source, view, result, extra
    type(frumpy_status) :: status

    source = asarray_r32([1.0_real32,2.0_real32,3.0_real32,4.0_real32,5.0_real32, &
      6.0_real32], [2_int64, 3_int64])
    view = reshape_r32(source, [3_int64, 2_int64], status)
    call require(status%is_ok() .and. associated(view%data, source%data), 'r32 reshape shares')
    call require(all(view%shape == [3_int64, 2_int64]), 'r32 reshape shape')
    result = ravel_r32(source, status)
    call require(status%is_ok() .and. associated(result%data, source%data), 'r32 ravel shares')
    result = flatten_r32(source, status)
    call require(status%is_ok() .and. .not. associated(result%data, source%data), &
      'r32 flatten copy')
    view = transpose_r32(source, status)
    call require(status%is_ok() .and. all(view%shape == [3_int64, 2_int64]), 'r32 transpose')
    result = ravel_r32(view, status)
    call require(status%is_ok() .and. result%owns_data, 'r32 noncontiguous ravel copies')
    view = swapaxes_r32(source, 0_int32, 1_int32, status)
    call require(status%is_ok() .and. all(view%strides == [1_int64, 3_int64]), 'r32 swapaxes')
    extra = expand_dims_r32(source, 1_int32, status)
    call require(status%is_ok() .and. all(extra%shape == [2_int64,1_int64,3_int64]), 'r32 expand')
    view = squeeze_r32(extra, status=status)
    call require(status%is_ok() .and. all(view%shape == source%shape), 'r32 squeeze')
    view = slice_r32(source, [slice_all(), &
      slice_range(2_int64, -1_int64, -1_int64)], status)
    call require(status%is_ok(), 'r32 reverse slice')
    call require(all(view%strides == [3_int64,-1_int64]), 'r32 reverse strides')
    call require(view%offset == 3_int64, 'r32 reverse offset')
    view%data(view%offset) = 0.0_real32
    call require(abs(real(source%data(3),real32)) < 1e-6_real32, 'r32 shared mutation')
    call source%release()
    call extra%release()
    call require(view%has_storage(), 'r32 view survives source')
    result = flatten_r32(view, status)
    call require(status%is_ok() .and. result%owns_data, 'r32 flatten surviving view')
    view%offset = huge(1_int64)
    result = transpose_r32(view, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'r32 invalid source bounds')
    call require(.not. result%has_storage(), 'r32 invalid view no storage')
  end subroutine exercise_r32

  subroutine extreme_slices()
    type(ndarray_i64) :: owner, virtual, result
    type(frumpy_status) :: status
    integer(int64) :: count

    owner = owned_descriptor_i64([1_int64])
    virtual = view_descriptor_i64(owner, [1_int64], [huge(1_int64)], 1_int64)
    result = slice_i64(virtual, [slice_range(1_int64, 1_int64)], status)
    call require(status%is_ok() .and. result%size() == 0, 'empty slice avoids conceptual offset')
    count = slice_length(slice_range(0_int64, 1_int64, huge(1_int64)), 1_int64, status)
    call require(status%is_ok() .and. count == 1, 'maximum step length')
    count = slice_length(slice_range(0_int64, -1_int64, -huge(1_int64)-1_int64), 1_int64, status)
    call require(status%is_ok() .and. count == 1, 'minimum step length')
  end subroutine extreme_slices

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_views_dtypes
