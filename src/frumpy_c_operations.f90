!> C dispatch for native broadcasting arithmetic and comparisons.
module frumpy_c_operations
  use iso_c_binding, only: c_ptr, c_int32_t, c_int64_t
  use iso_fortran_env, only: int32, int64
  use frumpy_c_handles, only: handle_slot, lookup, new_array_slot, publish, output_pointer
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR
  use frumpy_operands, only: descriptor_dtype
  use frumpy, only: ndarray_bool, binary_result_dtype
  use frumpy, only: add
  use frumpy, only: subtract
  use frumpy, only: multiply
  use frumpy, only: divide
  use frumpy, only: equal
  use frumpy, only: not_equal
  use frumpy, only: less
  use frumpy, only: less_equal
  use frumpy, only: greater
  use frumpy, only: greater_equal
  use frumpy, only: logical_and_bool
  use frumpy, only: logical_or_bool
  use frumpy, only: logical_xor_bool
  use frumpy, only: astype, logical_not_bool
  use frumpy, only: ndarray_r32, negate_r32, abs_r32, sqrt_r32, exp_r32, &
    log_r32, sin_r32, cos_r32
  use frumpy, only: ndarray_r64, negate_r64, abs_r64, sqrt_r64, exp_r64, &
    log_r64, sin_r64, cos_r64
  implicit none
  private
contains
  integer(c_int32_t) function binary(operation, lhs, rhs, output) &
      bind(C, name="frumpy_binary") result(code)
    integer(c_int32_t), value :: operation
    integer(c_int64_t), value :: lhs, rhs
    type(c_ptr), value :: output
    integer(c_int64_t), pointer :: out
    type(handle_slot), pointer :: left, right, slot
    type(frumpy_status) :: status
    integer(int32) :: dtype
    character(len=8), parameter :: names(4) = &
      [character(len=8) :: 'add', 'subtract', 'multiply', 'divide']

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
    if (operation < 1 .or. operation > 13) return
    dtype = 1_int32
    if (operation <= 4) dtype = binary_result_dtype(descriptor_dtype(left%array), &
      descriptor_dtype(right%array), trim(names(operation)), status)
    code = status%code
    if (status%is_failure()) return
    call new_array_slot(dtype, slot, status)
    code = status%code
    if (status%is_failure()) return
    select case (operation)
    case (1)
      call add(left%array, right%array, slot%array, status)
    case (2)
      call subtract(left%array, right%array, slot%array, status)
    case (3)
      call multiply(left%array, right%array, slot%array, status)
    case (4)
      call divide(left%array, right%array, slot%array, status)
    case default
      select type (a => slot%array)
      type is (ndarray_bool)
        select case (operation)
        case (5)
          a = equal(left%array, right%array, status)
        case (6)
          a = not_equal(left%array, right%array, status)
        case (7)
          a = less(left%array, right%array, status)
        case (8)
          a = less_equal(left%array, right%array, status)
        case (9)
          a = greater(left%array, right%array, status)
        case (10)
          a = greater_equal(left%array, right%array, status)
        case (11)
          a = logical_and_bool(left%array, right%array, status)
        case (12)
          a = logical_or_bool(left%array, right%array, status)
        case (13)
          a = logical_xor_bool(left%array, right%array, status)
        end select
      end select
    end select
    call publish(slot, out, status)
    code = status%code
  end function binary
  integer(c_int32_t) function cast(source, dtype, casting, output) &
      bind(C, name="frumpy_cast") result(code)
    integer(c_int64_t), value :: source
    integer(c_int32_t), value :: dtype, casting
    type(c_ptr), value :: output
    integer(c_int64_t), pointer :: out
    type(handle_slot), pointer :: input, slot
    type(frumpy_status) :: status

    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    input => lookup(source, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    call new_array_slot(dtype, slot, status)
    code = status%code
    if (status%is_failure()) return
    call astype(input%array, slot%array, casting, status)
    call publish(slot, out, status)
    code = status%code
  end function cast

  integer(c_int32_t) function unary(operation, source, output) &
      bind(C, name="frumpy_unary") result(code)
    integer(c_int64_t), value :: source
    integer(c_int32_t), value :: operation
    type(c_ptr), value :: output
    integer(c_int64_t), pointer :: out
    type(handle_slot), pointer :: input, slot
    type(frumpy_status) :: status
    integer(int32) :: dtype

    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    input => lookup(source, 1_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR
    if (operation < 1 .or. operation > 8) return
    dtype = descriptor_dtype(input%array)
    if (operation == 8) dtype = 1_int32
    call new_array_slot(dtype, slot, status)
    code = status%code
    if (status%is_failure()) return
    call set_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR)
    select type (b => slot%array)
    type is (ndarray_bool)
      if (operation == 8) b = logical_not_bool(input%array, status)

    type is (ndarray_r32)
      select type (a => input%array)
      type is (ndarray_r32)
        select case (operation)
        case (1)
          b = negate_r32(a, status)
        case (2)
          b = abs_r32(a, status)
        case (3)
          b = sqrt_r32(a, status)
        case (4)
          b = exp_r32(a, status)
        case (5)
          b = log_r32(a, status)
        case (6)
          b = sin_r32(a, status)
        case (7)
          b = cos_r32(a, status)
        end select
      end select
    type is (ndarray_r64)
      select type (a => input%array)
      type is (ndarray_r64)
        select case (operation)
        case (1)
          b = negate_r64(a, status)
        case (2)
          b = abs_r64(a, status)
        case (3)
          b = sqrt_r64(a, status)
        case (4)
          b = exp_r64(a, status)
        case (5)
          b = log_r64(a, status)
        case (6)
          b = sin_r64(a, status)
        case (7)
          b = cos_r64(a, status)
        end select
      end select
    end select
    call publish(slot, out, status)
    code = status%code
  end function unary
end module frumpy_c_operations
