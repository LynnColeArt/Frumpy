!> Explicit xoshiro256** 1.0 state, SplitMix64 seeds, and Box-Muller normal pairs.
!> Algorithms by Blackman/Vigna (public domain); see docs/RANDOM.md for references.
module frumpy_random
  use iso_fortran_env, only: int32, int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use frumpy_integer_scalars, only: wrapped_add_i64, wrapped_multiply_i64
  use frumpy_ndarray_r64, only: ndarray_r64, owned_descriptor_r64
  use frumpy_shape, only: element_count
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OVERFLOW
  implicit none
  private
  public :: random_generator, uniform_r64, normal_r64

  type :: random_generator
    private
    integer(int64) :: words(4) = [int(z'E220A8397B1DCDAF', int64), &
      int(z'6E789E6AA1B965F4', int64), int(z'06C45D188009454F', int64), &
      int(z'F88BB8A8724C81EC', int64)]
    logical :: has_spare = .false.
    real(real64) :: spare = 0.0_real64
  contains
    procedure :: seed => seed_generator
    procedure :: get_state
    procedure :: set_state
  end type random_generator
contains
  subroutine seed_generator(generator, seed)
    class(random_generator), intent(inout) :: generator
    integer(int64), intent(in) :: seed
    integer(int64) :: state, value
    integer(int32) :: i

    state = seed
    do i = 1_int32, 4_int32
      state = wrapped_add_i64(state, int(z'9E3779B97F4A7C15', int64))
      value = wrapped_multiply_i64(ieor(state, shiftr(state, 30)), int(z'BF58476D1CE4E5B9', int64))
      value = wrapped_multiply_i64(ieor(value, shiftr(value, 27)), int(z'94D049BB133111EB', int64))
      generator%words(i) = ieor(value, shiftr(value, 31))
    end do
    generator%has_spare = .false.
    generator%spare = 0.0_real64
  end subroutine seed_generator

  function get_state(generator) result(state)
    class(random_generator), intent(in) :: generator
    integer(int64) :: state(7)

    state = [1_int64, generator%words, 0_int64, 0_int64]
    if (generator%has_spare) then
      state(6) = 1_int64
      state(7) = transfer(generator%spare, 0_int64)
    end if
  end function get_state

  !> Rejected state leaves the generator unchanged, even when status is omitted.
  subroutine set_state(generator, state, status)
    class(random_generator), intent(inout) :: generator
    integer(int64), intent(in) :: state(:)
    type(frumpy_status), intent(out), optional :: status
    real(real64) :: spare

    if (present(status)) &
      call set_status(status, FRUMPY_STATUS_INVALID_SHAPE, "invalid random state")
    if (size(state) /= 7) return
    if (state(1) /= 1_int64 .or. all(state(2:5) == 0_int64)) return
    if (state(6) /= 0_int64 .and. state(6) /= 1_int64) return
    if (state(6) == 0_int64 .and. state(7) /= 0_int64) return
    spare = transfer(state(7), 0.0_real64)
    if (.not. ieee_is_finite(spare)) return
    generator%words = state(2:5)
    generator%has_spare = state(6) == 1_int64
    generator%spare = spare
    if (present(status)) call set_status(status, FRUMPY_STATUS_OK)
  end subroutine set_state

  function next_uniform(generator) result(value)
    type(random_generator), intent(inout) :: generator
    real(real64) :: value
    integer(int64) :: word, shifted

    word = wrapped_multiply_i64(generator%words(2), 5_int64)
    word = ior(shiftl(word, 7), shiftr(word, 57))
    word = wrapped_multiply_i64(word, 9_int64)
    value = real(shiftr(word, 11), real64) * 2.0_real64**(-53)
    shifted = shiftl(generator%words(2), 17)
    generator%words(3) = ieor(generator%words(3), generator%words(1))
    generator%words(4) = ieor(generator%words(4), generator%words(2))
    generator%words(2) = ieor(generator%words(2), generator%words(3))
    generator%words(1) = ieor(generator%words(1), generator%words(4))
    generator%words(3) = ieor(generator%words(3), shifted)
    generator%words(4) = ior(shiftl(generator%words(4), 45), shiftr(generator%words(4), 19))
  end function next_uniform

  function uniform_r64(generator, shape, status) result(array)
    type(random_generator), intent(inout) :: generator
    integer(int64), intent(in) :: shape(:)
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(frumpy_status) :: local_status
    integer(int64) :: i

    array = random_output(shape, local_status)
    if (present(status)) status = local_status
    if (local_status%is_failure()) return
    do i = 1_int64, array%size()
      array%data(i) = next_uniform(generator)
    end do
  end function uniform_r64

  function normal_r64(generator, shape, status) result(array)
    type(random_generator), intent(inout) :: generator
    integer(int64), intent(in) :: shape(:)
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(frumpy_status) :: local_status
    integer(int64) :: i
    real(real64) :: radius, angle, uniform
    real(real64), parameter :: TWO_PI = 6.283185307179586476925286766559_real64

    array = random_output(shape, local_status)
    if (present(status)) status = local_status
    if (local_status%is_failure()) return
    do i = 1_int64, array%size()
      if (generator%has_spare) then
        array%data(i) = generator%spare
        generator%has_spare = .false.
        generator%spare = 0.0_real64
      else
        uniform = next_uniform(generator)
        radius = sqrt(-2.0_real64 * log(1.0_real64 - uniform))
        angle = TWO_PI * next_uniform(generator)
        array%data(i) = radius * cos(angle)
        generator%spare = radius * sin(angle)
        generator%has_spare = .true.
      end if
    end do
  end function normal_r64

  function random_output(shape, status) result(array)
    integer(int64), intent(in) :: shape(:)
    type(frumpy_status), intent(out) :: status
    type(ndarray_r64) :: array
    integer(int64) :: count

    count = element_count(shape, status)
    if (status%is_ok()) then
      if (count > shiftr(huge(1_int64), 3)) &
        call set_status(status, FRUMPY_STATUS_OVERFLOW, "random result bytes overflow")
    end if
    if (status%is_failure()) return
    array = owned_descriptor_r64(shape, status=status)
  end function random_output
end module frumpy_random
