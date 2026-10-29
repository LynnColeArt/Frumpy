!> C dispatch for native views and explicit copies.
module frumpy_c_views
  use iso_c_binding, only: c_ptr, c_int32_t, c_int64_t
  use iso_fortran_env, only: int32, int64
  use frumpy_c_handles, only: handle_slot, lookup, new_array_slot, publish, output_pointer
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR
  use frumpy_operands, only: descriptor_dtype
  use frumpy_c_handles, only: read_parameters
  use frumpy, only: ndarray_bool, transpose_bool, reshape_bool, swapaxes_bool, &
    squeeze_bool, expand_dims_bool, slice_bool, ravel_bool, flatten_bool, copy_bool, &
    ascontiguousarray_bool
  use frumpy, only: ndarray_i32, transpose_i32, reshape_i32, swapaxes_i32, &
    squeeze_i32, expand_dims_i32, slice_i32, ravel_i32, flatten_i32, copy_i32, &
    ascontiguousarray_i32
  use frumpy, only: ndarray_i64, transpose_i64, reshape_i64, swapaxes_i64, &
    squeeze_i64, expand_dims_i64, slice_i64, ravel_i64, flatten_i64, copy_i64, &
    ascontiguousarray_i64
  use frumpy, only: ndarray_r32, transpose_r32, reshape_r32, swapaxes_r32, &
    squeeze_r32, expand_dims_r32, slice_r32, ravel_r32, flatten_r32, copy_r32, &
    ascontiguousarray_r32
  use frumpy, only: ndarray_r64, transpose_r64, reshape_r64, swapaxes_r64, &
    squeeze_r64, expand_dims_r64, slice_r64, ravel_r64, flatten_r64, copy_r64, &
    ascontiguousarray_r64
  use frumpy_statuses, only: FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_INVALID_AXIS
  use frumpy_slices, only: slice_spec
  implicit none
  private
contains
  integer(c_int32_t) function view(operation, source, parameters, count, output) &
      bind(C, name="frumpy_view") result(code)
    integer(c_int32_t), value :: operation, count
    integer(c_int64_t), value :: source
    type(c_ptr), value :: parameters, output
    integer(c_int64_t), pointer :: out
    integer(int64), allocatable :: values(:)
    type(handle_slot), pointer :: input, slot
    type(frumpy_status) :: status
    type(slice_spec) :: specs(32)
    integer(int32) :: i, axis, order

    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    input => lookup(source, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    call read_parameters(parameters, count, values, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR
    if (operation < 1 .or. operation > 10) return
    code = FRUMPY_STATUS_INVALID_SHAPE
    select case (operation)
    case (1)
      if (count > 32) return
    case (2,7,8,10)
      if (count /= 0) return
    case (3)
      if (count /= 2) return
    case (4,9)
      if (count > 1) return
    case (5)
      if (count /= 1) return
    case (6)
      if (mod(count,3) /= 0) return
      do i = 1, count / 3
        specs(i) = slice_spec(values(3*i-2), values(3*i-1), values(3*i), .false.)
      end do
    end select
    if (operation == 3 .or. operation == 4 .or. operation == 5 .or. operation == 9) then
      code = FRUMPY_STATUS_INVALID_AXIS
      if (any(values > int(huge(1_int32),int64)) .or. &
          any(values < -int(huge(1_int32),int64)-1_int64)) return
    end if
    axis = 0_int32
    order = 0_int32
    if (count > 0) then
      if (operation == 4 .or. operation == 5) axis = int(values(1),int32)
      if (operation == 9) order = int(values(1),int32)
    end if
    call new_array_slot(descriptor_dtype(input%array), slot, status)
    code = status%code
    if (status%is_failure()) return
    select type (a => input%array)
    type is (ndarray_bool)
      select type (b => slot%array)
      type is (ndarray_bool)
        select case (operation)
        case (1)
          b = reshape_bool(a, values, status)
        case (2)
          b = transpose_bool(a, status)
        case (3)
          b = swapaxes_bool(a, int(values(1),int32), int(values(2),int32), status)
        case (4)
          if (count == 0) then
            b = squeeze_bool(a, status=status)
          else
            b = squeeze_bool(a, axis, status)
          end if
        case (5)
          b = expand_dims_bool(a, axis, status)
        case (6)
          b = slice_bool(a, specs(:count/3), status)
        case (7)
          b = ravel_bool(a, status)
        case (8)
          b = flatten_bool(a, status)
        case (9)
          b = copy_bool(a, order, status)
        case (10)
          b = ascontiguousarray_bool(a, status)
        end select
      end select
    type is (ndarray_i32)
      select type (b => slot%array)
      type is (ndarray_i32)
        select case (operation)
        case (1)
          b = reshape_i32(a, values, status)
        case (2)
          b = transpose_i32(a, status)
        case (3)
          b = swapaxes_i32(a, int(values(1),int32), int(values(2),int32), status)
        case (4)
          if (count == 0) then
            b = squeeze_i32(a, status=status)
          else
            b = squeeze_i32(a, axis, status)
          end if
        case (5)
          b = expand_dims_i32(a, axis, status)
        case (6)
          b = slice_i32(a, specs(:count/3), status)
        case (7)
          b = ravel_i32(a, status)
        case (8)
          b = flatten_i32(a, status)
        case (9)
          b = copy_i32(a, order, status)
        case (10)
          b = ascontiguousarray_i32(a, status)
        end select
      end select
    type is (ndarray_i64)
      select type (b => slot%array)
      type is (ndarray_i64)
        select case (operation)
        case (1)
          b = reshape_i64(a, values, status)
        case (2)
          b = transpose_i64(a, status)
        case (3)
          b = swapaxes_i64(a, int(values(1),int32), int(values(2),int32), status)
        case (4)
          if (count == 0) then
            b = squeeze_i64(a, status=status)
          else
            b = squeeze_i64(a, axis, status)
          end if
        case (5)
          b = expand_dims_i64(a, axis, status)
        case (6)
          b = slice_i64(a, specs(:count/3), status)
        case (7)
          b = ravel_i64(a, status)
        case (8)
          b = flatten_i64(a, status)
        case (9)
          b = copy_i64(a, order, status)
        case (10)
          b = ascontiguousarray_i64(a, status)
        end select
      end select
    type is (ndarray_r32)
      select type (b => slot%array)
      type is (ndarray_r32)
        select case (operation)
        case (1)
          b = reshape_r32(a, values, status)
        case (2)
          b = transpose_r32(a, status)
        case (3)
          b = swapaxes_r32(a, int(values(1),int32), int(values(2),int32), status)
        case (4)
          if (count == 0) then
            b = squeeze_r32(a, status=status)
          else
            b = squeeze_r32(a, axis, status)
          end if
        case (5)
          b = expand_dims_r32(a, axis, status)
        case (6)
          b = slice_r32(a, specs(:count/3), status)
        case (7)
          b = ravel_r32(a, status)
        case (8)
          b = flatten_r32(a, status)
        case (9)
          b = copy_r32(a, order, status)
        case (10)
          b = ascontiguousarray_r32(a, status)
        end select
      end select
    type is (ndarray_r64)
      select type (b => slot%array)
      type is (ndarray_r64)
        select case (operation)
        case (1)
          b = reshape_r64(a, values, status)
        case (2)
          b = transpose_r64(a, status)
        case (3)
          b = swapaxes_r64(a, int(values(1),int32), int(values(2),int32), status)
        case (4)
          if (count == 0) then
            b = squeeze_r64(a, status=status)
          else
            b = squeeze_r64(a, axis, status)
          end if
        case (5)
          b = expand_dims_r64(a, axis, status)
        case (6)
          b = slice_r64(a, specs(:count/3), status)
        case (7)
          b = ravel_r64(a, status)
        case (8)
          b = flatten_r64(a, status)
        case (9)
          b = copy_r64(a, order, status)
        case (10)
          b = ascontiguousarray_r64(a, status)
        end select
      end select
    end select
    call publish(slot, out, status)
    code = status%code
  end function view
end module frumpy_c_views
