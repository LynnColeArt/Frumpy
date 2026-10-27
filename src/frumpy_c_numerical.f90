!> C entry points for the bounded float64 numerical surface.
module frumpy_c_numerical
  use iso_c_binding, only: c_ptr, c_int32_t, c_int64_t
  use iso_fortran_env, only: int32, int64
  use frumpy_c_handles, only: handle_slot, lookup, new_array_slot, publish, output_pointer, &
    read_parameters
  use frumpy_statuses, only: frumpy_status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    FRUMPY_STATUS_UNSUPPORTED_DTYPE, FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_INVALID_AXIS
  use frumpy_operands, only: descriptor_dtype
  use frumpy, only: ndarray_r64, outer_r64, dot_r64, matmul_r64, solve_r64, &
    vector_norm_r64, matrix_norm_r64
  implicit none
  private
contains
  integer(c_int32_t) function linalg(operation, lhs, rhs, output) &
      bind(C, name="frumpy_linalg") result(code)
    integer(c_int32_t), value :: operation
    integer(c_int64_t), value :: lhs, rhs
    type(c_ptr), value :: output
    integer(c_int64_t), pointer :: out
    type(handle_slot), pointer :: left, right, slot
    type(frumpy_status) :: status

    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    left => lookup(lhs, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    right => lookup(rhs, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR
    if (operation < 1 .or. operation > 4) return
    code = FRUMPY_STATUS_UNSUPPORTED_DTYPE
    if (descriptor_dtype(left%array) /= 5 .or. descriptor_dtype(right%array) /= 5) return
    call new_array_slot(5_int32, slot, status)
    code = status%code
    if (status%is_failure()) return
    select type (a => left%array)
    type is (ndarray_r64)
      select type (b => right%array)
      type is (ndarray_r64)
        select type (c => slot%array)
        type is (ndarray_r64)
          select case (operation)
          case (1)
            c = outer_r64(a, b, status)
          case (2)
            c = dot_r64(a, b, status)
          case (3)
            c = matmul_r64(a, b, status)
          case (4)
            c = solve_r64(a, b, status)
          end select
        end select
      end select
    end select
    call publish(slot, out, status)
    code = status%code
  end function linalg

  integer(c_int32_t) function norm(matrix, source, axes, count, keepdims, output) &
      bind(C, name="frumpy_norm") result(code)
    integer(c_int32_t), value :: matrix, count, keepdims
    integer(c_int64_t), value :: source
    type(c_ptr), value :: axes, output
    integer(c_int64_t), pointer :: out
    integer(int64), allocatable :: values(:)
    type(handle_slot), pointer :: input, slot
    type(frumpy_status) :: status

    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    input => lookup(source, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_INVALID_SHAPE
    if (matrix < 0 .or. matrix > 1 .or. keepdims < 0 .or. keepdims > 1) return
    if (count /= 0 .and. count /= matrix + 1) return
    call read_parameters(axes, count, values, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_INVALID_AXIS
    if (any(values > int(huge(1_int32),int64)) .or. &
        any(values < -int(huge(1_int32),int64)-1_int64)) return
    code = FRUMPY_STATUS_UNSUPPORTED_DTYPE
    if (descriptor_dtype(input%array) /= 5) return
    call new_array_slot(5_int32, slot, status)
    code = status%code
    if (status%is_failure()) return
    select type (a => input%array)
    type is (ndarray_r64)
      select type (b => slot%array)
      type is (ndarray_r64)
        if (matrix == 1) then
          if (count == 0) then
            b = matrix_norm_r64(a, keepdims=keepdims == 1, status=status)
          else
            b = matrix_norm_r64(a, int(values,int32), keepdims == 1, status)
          end if
        else
          if (count == 0) then
            b = vector_norm_r64(a, keepdims=keepdims == 1, status=status)
          else
            b = vector_norm_r64(a, int(values(1),int32), keepdims == 1, status)
          end if
        end if
      end select
    end select
    call publish(slot, out, status)
    code = status%code
  end function norm
end module frumpy_c_numerical
