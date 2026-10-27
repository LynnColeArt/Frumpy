!> Explicit generator handles and versioned state at the C boundary.
module frumpy_c_random
  use iso_c_binding, only: c_ptr, c_int32_t, c_int64_t, c_associated, c_f_pointer
  use iso_fortran_env, only: int32, int64
  use frumpy_c_handles, only: handle_slot, lookup, new_rng_slot, new_array_slot, &
    publish, output_pointer, read_shape
  use frumpy_statuses, only: frumpy_status, FRUMPY_STATUS_INVALID_SHAPE
  use frumpy, only: ndarray_r64, uniform_r64, normal_r64
  implicit none
  private
contains
  integer(c_int32_t) function create(seed, output) bind(C, name="frumpy_rng_create") result(code)
    integer(c_int64_t), value :: seed
    type(c_ptr), value :: output
    integer(c_int64_t), pointer :: out
    type(handle_slot), pointer :: slot
    type(frumpy_status) :: status

    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    call new_rng_slot(slot, status)
    if (status%is_ok()) call slot%generator%seed(seed)
    call publish(slot, out, status)
    code = status%code
  end function create

  integer(c_int32_t) function get_state(generator, words, count) &
      bind(C, name="frumpy_rng_get_state") result(code)
    integer(c_int64_t), value :: generator
    integer(c_int32_t), value :: count
    type(c_ptr), value :: words
    integer(c_int64_t), pointer :: buffer(:)
    type(handle_slot), pointer :: slot
    type(frumpy_status) :: status

    slot => lookup(generator, 2_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_INVALID_SHAPE
    if (count /= 7 .or. .not. c_associated(words)) return
    call c_f_pointer(words, buffer, [count])
    buffer = slot%generator%get_state()
    code = 0_c_int32_t
  end function get_state

  integer(c_int32_t) function set_state(generator, words, count) &
      bind(C, name="frumpy_rng_set_state") result(code)
    integer(c_int64_t), value :: generator
    integer(c_int32_t), value :: count
    type(c_ptr), value :: words
    integer(c_int64_t), pointer :: buffer(:)
    type(handle_slot), pointer :: slot
    type(frumpy_status) :: status

    slot => lookup(generator, 2_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_INVALID_SHAPE
    if (count /= 7 .or. .not. c_associated(words)) return
    call c_f_pointer(words, buffer, [count])
    call slot%generator%set_state(buffer, status)
    code = status%code
  end function set_state

  integer(c_int32_t) function fill(generator, normal, rank, shape, output) &
      bind(C, name="frumpy_rng_fill") result(code)
    integer(c_int64_t), value :: generator
    integer(c_int32_t), value :: normal, rank
    type(c_ptr), value :: shape, output
    integer(c_int64_t), pointer :: out
    integer(int64), allocatable :: dims(:)
    type(handle_slot), pointer :: rng, slot
    type(frumpy_status) :: status

    call output_pointer(output, out, status)
    code = status%code
    if (status%is_failure()) return
    rng => lookup(generator, 2_int32, status)
    code = status%code
    if (status%is_failure()) return
    code = FRUMPY_STATUS_INVALID_SHAPE
    if (normal < 0 .or. normal > 1) return
    call read_shape(shape, rank, dims, status)
    code = status%code
    if (status%is_failure()) return
    ! Allocate the handle before consuming state; publishing cannot allocate.
    call new_array_slot(5_int32, slot, status)
    code = status%code
    if (status%is_failure()) return
    select type (a => slot%array)
    type is (ndarray_r64)
      if (normal == 1) then
        a = normal_r64(rng%generator, dims, status)
      else
        a = uniform_r64(rng%generator, dims, status)
      end if
    end select
    call publish(slot, out, status)
    code = status%code
  end function fill
end module frumpy_c_random
