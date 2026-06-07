!> Project-wide constants shared by Frumpy core modules.
module frumpy_constants
  use iso_fortran_env, only: int32, int64

  implicit none

  private

  public :: FRUMPY_MAX_RANK
  public :: FRUMPY_ORDER_C
  public :: FRUMPY_ORDER_F
  public :: FRUMPY_ORDER_A
  public :: FRUMPY_ORDER_K
  public :: FRUMPY_DTYPE_NAME_LEN
  public :: FRUMPY_STATUS_MESSAGE_LEN
  public :: FRUMPY_BYTE_SIZE_BOOL
  public :: FRUMPY_BYTE_SIZE_I32
  public :: FRUMPY_BYTE_SIZE_I64
  public :: FRUMPY_BYTE_SIZE_R32
  public :: FRUMPY_BYTE_SIZE_R64

  integer(int32), parameter :: FRUMPY_MAX_RANK = 32_int32

  integer(int32), parameter :: FRUMPY_ORDER_C = 0_int32
  integer(int32), parameter :: FRUMPY_ORDER_F = 1_int32
  integer(int32), parameter :: FRUMPY_ORDER_A = 2_int32
  integer(int32), parameter :: FRUMPY_ORDER_K = 3_int32

  integer(int32), parameter :: FRUMPY_DTYPE_NAME_LEN = 16_int32
  integer(int32), parameter :: FRUMPY_STATUS_MESSAGE_LEN = 160_int32

  integer(int64), parameter :: FRUMPY_BYTE_SIZE_BOOL = 1_int64
  integer(int64), parameter :: FRUMPY_BYTE_SIZE_I32 = 4_int64
  integer(int64), parameter :: FRUMPY_BYTE_SIZE_I64 = 8_int64
  integer(int64), parameter :: FRUMPY_BYTE_SIZE_R32 = 4_int64
  integer(int64), parameter :: FRUMPY_BYTE_SIZE_R64 = 8_int64
end module frumpy_constants
