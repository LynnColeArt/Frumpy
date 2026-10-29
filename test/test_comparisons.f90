program test_comparisons
  use iso_fortran_env, only: int8, int64
  use frumpy, only: ndarray_i64, ndarray_bool, owned_descriptor_i64, owned_descriptor_bool, &
    view_descriptor_i64, equal, less, logical_not_bool, logical_and_bool, frumpy_status, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_UNSUPPORTED_DTYPE
  implicit none
  call exercise()
contains
  subroutine exercise()
    type(ndarray_i64) :: source, view, invalid
    type(ndarray_bool) :: result, truth
    type(frumpy_status) :: status

    source = owned_descriptor_i64([2_int64])
    source%data = [9007199254740992_int64, 9007199254740993_int64]
    view = view_descriptor_i64(source, [2_int64], [-1_int64], 2_int64)
    result = less(source, view, status)
    call require(status%is_ok(), 'comparison status')
    call require(all(result%data == [1_int8, 0_int8]), 'exact integer comparison above 2^53')
    call require(result%owns_data .and. result%is_c_contiguous, 'boolean result ownership')
    call source%release()
    call view%release()
    call require(result%data(1) == 1_int8, 'comparison lifetime')
    truth = owned_descriptor_bool([2_int64])
    truth%data = [-3_int8, 0_int8]
    result = logical_not_bool(truth, status)
    call require(status%is_ok(), 'logical status')
    call require(all(result%data == [0_int8, 1_int8]), 'noncanonical boolean truth')
    source = owned_descriptor_i64([2_int64])
    result = logical_and_bool(truth, source, status)
    call require(status%code == FRUMPY_STATUS_UNSUPPORTED_DTYPE, 'logical numeric input rejected')
    call require(.not. result%has_storage(), 'logical failure no result')
    invalid = view_descriptor_i64(source, [2_int64], [huge(1_int64)], 1_int64)
    result = equal(invalid, source, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'bad comparison bounds')
    call require(.not. result%has_storage(), 'comparison failure no result')
  end subroutine exercise

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      print *, message
      error stop 1
    end if
  end subroutine require
end program test_comparisons
