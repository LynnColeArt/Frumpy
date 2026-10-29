!> Exercise ownership through public APIs, including compiler-created temporaries.
program test_storage_lifetime_r64
  use iso_fortran_env, only: int32, int64, real64
  use frumpy, only: share_descriptors_r64, ndarray_r64, frumpy_status, full_r64, copy_r64, &
    view_descriptor_r64, transpose_r64, reshape_r64, add_r64, concatenate_r64, &
    metadata_descriptor_r64, FRUMPY_STATUS_INVALID_SHAPE
  implicit none

  call exercise_lifetimes()
  call exercise_array_assignment()
  call exercise_borrowed_storage()
  call exercise_allocatable_owners()
  call exercise_adapter_cleanup()

contains

  subroutine exercise_lifetimes()
    type(ndarray_r64) :: owner, alias, reversed, independent, result
    type(frumpy_status) :: status
    integer(int32) :: iteration

    owner = full_r64([3_int64], 7.0_real64, status=status)
    call require(status%is_ok(), 'constructor')
    alias = owner
    owner%data(2) = 9.0_real64
    call require(abs(alias%data(2) - 9.0_real64) < 1e-12_real64, 'assignment shares')
    independent = copy_r64(owner, status=status)
    call require(status%is_ok(), 'copy')
    reversed = view_descriptor_r64(owner, [3_int64], [-1_int64], 3_int64, status)
    call require(status%is_ok(), 'reversed view')
    call owner%release()
    call owner%release()
    call require(.not. owner%has_storage(), 'release clears storage')
    call require(.not. allocated(owner%shape), 'release clears metadata')
    call alias%release()
    call require(abs(reversed%data(2) - 9.0_real64) < 1e-12_real64, 'view keeps storage alive')
    reversed%data(2) = 11.0_real64
    call require(abs(independent%data(2) - 9.0_real64) < 1e-12_real64, 'copy is independent')

    owner = escaped_view()
    call require(all(abs(owner%data - 4.0_real64) < 1e-12_real64), 'view survives owner scope')
    owner = transpose_r64(owner, status=status)
    call require(status%is_ok(), 'replace owner with view of itself')
    call require(all(owner%shape == [3_int64, 2_int64]), 'transpose metadata')
    owner = owner
    call require(owner%has_storage(), 'self assignment')
    result = concatenate_r64([owner, owner], axis0=0_int32, status=status)
    call require(status%is_ok(), 'temporary array constructor')
    call require(owner%has_storage(), 'array constructor leaves original alive')

    do iteration = 1_int32, 100_int32
      owner = full_r64([2_int64, 3_int64], 2.0_real64, status=status)
      owner = add_r64(owner, full_r64([3_int64], 1.0_real64), status)
      call require(status%is_ok(), 'nested function temporaries')
      call require(all(abs(owner%data - 3.0_real64) < 1e-12_real64), 'nested result')
    end do

    owner = full_r64([0_int64], 0.0_real64, status=status)
    owner = owner
    alias = owner
    call owner%release()
    call require(alias%has_storage() .and. alias%size() == 0_int64, 'empty storage sharing')
    owner = full_r64([integer(int64) ::], 5.0_real64, status=status)
    alias = owner
    call owner%release()
    call require(abs(alias%data(1) - 5.0_real64) < 1e-12_real64, 'scalar storage sharing')
    owner = full_r64([-1_int64], 0.0_real64, status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'failed construction')
    call require(.not. owner%has_storage(), 'failed construction has no storage')
  end subroutine exercise_lifetimes

  function escaped_view() result(view)
    type(ndarray_r64) :: view, local_owner
    type(frumpy_status) :: status

    local_owner = full_r64([6_int64], 4.0_real64, status=status)
    view = reshape_r64(local_owner, [2_int64, 3_int64], status)
    call require(status%is_ok(), 'returned local view')
  end function escaped_view

  subroutine exercise_array_assignment()
    type(ndarray_r64), allocatable :: arrays(:), aliases(:)
    type(ndarray_r64) :: result
    type(frumpy_status) :: status

    allocate(arrays(2), aliases(2))
    arrays(1) = full_r64([2_int64], 1.0_real64)
    arrays(2) = full_r64([2_int64], 2.0_real64)
    call share_descriptors_r64(aliases, arrays, status)
    call require(status%is_ok(), 'share descriptor vector')
    call share_descriptors_r64(aliases(:1), arrays, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'descriptor vector length mismatch')
    deallocate(arrays)
    call share_descriptors_r64(aliases, aliases(2:1:-1), status)
    call require(status%is_ok(), 'overlapping descriptor vector')
    result = concatenate_r64(aliases, status=status)
    call require(status%is_ok(), 'array assignment retains storage')
    call require(all(abs(result%data - [2.0_real64, 2.0_real64, &
      1.0_real64, 1.0_real64]) < 1e-12_real64), 'array values')
    deallocate(aliases)
  end subroutine exercise_array_assignment

  subroutine exercise_borrowed_storage()
    real(real64), target :: external(2), empty_external(0)
    type(ndarray_r64) :: borrowed, alias

    external = 3.0_real64
    borrowed = metadata_descriptor_r64([2_int64], [1_int64], 1_int64)
    borrowed = borrowed
    borrowed%data => external
    alias = borrowed
    call borrowed%release()
    alias%data(1) = 8.0_real64
    call alias%release()
    call require(abs(external(1) - 8.0_real64) < 1e-12_real64, 'borrowed buffer not freed')
    borrowed = metadata_descriptor_r64([0_int64], [0_int64], 1_int64)
    borrowed%data => empty_external
    borrowed = borrowed
    call require(borrowed%has_storage(), 'empty borrowed self assignment')
    call borrowed%release()
  end subroutine exercise_borrowed_storage

  subroutine exercise_allocatable_owners()
    type :: container
      type(ndarray_r64) :: value
    end type container
    type(container), allocatable :: enclosing
    type(ndarray_r64), allocatable :: owner
    type(ndarray_r64) :: alias
    type(frumpy_status) :: status

    allocate(owner, enclosing)
    owner = full_r64([2_int64], 6.0_real64)
    call enclosing%value%share_from(owner, status)
    call require(status%is_ok(), 'explicit enclosing component share')
    deallocate(owner)
    alias = enclosing%value
    deallocate(enclosing)
    call require(all(abs(alias%data - 6.0_real64) < 1e-12_real64), 'enclosing owner finalized')
    call replace_intent_out(alias)
    call require(all(abs(alias%data - 3.0_real64) < 1e-12_real64), 'intent out replacement')
  end subroutine exercise_allocatable_owners

  subroutine replace_intent_out(array)
    type(ndarray_r64), intent(out) :: array

    array = full_r64([3_int64], 3.0_real64)
  end subroutine replace_intent_out

  subroutine exercise_adapter_cleanup()
    real(real64), target :: lhs(3), rhs(3), empty(0)
    real(real64) :: values(3), empty_values(0)
    integer(int32) :: iteration
    type(frumpy_status) :: status

    lhs = [1.0_real64, 2.0_real64, 3.0_real64]
    rhs = [4.0_real64, 5.0_real64, 6.0_real64]
    do iteration = 1_int32, 10000_int32
      call borrowed_add(lhs, rhs, values, mod(iteration, 2_int32) == 0_int32, status)
      call require(status%is_ok(), 'adapter addition')
      call require(all(abs(values - ([5.0_real64, 7.0_real64, 9.0_real64])) < 1e-12_real64), 'adapter values')
      call borrowed_add(empty, empty, empty_values, .true., status)
      call require(status%is_ok(), 'empty adapter addition')
      call borrowed_add(lhs, rhs(:2), values, .true., status)
      call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'adapter failure status')
      call require(all(abs(values - (-99.0_real64)) < 1e-12_real64), 'failed adapter leaves no result')
    end do
    call require(all(abs(lhs - ([1.0_real64, 2.0_real64, 3.0_real64])) < 1e-12_real64), 'borrowed lhs survives')
    call require(all(abs(rhs - ([4.0_real64, 5.0_real64, 6.0_real64])) < 1e-12_real64), 'borrowed rhs survives')
  end subroutine exercise_adapter_cleanup

  subroutine borrowed_add(lhs_data, rhs_data, values, explicit_release, status)
    real(real64), target, intent(in) :: lhs_data(:), rhs_data(:)
    real(real64), intent(out) :: values(:)
    logical, intent(in) :: explicit_release
    type(frumpy_status), intent(out) :: status
    type(ndarray_r64) :: lhs, rhs, output, alias

    values = -99.0_real64
    lhs = metadata_descriptor_r64([size(lhs_data, kind=int64)], [1_int64], 1_int64, status)
    call require(status%is_ok(), 'adapter lhs metadata')
    rhs = metadata_descriptor_r64([size(rhs_data, kind=int64)], [1_int64], 1_int64, status)
    call require(status%is_ok(), 'adapter rhs metadata')
    lhs%data => lhs_data
    rhs%data => rhs_data
    output = add_r64(lhs, rhs, status)
    if (status%is_failure()) then
      call require(.not. output%has_storage(), 'failed adapter output has no storage')
      call output%release()
      call output%release()
      return
    end if
    alias = view_descriptor_r64(output, output%shape, output%strides, output%offset, status)
    call require(status%is_ok(), 'adapter result view')
    if (explicit_release) then
      ! Issue #2: raw deallocate(output%data) leaves the private backing dangling.
      call output%release()
      call output%release()
      call require(.not. output%has_storage(), 'adapter explicit release clears result')
    end if
    values = alias%data
    call lhs%release()
    call lhs%release()
    ! All descriptors finalize here, including the already released owner/borrow.
  end subroutine borrowed_add

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not. condition) then
      write (*, '(a)') message
      error stop 1
    end if
  end subroutine require
end program test_storage_lifetime_r64
