!> Explicit dtype casting policy and scalar conversion kernels.
module frumpy_casting
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use iso_fortran_env, only: int32, int64, real32, real64
  use frumpy_constants, only: FRUMPY_STATUS_MESSAGE_LEN
  use frumpy_dtypes, only: FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_I32, &
    FRUMPY_DTYPE_I64, FRUMPY_DTYPE_R32, FRUMPY_DTYPE_R64, dtype_name
  use frumpy_statuses, only: FRUMPY_STATUS_OK, FRUMPY_STATUS_OVERFLOW, &
    FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
    frumpy_status, set_status

  implicit none

  private

  public :: FRUMPY_CASTING_NO
  public :: FRUMPY_CASTING_EQUIV
  public :: FRUMPY_CASTING_SAFE
  public :: FRUMPY_CASTING_SAME_KIND
  public :: FRUMPY_CASTING_UNSAFE
  public :: can_cast_dtype
  public :: require_cast_dtype
  public :: copy_r64_value
  public :: cast_bool_to_i32
  public :: cast_i32_to_i64
  public :: cast_i32_to_r64
  public :: cast_i64_to_r64
  public :: cast_r32_to_r64
  public :: cast_i64_to_i32
  public :: cast_r64_to_i32
  public :: cast_r64_to_r32

  integer(int32), parameter :: FRUMPY_CASTING_NO = 0_int32
  integer(int32), parameter :: FRUMPY_CASTING_EQUIV = 1_int32
  integer(int32), parameter :: FRUMPY_CASTING_SAFE = 2_int32
  integer(int32), parameter :: FRUMPY_CASTING_SAME_KIND = 3_int32
  integer(int32), parameter :: FRUMPY_CASTING_UNSAFE = 4_int32
  integer(int64), parameter :: MAX_EXACT_I64_IN_R64 = &
    9007199254740992_int64

contains

  logical function can_cast_dtype(source_dtype_id, target_dtype_id, casting)
    integer(int32), intent(in) :: source_dtype_id
    integer(int32), intent(in) :: target_dtype_id
    integer(int32), intent(in), optional :: casting
    integer(int32) :: resolved_casting

    resolved_casting = resolve_casting(casting)

    if (.not. is_registered_dtype(source_dtype_id) .or. &
        .not. is_registered_dtype(target_dtype_id)) then
      can_cast_dtype = .false.
      return
    end if

    select case (resolved_casting)
    case (FRUMPY_CASTING_NO, FRUMPY_CASTING_EQUIV)
      can_cast_dtype = source_dtype_id == target_dtype_id
    case (FRUMPY_CASTING_SAFE)
      can_cast_dtype = can_cast_safe(source_dtype_id, target_dtype_id)
    case (FRUMPY_CASTING_SAME_KIND)
      can_cast_dtype = can_cast_same_kind(source_dtype_id, target_dtype_id)
    case (FRUMPY_CASTING_UNSAFE)
      can_cast_dtype = .true.
    case default
      can_cast_dtype = .false.
    end select
  end function can_cast_dtype

  logical function require_cast_dtype(source_dtype_id, target_dtype_id, &
      casting, status)
    integer(int32), intent(in) :: source_dtype_id
    integer(int32), intent(in) :: target_dtype_id
    integer(int32), intent(in), optional :: casting
    type(frumpy_status), intent(out), optional :: status
    integer(int32) :: resolved_casting

    resolved_casting = resolve_casting(casting)
    require_cast_dtype = can_cast_dtype(source_dtype_id, target_dtype_id, &
      resolved_casting)

    if (require_cast_dtype) then
      call set_optional_status(status, FRUMPY_STATUS_OK)
    else if (.not. is_registered_dtype(source_dtype_id) .or. &
        .not. is_registered_dtype(target_dtype_id)) then
      call set_optional_status(status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
        cast_status_message("unsupported dtype cast", source_dtype_id, &
        target_dtype_id))
    else
      call set_optional_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        cast_status_message("cast is not allowed by casting policy", &
        source_dtype_id, target_dtype_id))
    end if
  end function require_cast_dtype

  function copy_r64_value(value, status) result(copied_value)
    real(real64), intent(in) :: value
    type(frumpy_status), intent(out), optional :: status
    real(real64) :: copied_value

    copied_value = value
    call set_optional_status(status, FRUMPY_STATUS_OK)
  end function copy_r64_value

  function cast_bool_to_i32(value, status) result(cast_value)
    logical, intent(in) :: value
    type(frumpy_status), intent(out), optional :: status
    integer(int32) :: cast_value

    if (value) then
      cast_value = 1_int32
    else
      cast_value = 0_int32
    end if
    call set_optional_status(status, FRUMPY_STATUS_OK)
  end function cast_bool_to_i32

  function cast_i32_to_i64(value, status) result(cast_value)
    integer(int32), intent(in) :: value
    type(frumpy_status), intent(out), optional :: status
    integer(int64) :: cast_value

    cast_value = int(value, int64)
    call set_optional_status(status, FRUMPY_STATUS_OK)
  end function cast_i32_to_i64

  function cast_i32_to_r64(value, status) result(cast_value)
    integer(int32), intent(in) :: value
    type(frumpy_status), intent(out), optional :: status
    real(real64) :: cast_value

    cast_value = real(value, real64)
    call set_optional_status(status, FRUMPY_STATUS_OK)
  end function cast_i32_to_r64

  function cast_i64_to_r64(value, status) result(cast_value)
    integer(int64), intent(in) :: value
    type(frumpy_status), intent(out), optional :: status
    real(real64) :: cast_value

    cast_value = 0.0_real64

    if (value < -MAX_EXACT_I64_IN_R64 .or. &
        value > MAX_EXACT_I64_IN_R64) then
      call set_optional_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "i64 to r64 cast would lose integer precision")
      return
    end if

    cast_value = real(value, real64)
    call set_optional_status(status, FRUMPY_STATUS_OK)
  end function cast_i64_to_r64

  function cast_r32_to_r64(value, status) result(cast_value)
    real(real32), intent(in) :: value
    type(frumpy_status), intent(out), optional :: status
    real(real64) :: cast_value

    cast_value = real(value, real64)
    call set_optional_status(status, FRUMPY_STATUS_OK)
  end function cast_r32_to_r64

  function cast_i64_to_i32(value, casting, status) result(cast_value)
    integer(int64), intent(in) :: value
    integer(int32), intent(in), optional :: casting
    type(frumpy_status), intent(out), optional :: status
    integer(int32) :: cast_value

    cast_value = 0_int32

    if (.not. require_cast_dtype(FRUMPY_DTYPE_I64, FRUMPY_DTYPE_I32, &
        casting, status)) return

    if (value < -int(huge(0_int32), int64) - 1_int64 .or. &
        value > int(huge(0_int32), int64)) then
      call set_optional_status(status, FRUMPY_STATUS_OVERFLOW, &
        "i64 to i32 cast overflows target range")
      return
    end if

    cast_value = int(value, int32)
    call set_optional_status(status, FRUMPY_STATUS_OK)
  end function cast_i64_to_i32

  function cast_r64_to_i32(value, casting, status) result(cast_value)
    real(real64), intent(in) :: value
    integer(int32), intent(in), optional :: casting
    type(frumpy_status), intent(out), optional :: status
    integer(int32) :: cast_value
    real(real64) :: lower_bound
    real(real64) :: upper_bound

    cast_value = 0_int32

    if (.not. require_cast_dtype(FRUMPY_DTYPE_R64, FRUMPY_DTYPE_I32, &
        casting, status)) return

    if (.not. value_is_finite(value)) then
      call set_optional_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "r64 to i32 cast requires finite value")
      return
    end if

    lower_bound = -real(huge(0_int32), real64) - 1.0_real64
    upper_bound = real(huge(0_int32), real64)

    if (value < lower_bound .or. value > upper_bound) then
      call set_optional_status(status, FRUMPY_STATUS_OVERFLOW, &
        "r64 to i32 cast overflows target range")
      return
    end if

    cast_value = int(value, int32)
    if (abs(real(cast_value, real64) - value) > 0.0_real64) then
      cast_value = 0_int32
      call set_optional_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "r64 to i32 cast would lose fractional precision")
      return
    end if

    call set_optional_status(status, FRUMPY_STATUS_OK)
  end function cast_r64_to_i32

  function cast_r64_to_r32(value, casting, status) result(cast_value)
    real(real64), intent(in) :: value
    integer(int32), intent(in), optional :: casting
    type(frumpy_status), intent(out), optional :: status
    real(real32) :: cast_value
    integer(int32) :: resolved_casting

    cast_value = 0.0_real32
    resolved_casting = resolve_casting(casting)

    if (.not. require_cast_dtype(FRUMPY_DTYPE_R64, FRUMPY_DTYPE_R32, &
        resolved_casting, status)) return

    if (.not. value_is_finite(value)) then
      call set_optional_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "r64 to r32 cast requires finite value")
      return
    end if

    if (abs(value) > real(huge(0.0_real32), real64)) then
      call set_optional_status(status, FRUMPY_STATUS_OVERFLOW, &
        "r64 to r32 cast overflows target range")
      return
    end if

    cast_value = real(value, real32)

    if (abs(real(cast_value, real64) - value) > 0.0_real64) then
      cast_value = 0.0_real32
      call set_optional_status(status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
        "r64 to r32 cast would lose precision")
      return
    end if

    call set_optional_status(status, FRUMPY_STATUS_OK)
  end function cast_r64_to_r32

  integer(int32) function resolve_casting(casting) result(resolved_casting)
    integer(int32), intent(in), optional :: casting

    resolved_casting = FRUMPY_CASTING_SAFE
    if (present(casting)) resolved_casting = casting
  end function resolve_casting

  logical function is_registered_dtype(dtype_id)
    integer(int32), intent(in) :: dtype_id

    select case (dtype_id)
    case (FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_I32, FRUMPY_DTYPE_I64, &
        FRUMPY_DTYPE_R32, FRUMPY_DTYPE_R64)
      is_registered_dtype = .true.
    case default
      is_registered_dtype = .false.
    end select
  end function is_registered_dtype

  logical function can_cast_safe(source_dtype_id, target_dtype_id)
    integer(int32), intent(in) :: source_dtype_id
    integer(int32), intent(in) :: target_dtype_id

    select case (source_dtype_id)
    case (FRUMPY_DTYPE_BOOL)
      can_cast_safe = .true.
    case (FRUMPY_DTYPE_I32)
      can_cast_safe = target_dtype_id == FRUMPY_DTYPE_I32 .or. &
        target_dtype_id == FRUMPY_DTYPE_I64 .or. &
        target_dtype_id == FRUMPY_DTYPE_R64
    case (FRUMPY_DTYPE_I64)
      can_cast_safe = target_dtype_id == FRUMPY_DTYPE_I64 .or. &
        target_dtype_id == FRUMPY_DTYPE_R64
    case (FRUMPY_DTYPE_R32)
      can_cast_safe = target_dtype_id == FRUMPY_DTYPE_R32 .or. &
        target_dtype_id == FRUMPY_DTYPE_R64
    case (FRUMPY_DTYPE_R64)
      can_cast_safe = target_dtype_id == FRUMPY_DTYPE_R64
    case default
      can_cast_safe = .false.
    end select
  end function can_cast_safe

  logical function can_cast_same_kind(source_dtype_id, target_dtype_id)
    integer(int32), intent(in) :: source_dtype_id
    integer(int32), intent(in) :: target_dtype_id

    select case (source_dtype_id)
    case (FRUMPY_DTYPE_BOOL)
      can_cast_same_kind = .true.
    case (FRUMPY_DTYPE_I32, FRUMPY_DTYPE_I64)
      can_cast_same_kind = target_dtype_id == FRUMPY_DTYPE_I32 .or. &
        target_dtype_id == FRUMPY_DTYPE_I64 .or. &
        target_dtype_id == FRUMPY_DTYPE_R32 .or. &
        target_dtype_id == FRUMPY_DTYPE_R64
    case (FRUMPY_DTYPE_R32, FRUMPY_DTYPE_R64)
      can_cast_same_kind = target_dtype_id == FRUMPY_DTYPE_R32 .or. &
        target_dtype_id == FRUMPY_DTYPE_R64
    case default
      can_cast_same_kind = .false.
    end select
  end function can_cast_same_kind

  logical function value_is_finite(value)
    real(real64), intent(in) :: value

    value_is_finite = ieee_is_finite(value)
  end function value_is_finite

  function cast_status_message(prefix, source_dtype_id, target_dtype_id) &
      result(message)
    character(len=*), intent(in) :: prefix
    integer(int32), intent(in) :: source_dtype_id
    integer(int32), intent(in) :: target_dtype_id
    character(len=FRUMPY_STATUS_MESSAGE_LEN) :: message

    message = prefix // ": " // trim(dtype_name(source_dtype_id)) // &
      " to " // trim(dtype_name(target_dtype_id))
  end function cast_status_message

  subroutine set_optional_status(status, code, message)
    type(frumpy_status), intent(out), optional :: status
    integer(int32), intent(in) :: code
    character(len=*), intent(in), optional :: message

    if (.not. present(status)) return

    if (present(message)) then
      call set_status(status, code, message)
    else
      call set_status(status, code)
    end if
  end subroutine set_optional_status
end module frumpy_casting
