!> Table-driven dtype promotion policy for registered Frumpy dtypes.
module frumpy_promotion
  use iso_fortran_env, only: int32
  use frumpy_constants, only: FRUMPY_STATUS_MESSAGE_LEN
  use frumpy_dtypes, only: FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_I32, &
    FRUMPY_DTYPE_I64, FRUMPY_DTYPE_R32, FRUMPY_DTYPE_R64, &
    FRUMPY_DTYPE_UNSUPPORTED, dtype_name
  use frumpy_statuses, only: FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_UNSUPPORTED_DTYPE, frumpy_status, set_status

  implicit none

  private

  public :: promote_dtypes
  public :: promote_scalar_dtype
  public :: is_supported_promotion

  type :: frumpy_promotion_rule
    integer(int32) :: lhs_dtype_id = FRUMPY_DTYPE_UNSUPPORTED
    integer(int32) :: rhs_dtype_id = FRUMPY_DTYPE_UNSUPPORTED
    integer(int32) :: result_dtype_id = FRUMPY_DTYPE_UNSUPPORTED
  end type frumpy_promotion_rule

  integer(int32), parameter :: PROMOTION_RULE_COUNT = 15_int32

  type(frumpy_promotion_rule), parameter :: PROMOTION_RULES( &
    PROMOTION_RULE_COUNT) = [ &
    frumpy_promotion_rule(FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_BOOL, &
      FRUMPY_DTYPE_BOOL), &
    frumpy_promotion_rule(FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_I32, &
      FRUMPY_DTYPE_I32), &
    frumpy_promotion_rule(FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_I64, &
      FRUMPY_DTYPE_I64), &
    frumpy_promotion_rule(FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_R32, &
      FRUMPY_DTYPE_R32), &
    frumpy_promotion_rule(FRUMPY_DTYPE_BOOL, FRUMPY_DTYPE_R64, &
      FRUMPY_DTYPE_R64), &
    frumpy_promotion_rule(FRUMPY_DTYPE_I32, FRUMPY_DTYPE_I32, &
      FRUMPY_DTYPE_I32), &
    frumpy_promotion_rule(FRUMPY_DTYPE_I32, FRUMPY_DTYPE_I64, &
      FRUMPY_DTYPE_I64), &
    frumpy_promotion_rule(FRUMPY_DTYPE_I32, FRUMPY_DTYPE_R32, &
      FRUMPY_DTYPE_R64), &
    frumpy_promotion_rule(FRUMPY_DTYPE_I32, FRUMPY_DTYPE_R64, &
      FRUMPY_DTYPE_R64), &
    frumpy_promotion_rule(FRUMPY_DTYPE_I64, FRUMPY_DTYPE_I64, &
      FRUMPY_DTYPE_I64), &
    frumpy_promotion_rule(FRUMPY_DTYPE_I64, FRUMPY_DTYPE_R32, &
      FRUMPY_DTYPE_R64), &
    frumpy_promotion_rule(FRUMPY_DTYPE_I64, FRUMPY_DTYPE_R64, &
      FRUMPY_DTYPE_R64), &
    frumpy_promotion_rule(FRUMPY_DTYPE_R32, FRUMPY_DTYPE_R32, &
      FRUMPY_DTYPE_R32), &
    frumpy_promotion_rule(FRUMPY_DTYPE_R32, FRUMPY_DTYPE_R64, &
      FRUMPY_DTYPE_R64), &
    frumpy_promotion_rule(FRUMPY_DTYPE_R64, FRUMPY_DTYPE_R64, &
      FRUMPY_DTYPE_R64) &
  ]

contains

  function promote_dtypes(lhs_dtype_id, rhs_dtype_id, status) &
      result(result_dtype_id)
    integer(int32), intent(in) :: lhs_dtype_id
    integer(int32), intent(in) :: rhs_dtype_id
    type(frumpy_status), intent(out), optional :: status
    integer(int32) :: result_dtype_id
    type(frumpy_promotion_rule) :: rule

    rule = find_promotion_rule(lhs_dtype_id, rhs_dtype_id)
    result_dtype_id = rule%result_dtype_id

    if (result_dtype_id /= FRUMPY_DTYPE_UNSUPPORTED) then
      call set_optional_status(status, FRUMPY_STATUS_OK)
    else
      call set_optional_status(status, FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
        promotion_status_message(lhs_dtype_id, rhs_dtype_id))
    end if
  end function promote_dtypes

  function promote_scalar_dtype(array_dtype_id, scalar_dtype_id, status) &
      result(result_dtype_id)
    integer(int32), intent(in) :: array_dtype_id
    integer(int32), intent(in) :: scalar_dtype_id
    type(frumpy_status), intent(out), optional :: status
    integer(int32) :: result_dtype_id

    result_dtype_id = promote_dtypes(array_dtype_id, scalar_dtype_id, status)
  end function promote_scalar_dtype

  logical function is_supported_promotion(lhs_dtype_id, rhs_dtype_id)
    integer(int32), intent(in) :: lhs_dtype_id
    integer(int32), intent(in) :: rhs_dtype_id
    type(frumpy_promotion_rule) :: rule

    rule = find_promotion_rule(lhs_dtype_id, rhs_dtype_id)
    is_supported_promotion = rule%result_dtype_id /= FRUMPY_DTYPE_UNSUPPORTED
  end function is_supported_promotion

  function find_promotion_rule(lhs_dtype_id, rhs_dtype_id) result(rule)
    integer(int32), intent(in) :: lhs_dtype_id
    integer(int32), intent(in) :: rhs_dtype_id
    type(frumpy_promotion_rule) :: rule
    integer(int32) :: lhs_key
    integer(int32) :: rhs_key
    integer :: candidate

    call canonical_promotion_pair(lhs_dtype_id, rhs_dtype_id, &
      lhs_key, rhs_key)
    rule = frumpy_promotion_rule()

    do candidate = 1, size(PROMOTION_RULES)
      if (PROMOTION_RULES(candidate)%lhs_dtype_id == lhs_key .and. &
          PROMOTION_RULES(candidate)%rhs_dtype_id == rhs_key) then
        rule = PROMOTION_RULES(candidate)
        return
      end if
    end do
  end function find_promotion_rule

  subroutine canonical_promotion_pair(lhs_dtype_id, rhs_dtype_id, &
      lhs_key, rhs_key)
    integer(int32), intent(in) :: lhs_dtype_id
    integer(int32), intent(in) :: rhs_dtype_id
    integer(int32), intent(out) :: lhs_key
    integer(int32), intent(out) :: rhs_key

    if (lhs_dtype_id <= rhs_dtype_id) then
      lhs_key = lhs_dtype_id
      rhs_key = rhs_dtype_id
    else
      lhs_key = rhs_dtype_id
      rhs_key = lhs_dtype_id
    end if
  end subroutine canonical_promotion_pair

  function promotion_status_message(lhs_dtype_id, rhs_dtype_id) result(message)
    integer(int32), intent(in) :: lhs_dtype_id
    integer(int32), intent(in) :: rhs_dtype_id
    character(len=FRUMPY_STATUS_MESSAGE_LEN) :: message

    message = "unsupported dtype promotion pair: " // &
      trim(dtype_name(lhs_dtype_id)) // " and " // trim(dtype_name(rhs_dtype_id))
  end function promotion_status_message

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
end module frumpy_promotion
