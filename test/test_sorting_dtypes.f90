program test_sorting_dtypes
  use iso_fortran_env, only: int8, int32, int64
  use frumpy, only: ndarray_bool, ndarray_i32, ndarray_i64, owned_descriptor_bool, &
    owned_descriptor_i32, owned_descriptor_i64, view_descriptor_bool, view_descriptor_i32, &
    sort, argsort, frumpy_status, FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_INVALID_AXIS, &
    FRUMPY_STATUS_OVERFLOW
  implicit none
  call exercise()
contains
  subroutine exercise()
    type(ndarray_bool) :: bits,sorted_bits,huge_view
    type(ndarray_i32) :: source,view,sorted,invalid
    type(ndarray_i64) :: wide,indices
    type(frumpy_status) :: status

    bits=owned_descriptor_bool([4_int64])
    bits%data=[-2_int8,0_int8,1_int8,0_int8]
    indices=argsort(bits,status=status)
    call require(status%is_ok(),'bool argsort status')
    call require(all(indices%data==[1_int64,3_int64,0_int64,2_int64]),'stable normalized truth')
    sorted_bits=sort(bits,status=status)
    call require(status%is_ok(),'bool sort status')
    call require(all(sorted_bits%data==[0_int8,0_int8,1_int8,1_int8]),'normalized bool result')
    wide=owned_descriptor_i64([4_int64])
    wide%data=[huge(1_int64),huge(1_int64)-1_int64,-huge(1_int64)-1_int64,huge(1_int64)]
    indices=argsort(wide,status=status)
    call require(status%is_ok(),'exact int64 status')
    call require(all(indices%data==[2_int64,1_int64,0_int64,3_int64]),'exact int64 order')
    source=owned_descriptor_i32([6_int64])
    source%data=[3_int32,1_int32,2_int32,3_int32,1_int32,2_int32]
    view=view_descriptor_i32(source,[2_int64,3_int64],[-3_int64,-1_int64],6_int64)
    sorted=sort(view,status=status)
    call require(status%is_ok(),'signed-stride sort')
    call require(all(sorted%data==[1_int32,2_int32,3_int32,1_int32,2_int32,3_int32]),'values')
    call require(sorted%owns_data .and. sorted%is_c_contiguous,'owned output')
    call source%release()
    call view%release()
    call require(sorted%data(1)==1_int32,'independent output lifetime')
    indices=argsort(invalid,status=status)
    call require(status%is_failure() .and. .not. indices%has_storage(),'missing storage')
    source=owned_descriptor_i32([1_int64])
    invalid=view_descriptor_i32(source,[2_int64],[huge(1_int64)],1_int64)
    sorted=sort(invalid,status=status)
    call require(status%code==FRUMPY_STATUS_INVALID_SHAPE,'invalid reachable bounds')
    call require(.not. sorted%has_storage(),'failed sort has no storage')
    indices=argsort(source,axis0=-2_int32,status=status)
    call require(status%code==FRUMPY_STATUS_INVALID_AXIS,'invalid negative axis')
    huge_view=view_descriptor_bool(bits,[shiftr(huge(1_int64),3)+1_int64],[0_int64],1_int64)
    indices=argsort(huge_view,status=status)
    call require(status%code==FRUMPY_STATUS_OVERFLOW,'int64 result bytes overflow')
    sorted_bits=sort(huge_view,status=status)
    call require(status%code==FRUMPY_STATUS_OVERFLOW,'sort index temporary overflow')
    call require(.not. sorted_bits%has_storage(),'overflow has no output')
  end subroutine exercise
  subroutine require(condition,message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      print *,message
      error stop 1
    end if
  end subroutine require
end program test_sorting_dtypes
