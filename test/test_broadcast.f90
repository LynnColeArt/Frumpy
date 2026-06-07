program test_broadcast
  use iso_fortran_env, only: int32, int64, real64
  use frumpy_broadcast, only: broadcast_plan, broadcast_plan_r64
  use frumpy_constructors_r64, only: asarray_r64, empty_r64
  use frumpy_constants, only: FRUMPY_ORDER_C, FRUMPY_ORDER_F
  use frumpy_ndarray_r64, only: ndarray_r64
  use frumpy_statuses, only: FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OK, &
    frumpy_status

  implicit none

  integer(int64) :: scalar_shape(0)

  call test_trailing_dimension_plan()
  call test_scalar_plan_uses_zero_strides()
  call test_zero_extent_plan_keeps_zero_shape()
  call test_fortran_order_strides_are_preserved()
  call test_incompatible_shapes_fail()

contains

  subroutine test_trailing_dimension_plan()
    type(frumpy_status) :: status
    type(ndarray_r64) :: lhs
    type(ndarray_r64) :: rhs
    type(broadcast_plan) :: plan

    lhs = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      status=status)
    call assert_status_ok(status, "lhs constructor")

    rhs = asarray_r64([10.0_real64, 20.0_real64, 30.0_real64], &
      [3_int64], status=status)
    call assert_status_ok(status, "rhs constructor")

    plan = broadcast_plan_r64(lhs, rhs, status)
    call assert_status_ok(status, "trailing broadcast status")
    call assert_equal_int32(plan%rank, 2_int32, "trailing rank")
    call assert_equal_int64_vector(plan%shape, [2_int64, 3_int64], &
      "trailing shape")
    call assert_equal_int64_vector(plan%lhs_strides, [3_int64, 1_int64], &
      "trailing lhs strides")
    call assert_equal_int64_vector(plan%rhs_strides, [0_int64, 1_int64], &
      "trailing rhs zero stride")
    call assert_equal_int64(plan%size(), 6_int64, "trailing size")
  end subroutine test_trailing_dimension_plan

  subroutine test_scalar_plan_uses_zero_strides()
    type(frumpy_status) :: status
    type(ndarray_r64) :: scalar
    type(ndarray_r64) :: vector
    type(broadcast_plan) :: plan

    scalar = asarray_r64([2.0_real64], scalar_shape, status=status)
    call assert_status_ok(status, "scalar constructor")

    vector = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64], &
      status=status)
    call assert_status_ok(status, "vector constructor")

    plan = broadcast_plan_r64(scalar, vector, status)
    call assert_status_ok(status, "scalar broadcast status")
    call assert_equal_int64_vector(plan%shape, [3_int64], &
      "scalar broadcast shape")
    call assert_equal_int64_vector(plan%lhs_strides, [0_int64], &
      "scalar lhs zero stride")
    call assert_equal_int64_vector(plan%rhs_strides, [1_int64], &
      "scalar rhs stride")
  end subroutine test_scalar_plan_uses_zero_strides

  subroutine test_zero_extent_plan_keeps_zero_shape()
    type(frumpy_status) :: status
    type(ndarray_r64) :: lhs
    type(ndarray_r64) :: rhs
    type(broadcast_plan) :: plan

    lhs = empty_r64([0_int64, 3_int64], status=status)
    call assert_status_ok(status, "zero extent lhs constructor")

    rhs = asarray_r64([10.0_real64, 20.0_real64, 30.0_real64], &
      [1_int64, 3_int64], status=status)
    call assert_status_ok(status, "zero extent rhs constructor")

    plan = broadcast_plan_r64(lhs, rhs, status)
    call assert_status_ok(status, "zero extent broadcast status")
    call assert_equal_int64_vector(plan%shape, [0_int64, 3_int64], &
      "zero extent broadcast shape")
    call assert_equal_int64_vector(plan%rhs_strides, [0_int64, 1_int64], &
      "zero extent singleton rhs stride")
    call assert_equal_int64(plan%size(), 0_int64, "zero extent size")
  end subroutine test_zero_extent_plan_keeps_zero_shape

  subroutine test_fortran_order_strides_are_preserved()
    type(frumpy_status) :: status
    type(ndarray_r64) :: lhs
    type(ndarray_r64) :: rhs
    type(broadcast_plan) :: plan

    lhs = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64, &
        4.0_real64, 5.0_real64, 6.0_real64], [2_int64, 3_int64], &
      FRUMPY_ORDER_F, status)
    call assert_status_ok(status, "Fortran lhs constructor")

    rhs = asarray_r64([10.0_real64, 20.0_real64], [2_int64, 1_int64], &
      FRUMPY_ORDER_C, status)
    call assert_status_ok(status, "broadcast column constructor")

    plan = broadcast_plan_r64(lhs, rhs, status)
    call assert_status_ok(status, "Fortran stride broadcast status")
    call assert_equal_int64_vector(plan%shape, [2_int64, 3_int64], &
      "Fortran stride broadcast shape")
    call assert_equal_int64_vector(plan%lhs_strides, [1_int64, 2_int64], &
      "Fortran lhs strides")
    call assert_equal_int64_vector(plan%rhs_strides, [1_int64, 0_int64], &
      "column rhs broadcast strides")
  end subroutine test_fortran_order_strides_are_preserved

  subroutine test_incompatible_shapes_fail()
    type(frumpy_status) :: status
    type(ndarray_r64) :: lhs
    type(ndarray_r64) :: rhs
    type(broadcast_plan) :: plan

    lhs = asarray_r64([1.0_real64, 2.0_real64], [2_int64], &
      status=status)
    call assert_status_ok(status, "incompatible lhs constructor")

    rhs = asarray_r64([1.0_real64, 2.0_real64, 3.0_real64], &
      [3_int64], status=status)
    call assert_status_ok(status, "incompatible rhs constructor")

    plan = broadcast_plan_r64(lhs, rhs, status)
    call assert_status_code(status, FRUMPY_STATUS_INVALID_SHAPE, &
      "incompatible broadcast status")
  end subroutine test_incompatible_shapes_fail

  subroutine assert_status_ok(status, message)
    type(frumpy_status), intent(in) :: status
    character(len=*), intent(in) :: message

    call assert_status_code(status, FRUMPY_STATUS_OK, message)
  end subroutine assert_status_ok

  subroutine assert_status_code(status, expected_code, message)
    type(frumpy_status), intent(in) :: status
    integer(int32), intent(in) :: expected_code
    character(len=*), intent(in) :: message

    if (status%code /= expected_code) then
      write (*, '(a,1x,i0,1x,a,1x,i0)') "FAIL:", status%code, &
        "/=", expected_code
      write (*, '(a)') message
      error stop 1
    end if
  end subroutine assert_status_code

  subroutine assert_equal_int32(actual, expected, message)
    integer(int32), intent(in) :: actual
    integer(int32), intent(in) :: expected
    character(len=*), intent(in) :: message

    if (actual /= expected) then
      write (*, '(a,1x,i0,1x,a,1x,i0)') "FAIL:", actual, "/=", expected
      write (*, '(a)') message
      error stop 1
    end if
  end subroutine assert_equal_int32

  subroutine assert_equal_int64(actual, expected, message)
    integer(int64), intent(in) :: actual
    integer(int64), intent(in) :: expected
    character(len=*), intent(in) :: message

    if (actual /= expected) then
      write (*, '(a,1x,i0,1x,a,1x,i0)') "FAIL:", actual, "/=", expected
      write (*, '(a)') message
      error stop 1
    end if
  end subroutine assert_equal_int64

  subroutine assert_equal_int64_vector(actual, expected, message)
    integer(int64), intent(in) :: actual(:)
    integer(int64), intent(in) :: expected(:)
    character(len=*), intent(in) :: message

    if (size(actual) /= size(expected)) then
      write (*, '(a)') "FAIL: " // message
      error stop 1
    end if

    if (any(actual /= expected)) then
      write (*, '(a)') "FAIL: " // message
      write (*, '(a,*(1x,i0))') "actual:", actual
      write (*, '(a,*(1x,i0))') "expected:", expected
      error stop 1
    end if
  end subroutine assert_equal_int64_vector
end program test_broadcast
