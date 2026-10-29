!> Float64 sequence constructors with finite arange and byte-count guards.
module frumpy_c_sequences
  use iso_c_binding, only: c_ptr, c_int32_t, c_int64_t, c_double
  use iso_fortran_env, only: int32, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use frumpy_c_handles, only: handle_slot, new_array_slot, publish, output_pointer
  use frumpy_statuses, only: frumpy_status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    FRUMPY_STATUS_OVERFLOW, FRUMPY_STATUS_INVALID_SHAPE
  use frumpy, only: ndarray_r64, arange_r64, linspace_r64
  implicit none
  private
contains
  integer(c_int32_t) function arange(start, stop, step, output) &
      bind(C, name="frumpy_arange") result(code)
    real(c_double), value :: start, stop, step
    type(c_ptr), value :: output
    integer(c_int64_t), pointer :: out
    type(handle_slot), pointer :: slot
    type(frumpy_status) :: status
    real(c_double) :: count

    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR
    if (.not. ieee_is_finite(start) .or. .not. ieee_is_finite(stop) .or. &
        .not. ieee_is_finite(step)) return
    if (abs(step) <= tiny(step)) return
    count = (stop - start) / step
    code = FRUMPY_STATUS_OVERFLOW
    if (.not. ieee_is_finite(count)) return
    if (count >= real(shiftr(huge(1_int64),3),c_double)) return
    call new_array_slot(5_int32, slot, status)
    code = status%code
    if (status%is_failure()) return
    select type (a => slot%array)
    type is (ndarray_r64)
      a = arange_r64(start, stop, step, status)
    end select
    call publish(slot, out, status)
    code = status%code
  end function arange

  integer(c_int32_t) function linspace(start, stop, count, endpoint, output) &
      bind(C, name="frumpy_linspace") result(code)
    real(c_double), value :: start, stop
    integer(c_int64_t), value :: count
    integer(c_int32_t), value :: endpoint
    type(c_ptr), value :: output
    integer(c_int64_t), pointer :: out
    type(handle_slot), pointer :: slot
    type(frumpy_status) :: status

    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_INVALID_SHAPE
    if (count < 0 .or. endpoint < 0 .or. endpoint > 1) return
    code = FRUMPY_STATUS_OVERFLOW
    if (count > shiftr(huge(count),3)) return
    call new_array_slot(5_int32, slot, status)
    code = status%code
    if (status%is_failure()) return
    select type (a => slot%array)
    type is (ndarray_r64)
      a = linspace_r64(start, stop, count, endpoint == 1, status)
    end select
    call publish(slot, out, status)
    code = status%code
  end function linspace
end module frumpy_c_sequences
