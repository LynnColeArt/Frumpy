program test_release_edges
  use iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use frumpy, only: ndarray_r64, ndarray_r32, ndarray_i32, ndarray_i64, frumpy_status, &
    owned_descriptor_r64, owned_descriptor_r32, owned_descriptor_i32, owned_descriptor_i64, &
    arange_r64, asarray_r64, copy_r64, FRUMPY_STATUS_OVERFLOW, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    FRUMPY_STATUS_UNSUPPORTED_DTYPE, FRUMPY_STATUS_INVALID_SHAPE
  implicit none
  type(ndarray_r64) :: a, b
  type(ndarray_r32) :: small_real
  type(ndarray_i32) :: small_int
  type(ndarray_i64) :: large_int
  type(frumpy_status) :: status
  integer(int64) :: count

  count = shiftr(huge(count), 3) + 1_int64
  a = owned_descriptor_r64([count], status=status)
  if (status%code /= FRUMPY_STATUS_OVERFLOW .or. a%has_storage()) error stop 'r64 byte overflow'
  large_int = owned_descriptor_i64([count], status=status)
  if (status%code /= FRUMPY_STATUS_OVERFLOW .or. large_int%has_storage()) &
    error stop 'i64 byte overflow'
  count = shiftr(huge(count), 2) + 1_int64
  small_real = owned_descriptor_r32([count], status=status)
  if (status%code /= FRUMPY_STATUS_OVERFLOW .or. small_real%has_storage()) &
    error stop 'r32 byte overflow'
  small_int = owned_descriptor_i32([count], status=status)
  if (status%code /= FRUMPY_STATUS_OVERFLOW .or. small_int%has_storage()) &
    error stop 'i32 byte overflow'
  a = arange_r64(ieee_value(0.0_real64, ieee_quiet_nan), 1.0_real64, status=status)
  if (status%code /= FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR .or. a%has_storage()) &
    error stop 'arange nonfinite'
  a = arange_r64(0.0_real64, real(huge(count),real64), status=status)
  if (status%code /= FRUMPY_STATUS_OVERFLOW .or. a%has_storage()) error stop 'arange count bound'
  a = asarray_r64([1.0_real64,2.0_real64], status=status)
  a%dtype_id = 4
  b = copy_r64(a, status=status)
  if (status%code /= FRUMPY_STATUS_UNSUPPORTED_DTYPE .or. b%has_storage()) &
    error stop 'copy malformed dtype'
  a%dtype_id = 5
  a%strides(1) = huge(count)
  b = copy_r64(a, status=status)
  if (status%code /= FRUMPY_STATUS_INVALID_SHAPE .or. b%has_storage()) &
    error stop 'copy malformed strides'
  call a%release()
  call b%release()
end program test_release_edges
