!> Project-wide constants shared by Fenum core modules.
module fenum_constants
  use iso_fortran_env, only: int32, int64

  implicit none

  private

  public :: FENUM_MAX_RANK
  public :: FENUM_ORDER_C
  public :: FENUM_ORDER_F
  public :: FENUM_ORDER_A
  public :: FENUM_ORDER_K
  public :: FENUM_DTYPE_NAME_LEN
  public :: FENUM_STATUS_MESSAGE_LEN
  public :: FENUM_BYTE_SIZE_BOOL
  public :: FENUM_BYTE_SIZE_I32
  public :: FENUM_BYTE_SIZE_I64
  public :: FENUM_BYTE_SIZE_R32
  public :: FENUM_BYTE_SIZE_R64

  integer(int32), parameter :: FENUM_MAX_RANK = 32_int32

  integer(int32), parameter :: FENUM_ORDER_C = 0_int32
  integer(int32), parameter :: FENUM_ORDER_F = 1_int32
  integer(int32), parameter :: FENUM_ORDER_A = 2_int32
  integer(int32), parameter :: FENUM_ORDER_K = 3_int32

  integer(int32), parameter :: FENUM_DTYPE_NAME_LEN = 16_int32
  integer(int32), parameter :: FENUM_STATUS_MESSAGE_LEN = 160_int32

  integer(int64), parameter :: FENUM_BYTE_SIZE_BOOL = 1_int64
  integer(int64), parameter :: FENUM_BYTE_SIZE_I32 = 4_int64
  integer(int64), parameter :: FENUM_BYTE_SIZE_I64 = 8_int64
  integer(int64), parameter :: FENUM_BYTE_SIZE_R32 = 4_int64
  integer(int64), parameter :: FENUM_BYTE_SIZE_R64 = 8_int64
end module fenum_constants
