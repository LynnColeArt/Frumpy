!> Array astype uses dtype policy, with transactional output and explicit unsafe conversion rules.
module frumpy_array_casting
  use iso_fortran_env, only: int8, int32, int64, real32, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use frumpy_operands, only: operand, bind_operand, descriptor_dtype, integer_value, &
    real32_value, real64_value, boolean_value
  use frumpy_dtypes, only: FRUMPY_DTYPE_I64, dtype_byte_size
  use frumpy_casting, only: require_cast_dtype, FRUMPY_CASTING_UNSAFE
  use frumpy_integer_scalars, only: wrap_i32
  use frumpy_shape, only: element_count
  use frumpy_strides, only: flat_offset
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_OVERFLOW, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR
  use frumpy_ndarray_bool, only: ndarray_bool, owned_descriptor_bool
  use frumpy_ndarray_i32, only: ndarray_i32, owned_descriptor_i32
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64
  use frumpy_ndarray_r32, only: ndarray_r32, owned_descriptor_r32
  use frumpy_ndarray_r64, only: ndarray_r64, owned_descriptor_r64
  implicit none
  private
  public :: astype
contains
  !> Destination's concrete type selects dtype; all reported failures preserve its previous value.
  subroutine astype(source, result, casting, status)
    class(*), target, intent(in) :: source
    class(*), intent(inout) :: result
    integer(int32), intent(in), optional :: casting
    type(frumpy_status), intent(out), optional :: status
    type(operand) :: borrowed
    type(frumpy_status) :: local_status
    integer(int32) :: mode, target_dtype
    integer(int64) :: count, bytes, i0, position, integral

    mode = FRUMPY_CASTING_UNSAFE
    if (present(casting)) mode = casting
    call bind_operand(source, borrowed, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    target_dtype = descriptor_dtype(result)
    if (.not. require_cast_dtype(borrowed%dtype_id, target_dtype, mode, local_status)) then
      if (present(status)) status = local_status
      return
    end if
    count = element_count(borrowed%shape)
    bytes = dtype_byte_size(target_dtype)
    if (count > huge(1_int64) / bytes) then
      call set_status(local_status, FRUMPY_STATUS_OVERFLOW, "astype output bytes overflow")
      if (present(status)) status = local_status
      return
    end if
    select type (result)
    type is (ndarray_bool)
      block
        type(ndarray_bool) :: staged

        staged = owned_descriptor_bool(borrowed%shape, status=local_status)
        if (local_status%is_ok()) then
          do i0 = 0_int64, count - 1_int64
            position = flat_offset(borrowed%shape, borrowed%strides, borrowed%offset, i0)
            staged%data(i0 + 1_int64) = merge(1_int8, 0_int8, boolean_value(borrowed, position))
          end do
          if (local_status%is_ok()) call result%share_from(staged, local_status)
        end if
      end block
    type is (ndarray_i32)
      block
        type(ndarray_i32) :: staged

        staged = owned_descriptor_i32(borrowed%shape, status=local_status)
        if (local_status%is_ok()) then
          do i0 = 0_int64, count - 1_int64
            position = flat_offset(borrowed%shape, borrowed%strides, borrowed%offset, i0)
            integral = cast_integer(borrowed, position, 32_int32, local_status)
            if (local_status%is_failure()) exit
            staged%data(i0 + 1_int64) = wrap_i32(integral)
          end do
          if (local_status%is_ok()) call result%share_from(staged, local_status)
        end if
      end block
    type is (ndarray_i64)
      block
        type(ndarray_i64) :: staged

        staged = owned_descriptor_i64(borrowed%shape, status=local_status)
        if (local_status%is_ok()) then
          do i0 = 0_int64, count - 1_int64
            position = flat_offset(borrowed%shape, borrowed%strides, borrowed%offset, i0)
            integral = cast_integer(borrowed, position, 64_int32, local_status)
            if (local_status%is_failure()) exit
            staged%data(i0 + 1_int64) = integral
          end do
          if (local_status%is_ok()) call result%share_from(staged, local_status)
        end if
      end block
    type is (ndarray_r32)
      block
        type(ndarray_r32) :: staged

        staged = owned_descriptor_r32(borrowed%shape, status=local_status)
        if (local_status%is_ok()) then
          do i0 = 0_int64, count - 1_int64
            position = flat_offset(borrowed%shape, borrowed%strides, borrowed%offset, i0)
            staged%data(i0 + 1_int64) = real32_value(borrowed, position)
          end do
          if (local_status%is_ok()) call result%share_from(staged, local_status)
        end if
      end block
    type is (ndarray_r64)
      block
        type(ndarray_r64) :: staged

        staged = owned_descriptor_r64(borrowed%shape, status=local_status)
        if (local_status%is_ok()) then
          do i0 = 0_int64, count - 1_int64
            position = flat_offset(borrowed%shape, borrowed%strides, borrowed%offset, i0)
            staged%data(i0 + 1_int64) = real64_value(borrowed, position)
          end do
          if (local_status%is_ok()) call result%share_from(staged, local_status)
        end if
      end block
    end select
    if (present(status)) status = local_status
  end subroutine astype

  integer(int64) function cast_integer(source, position, bits, status) result(value)
    type(operand), intent(in) :: source
    integer(int64), intent(in) :: position
    integer(int32), intent(in) :: bits
    type(frumpy_status), intent(inout) :: status
    real(real64) :: number, bound

    value = 0_int64
    if (source%dtype_id <= FRUMPY_DTYPE_I64) then
      value = integer_value(source, position)
      return
    end if
    number = real64_value(source, position)
    if (.not. ieee_is_finite(number)) then
      call set_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, "nonfinite float to integer cast")
      return
    end if
    number = aint(number)
    bound = 2.0_real64**(bits - 1_int32)
    if (number < -bound .or. number >= bound) then
      call set_status(status, FRUMPY_STATUS_OVERFLOW, "float to integer cast is out of range")
      return
    end if
    value = int(number, int64)
  end function cast_integer
end module frumpy_array_casting
