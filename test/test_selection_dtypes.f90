!> Selection dtype, malformed-metadata, overflow and lifetime invariants.
program test_selection_dtypes
  use iso_fortran_env, only: int8, int32, int64, real32, real64
  use frumpy, only: where, take, concatenate, stack, frumpy_status, FRUMPY_ORDER_F
  use frumpy_ndarray_bool, only: ndarray_bool, owned_descriptor_bool, metadata_descriptor_bool
  use frumpy_ndarray_i32, only: ndarray_i32, owned_descriptor_i32, metadata_descriptor_i32
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64, metadata_descriptor_i64
  use frumpy_ndarray_r32, only: ndarray_r32, owned_descriptor_r32, metadata_descriptor_r32
  use frumpy_ndarray_r64, only: ndarray_r64, owned_descriptor_r64, metadata_descriptor_r64
  implicit none
  call test_bool()
  call test_i32()
  call test_i64()
  call test_r32()
  call test_r64()
contains
  subroutine test_bool()
    type(ndarray_bool) :: inputs(2), result, invalid, huge_input
    type(ndarray_bool) :: mask
    type(frumpy_status) :: status
    integer(int8), target :: external(1)
    integer(int64) :: rank_shape(32), no_indices(0)

    inputs(1) = owned_descriptor_bool([2_int64, 3_int64], FRUMPY_ORDER_F, status)
    call require(status%is_ok(), 'allocate source')
    inputs(1)%data = 1_int8
    call inputs(2)%share_from(inputs(1), status)
    mask = owned_descriptor_bool([2_int64, 1_int64], status=status)
    mask%data = [-7_int8, 0_int8]
    result = where(mask, inputs(1), inputs(2), status)
    call require(status%is_ok(), 'where same dtype')
    call require(all(result%data == 1_int8), 'where exact values')
    result = concatenate(inputs, -1_int32, status)
    call require(status%is_ok(), 'concatenate')
    call require(all(result%shape == [2_int64, 6_int64]), 'concatenate shape')
    call require(result%is_f_contiguous, 'concatenate F order')
    result = stack(inputs, -1_int32, status)
    call require(status%is_ok(), 'stack')
    call require(all(result%shape == [2_int64, 3_int64, 2_int64]), 'stack shape')
    call require(result%is_c_contiguous, 'stack C order')
    result = take(inputs(1), [5_int64, -6_int64], status=status)
    call require(status%is_ok(), 'take flatten')
    call inputs(1)%release()
    call inputs(2)%release()
    call require(all(result%data == 1_int8), 'independent result after input release')

    inputs(1) = owned_descriptor_bool([0_int64, 3_int64], status=status)
    result = take(inputs(1), [3_int64], 1_int32, status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'invalid index despite empty batch')
    result = take(inputs(1), no_indices, 1_int32, status)
    call require(status%is_ok(), 'empty take')
    call require(all(result%shape == [0_int64, 0_int64]), 'empty take shape')
    result = take(inputs(1), no_indices, -huge(1_int32)-1_int32, status)
    call require(status%code == 2 .and. .not. result%has_storage(), 'extreme axis rejected')
    result = concatenate(inputs(:0), status=status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'empty input sequence rejected')

    invalid = owned_descriptor_bool([1_int64], status=status)
    deallocate(invalid%shape)
    result = take(invalid, [0_int64], status=status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'missing metadata rejected')
    result = where(mask, inputs(1), invalid, status)
    call require(status%is_failure() .and. .not. result%has_storage(), 'invalid rhs rejected')
    invalid = owned_descriptor_bool([1_int64], status=status)
    invalid%offset = 2_int64
    result = take(invalid, [0_int64], status=status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'out of bounds storage rejected')

    rank_shape = 1_int64
    inputs(1) = owned_descriptor_bool(rank_shape, status=status)
    result = stack(inputs(:1), status=status)
    call require(status%is_failure() .and. .not. result%has_storage(), 'stack rank limit')

    ! Huge logical extents, one borrowed value: overflow must precede allocation/access.
    external = 1_int8
    huge_input = metadata_descriptor_bool([huge(1_int64)], [0_int64], 1_int64, status)
    huge_input%data => external
    call inputs(1)%share_from(huge_input, status)
    call inputs(2)%share_from(huge_input, status)
    result = concatenate(inputs, status=status)
    call require(status%code == 4 .and. .not. result%has_storage(), 'join extent overflow')
    inputs(1) = owned_descriptor_bool([1_int64], status=status)
    inputs(1)%data = -3_int8
    result = take(inputs(1), [0_int64], status=status)
    call require(result%data(1) == 1_int8, 'bool payload normalized')
  end subroutine test_bool

  subroutine test_i32()
    type(ndarray_i32) :: inputs(2), result, invalid, huge_input
    type(ndarray_bool) :: mask
    type(frumpy_status) :: status
    integer(int32), target :: external(1)
    integer(int64) :: rank_shape(32), no_indices(0)

    inputs(1) = owned_descriptor_i32([2_int64, 3_int64], FRUMPY_ORDER_F, status)
    call require(status%is_ok(), 'allocate source')
    inputs(1)%data = 123_int32
    call inputs(2)%share_from(inputs(1), status)
    mask = owned_descriptor_bool([2_int64, 1_int64], status=status)
    mask%data = [-7_int8, 0_int8]
    result = where(mask, inputs(1), inputs(2), status)
    call require(status%is_ok(), 'where same dtype')
    call require(all(result%data == 123_int32), 'where exact values')
    result = concatenate(inputs, -1_int32, status)
    call require(status%is_ok(), 'concatenate')
    call require(all(result%shape == [2_int64, 6_int64]), 'concatenate shape')
    call require(result%is_f_contiguous, 'concatenate F order')
    result = stack(inputs, -1_int32, status)
    call require(status%is_ok(), 'stack')
    call require(all(result%shape == [2_int64, 3_int64, 2_int64]), 'stack shape')
    call require(result%is_c_contiguous, 'stack C order')
    result = take(inputs(1), [5_int64, -6_int64], status=status)
    call require(status%is_ok(), 'take flatten')
    call inputs(1)%release()
    call inputs(2)%release()
    call require(all(result%data == 123_int32), 'independent result after input release')

    inputs(1) = owned_descriptor_i32([0_int64, 3_int64], status=status)
    result = take(inputs(1), [3_int64], 1_int32, status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'invalid index despite empty batch')
    result = take(inputs(1), no_indices, 1_int32, status)
    call require(status%is_ok(), 'empty take')
    call require(all(result%shape == [0_int64, 0_int64]), 'empty take shape')
    result = take(inputs(1), no_indices, -huge(1_int32)-1_int32, status)
    call require(status%code == 2 .and. .not. result%has_storage(), 'extreme axis rejected')
    result = concatenate(inputs(:0), status=status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'empty input sequence rejected')

    invalid = owned_descriptor_i32([1_int64], status=status)
    deallocate(invalid%shape)
    result = take(invalid, [0_int64], status=status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'missing metadata rejected')
    result = where(mask, inputs(1), invalid, status)
    call require(status%is_failure() .and. .not. result%has_storage(), 'invalid rhs rejected')
    invalid = owned_descriptor_i32([1_int64], status=status)
    invalid%offset = 2_int64
    result = take(invalid, [0_int64], status=status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'out of bounds storage rejected')

    rank_shape = 1_int64
    inputs(1) = owned_descriptor_i32(rank_shape, status=status)
    result = stack(inputs(:1), status=status)
    call require(status%is_failure() .and. .not. result%has_storage(), 'stack rank limit')

    ! Huge logical extents, one borrowed value: overflow must precede allocation/access.
    external = 123_int32
    huge_input = metadata_descriptor_i32([huge(1_int64)], [0_int64], 1_int64, status)
    huge_input%data => external
    call inputs(1)%share_from(huge_input, status)
    call inputs(2)%share_from(huge_input, status)
    result = concatenate(inputs, status=status)
    call require(status%code == 4 .and. .not. result%has_storage(), 'join extent overflow')
    mask = owned_descriptor_bool([integer(int64) ::], status=status)
    mask%data = 1_int8
    result = where(mask, huge_input, huge_input, status)
    call require(status%code == 4 .and. .not. result%has_storage(), 'where byte overflow')
  end subroutine test_i32

  subroutine test_i64()
    type(ndarray_i64) :: inputs(2), result, invalid, huge_input
    type(ndarray_bool) :: mask
    type(frumpy_status) :: status
    integer(int64), target :: external(1)
    integer(int64) :: rank_shape(32), no_indices(0)

    inputs(1) = owned_descriptor_i64([2_int64, 3_int64], FRUMPY_ORDER_F, status)
    call require(status%is_ok(), 'allocate source')
    inputs(1)%data = 9007199254740993_int64
    call inputs(2)%share_from(inputs(1), status)
    mask = owned_descriptor_bool([2_int64, 1_int64], status=status)
    mask%data = [-7_int8, 0_int8]
    result = where(mask, inputs(1), inputs(2), status)
    call require(status%is_ok(), 'where same dtype')
    call require(all(result%data == 9007199254740993_int64), 'where exact values')
    result = concatenate(inputs, -1_int32, status)
    call require(status%is_ok(), 'concatenate')
    call require(all(result%shape == [2_int64, 6_int64]), 'concatenate shape')
    call require(result%is_f_contiguous, 'concatenate F order')
    result = stack(inputs, -1_int32, status)
    call require(status%is_ok(), 'stack')
    call require(all(result%shape == [2_int64, 3_int64, 2_int64]), 'stack shape')
    call require(result%is_c_contiguous, 'stack C order')
    result = take(inputs(1), [5_int64, -6_int64], status=status)
    call require(status%is_ok(), 'take flatten')
    call inputs(1)%release()
    call inputs(2)%release()
    call require(all(result%data == 9007199254740993_int64), 'independent result after input release')

    inputs(1) = owned_descriptor_i64([0_int64, 3_int64], status=status)
    result = take(inputs(1), [3_int64], 1_int32, status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'invalid index despite empty batch')
    result = take(inputs(1), no_indices, 1_int32, status)
    call require(status%is_ok(), 'empty take')
    call require(all(result%shape == [0_int64, 0_int64]), 'empty take shape')
    result = take(inputs(1), no_indices, -huge(1_int32)-1_int32, status)
    call require(status%code == 2 .and. .not. result%has_storage(), 'extreme axis rejected')
    result = concatenate(inputs(:0), status=status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'empty input sequence rejected')

    invalid = owned_descriptor_i64([1_int64], status=status)
    deallocate(invalid%shape)
    result = take(invalid, [0_int64], status=status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'missing metadata rejected')
    result = where(mask, inputs(1), invalid, status)
    call require(status%is_failure() .and. .not. result%has_storage(), 'invalid rhs rejected')
    invalid = owned_descriptor_i64([1_int64], status=status)
    invalid%offset = 2_int64
    result = take(invalid, [0_int64], status=status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'out of bounds storage rejected')

    rank_shape = 1_int64
    inputs(1) = owned_descriptor_i64(rank_shape, status=status)
    result = stack(inputs(:1), status=status)
    call require(status%is_failure() .and. .not. result%has_storage(), 'stack rank limit')

    ! Huge logical extents, one borrowed value: overflow must precede allocation/access.
    external = 9007199254740993_int64
    huge_input = metadata_descriptor_i64([huge(1_int64)], [0_int64], 1_int64, status)
    huge_input%data => external
    call inputs(1)%share_from(huge_input, status)
    call inputs(2)%share_from(huge_input, status)
    result = concatenate(inputs, status=status)
    call require(status%code == 4 .and. .not. result%has_storage(), 'join extent overflow')
    mask = owned_descriptor_bool([integer(int64) ::], status=status)
    mask%data = 1_int8
    result = where(mask, huge_input, huge_input, status)
    call require(status%code == 4 .and. .not. result%has_storage(), 'where byte overflow')
  end subroutine test_i64

  subroutine test_r32()
    type(ndarray_r32) :: inputs(2), result, invalid, huge_input
    type(ndarray_bool) :: mask
    type(frumpy_status) :: status
    real(real32), target :: external(1)
    integer(int64) :: rank_shape(32), no_indices(0)

    inputs(1) = owned_descriptor_r32([2_int64, 3_int64], FRUMPY_ORDER_F, status)
    call require(status%is_ok(), 'allocate source')
    inputs(1)%data = 1.25_real32
    call inputs(2)%share_from(inputs(1), status)
    mask = owned_descriptor_bool([2_int64, 1_int64], status=status)
    mask%data = [-7_int8, 0_int8]
    result = where(mask, inputs(1), inputs(2), status)
    call require(status%is_ok(), 'where same dtype')
    call require(all(abs(result%data - 1.25_real32) < epsilon(1.25_real32)), 'where exact values')
    result = concatenate(inputs, -1_int32, status)
    call require(status%is_ok(), 'concatenate')
    call require(all(result%shape == [2_int64, 6_int64]), 'concatenate shape')
    call require(result%is_f_contiguous, 'concatenate F order')
    result = stack(inputs, -1_int32, status)
    call require(status%is_ok(), 'stack')
    call require(all(result%shape == [2_int64, 3_int64, 2_int64]), 'stack shape')
    call require(result%is_c_contiguous, 'stack C order')
    result = take(inputs(1), [5_int64, -6_int64], status=status)
    call require(status%is_ok(), 'take flatten')
    call inputs(1)%release()
    call inputs(2)%release()
    call require(all(abs(result%data - 1.25_real32) < epsilon(1.25_real32)), 'independent result after input release')

    inputs(1) = owned_descriptor_r32([0_int64, 3_int64], status=status)
    result = take(inputs(1), [3_int64], 1_int32, status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'invalid index despite empty batch')
    result = take(inputs(1), no_indices, 1_int32, status)
    call require(status%is_ok(), 'empty take')
    call require(all(result%shape == [0_int64, 0_int64]), 'empty take shape')
    result = take(inputs(1), no_indices, -huge(1_int32)-1_int32, status)
    call require(status%code == 2 .and. .not. result%has_storage(), 'extreme axis rejected')
    result = concatenate(inputs(:0), status=status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'empty input sequence rejected')

    invalid = owned_descriptor_r32([1_int64], status=status)
    deallocate(invalid%shape)
    result = take(invalid, [0_int64], status=status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'missing metadata rejected')
    result = where(mask, inputs(1), invalid, status)
    call require(status%is_failure() .and. .not. result%has_storage(), 'invalid rhs rejected')
    invalid = owned_descriptor_r32([1_int64], status=status)
    invalid%offset = 2_int64
    result = take(invalid, [0_int64], status=status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'out of bounds storage rejected')

    rank_shape = 1_int64
    inputs(1) = owned_descriptor_r32(rank_shape, status=status)
    result = stack(inputs(:1), status=status)
    call require(status%is_failure() .and. .not. result%has_storage(), 'stack rank limit')

    ! Huge logical extents, one borrowed value: overflow must precede allocation/access.
    external = 1.25_real32
    huge_input = metadata_descriptor_r32([huge(1_int64)], [0_int64], 1_int64, status)
    huge_input%data => external
    call inputs(1)%share_from(huge_input, status)
    call inputs(2)%share_from(huge_input, status)
    result = concatenate(inputs, status=status)
    call require(status%code == 4 .and. .not. result%has_storage(), 'join extent overflow')
    mask = owned_descriptor_bool([integer(int64) ::], status=status)
    mask%data = 1_int8
    result = where(mask, huge_input, huge_input, status)
    call require(status%code == 4 .and. .not. result%has_storage(), 'where byte overflow')
  end subroutine test_r32

  subroutine test_r64()
    type(ndarray_r64) :: inputs(2), result, invalid, huge_input
    type(ndarray_bool) :: mask
    type(frumpy_status) :: status
    real(real64), target :: external(1)
    integer(int64) :: rank_shape(32), no_indices(0)

    inputs(1) = owned_descriptor_r64([2_int64, 3_int64], FRUMPY_ORDER_F, status)
    call require(status%is_ok(), 'allocate source')
    inputs(1)%data = 1.25_real64
    call inputs(2)%share_from(inputs(1), status)
    mask = owned_descriptor_bool([2_int64, 1_int64], status=status)
    mask%data = [-7_int8, 0_int8]
    result = where(mask, inputs(1), inputs(2), status)
    call require(status%is_ok(), 'where same dtype')
    call require(all(abs(result%data - 1.25_real64) < epsilon(1.25_real64)), 'where exact values')
    result = concatenate(inputs, -1_int32, status)
    call require(status%is_ok(), 'concatenate')
    call require(all(result%shape == [2_int64, 6_int64]), 'concatenate shape')
    call require(result%is_f_contiguous, 'concatenate F order')
    result = stack(inputs, -1_int32, status)
    call require(status%is_ok(), 'stack')
    call require(all(result%shape == [2_int64, 3_int64, 2_int64]), 'stack shape')
    call require(result%is_c_contiguous, 'stack C order')
    result = take(inputs(1), [5_int64, -6_int64], status=status)
    call require(status%is_ok(), 'take flatten')
    call inputs(1)%release()
    call inputs(2)%release()
    call require(all(abs(result%data - 1.25_real64) < epsilon(1.25_real64)), 'independent result after input release')

    inputs(1) = owned_descriptor_r64([0_int64, 3_int64], status=status)
    result = take(inputs(1), [3_int64], 1_int32, status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'invalid index despite empty batch')
    result = take(inputs(1), no_indices, 1_int32, status)
    call require(status%is_ok(), 'empty take')
    call require(all(result%shape == [0_int64, 0_int64]), 'empty take shape')
    result = take(inputs(1), no_indices, -huge(1_int32)-1_int32, status)
    call require(status%code == 2 .and. .not. result%has_storage(), 'extreme axis rejected')
    result = concatenate(inputs(:0), status=status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'empty input sequence rejected')

    invalid = owned_descriptor_r64([1_int64], status=status)
    deallocate(invalid%shape)
    result = take(invalid, [0_int64], status=status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'missing metadata rejected')
    result = where(mask, inputs(1), invalid, status)
    call require(status%is_failure() .and. .not. result%has_storage(), 'invalid rhs rejected')
    invalid = owned_descriptor_r64([1_int64], status=status)
    invalid%offset = 2_int64
    result = take(invalid, [0_int64], status=status)
    call require(status%code == 1 .and. .not. result%has_storage(), 'out of bounds storage rejected')

    rank_shape = 1_int64
    inputs(1) = owned_descriptor_r64(rank_shape, status=status)
    result = stack(inputs(:1), status=status)
    call require(status%is_failure() .and. .not. result%has_storage(), 'stack rank limit')

    ! Huge logical extents, one borrowed value: overflow must precede allocation/access.
    external = 1.25_real64
    huge_input = metadata_descriptor_r64([huge(1_int64)], [0_int64], 1_int64, status)
    huge_input%data => external
    call inputs(1)%share_from(huge_input, status)
    call inputs(2)%share_from(huge_input, status)
    result = concatenate(inputs, status=status)
    call require(status%code == 4 .and. .not. result%has_storage(), 'join extent overflow')
    mask = owned_descriptor_bool([integer(int64) ::], status=status)
    mask%data = 1_int8
    result = where(mask, huge_input, huge_input, status)
    call require(status%code == 4 .and. .not. result%has_storage(), 'where byte overflow')
  end subroutine test_r64

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_selection_dtypes
