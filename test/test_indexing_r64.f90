program test_indexing_r64
  use iso_fortran_env, only: int8, int64, real64
  use frumpy, only: ndarray_r64, ndarray_bool, owned_descriptor_r64, owned_descriptor_bool, &
    view_descriptor_r64, assign_r64, mask_select_r64, frumpy_status, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OVERFLOW
  implicit none
  call exercise()
contains
  subroutine exercise()
    type(ndarray_r64) :: owner, target, rhs, selected, invalid
    type(ndarray_bool) :: mask
    type(frumpy_status) :: status

    owner = owned_descriptor_r64([4_int64])
    owner%data = [1.0_real64,2.0_real64,3.0_real64,4.0_real64]
    target = view_descriptor_r64(owner, [3_int64], [1_int64], 2_int64)
    rhs = view_descriptor_r64(owner, [3_int64], [1_int64], 1_int64)
    call assign_r64(target, rhs, status)
    call require(status%is_ok(), 'overlapping assignment status')
    call require(all(abs(owner%data-[1.0_real64,1.0_real64,2.0_real64,3.0_real64]) &
      < 1e-14_real64), 'overlapping assignment stages input')
    call require(target%offset == 2_int64 .and. .not. target%owns_data, 'target metadata preserved')
    target = view_descriptor_r64(owner, [4_int64], [-1_int64], 4_int64)
    call assign_r64(target, owner, status)
    call require(status%is_ok(), 'reverse overlap assignment')
    call require(all(abs(owner%data-[3.0_real64,2.0_real64,1.0_real64,1.0_real64]) &
      < 1e-14_real64), 'reverse overlap values')
    mask = owned_descriptor_bool([4_int64])
    mask%data = [-2_int8,0_int8,1_int8,0_int8]
    selected = mask_select_r64(owner, mask, status)
    call require(status%is_ok(), 'mask select status')
    call require(all(abs(selected%data-[3.0_real64,1.0_real64]) < 1e-14_real64), 'mask selection')
    call require(selected%owns_data .and. .not. associated(selected%data,owner%data), 'mask copy')
    invalid = view_descriptor_r64(owner, [4_int64], [huge(1_int64)], 1_int64)
    call assign_r64(target, invalid, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'bad rhs rejected')
    call require(abs(owner%data(1)-3.0_real64)<1e-14_real64, 'bad rhs preserves target')
    target = view_descriptor_r64(owner, [3_int64], [0_int64], 1_int64)
    rhs = owned_descriptor_r64([3_int64])
    rhs%data = [4.0_real64,5.0_real64,6.0_real64]
    call assign_r64(target, rhs, status)
    call require(status%is_ok(), 'zero stride assignment')
    call require(abs(owner%data(1)-6.0_real64)<1e-14_real64, 'last C-order write wins')
    target = view_descriptor_r64(owner, [shiftr(huge(1_int64),3)+1_int64], [0_int64], 1_int64)
    rhs = owned_descriptor_r64([integer(int64) ::])
    rhs%data = 9.0_real64
    call assign_r64(target, rhs, status)
    call require(status%code == FRUMPY_STATUS_OVERFLOW, 'staging bytes overflow')
    call require(abs(owner%data(1)-6.0_real64)<1e-14_real64, 'overflow preserves target')
    call owner%release()
    call target%release()
    call require(abs(selected%data(1)-3.0_real64)<1e-14_real64, 'selected result lifetime')
  end subroutine exercise

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_indexing_r64
