program test_searching_dtypes
  use iso_fortran_env, only: int8, int32, int64, real32
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_positive_inf
  use frumpy, only: ndarray_bool, ndarray_i64, ndarray_r32, owned_descriptor_bool, &
    owned_descriptor_i64, owned_descriptor_r32, view_descriptor_bool, view_descriptor_i64, &
    searchsorted, frumpy_status, FRUMPY_STATUS_OVERFLOW, FRUMPY_STATUS_INVALID_SHAPE, &
    FRUMPY_STATUS_UNSUPPORTED_DTYPE
  implicit none
  call exercise()
contains
  subroutine exercise()
    type(ndarray_i64) :: source,queries,result,invalid
    type(ndarray_bool) :: bits,truth,virtual
    type(ndarray_r32) :: floats,targets
    type(frumpy_status) :: status
    real(real32) :: infinity,nan

    source=owned_descriptor_i64([4_int64])
    source%data=[-huge(1_int64)-1_int64,huge(1_int64)-1_int64,huge(1_int64),huge(1_int64)]
    queries=owned_descriptor_i64([3_int64])
    queries%data=[huge(1_int64)-2_int64,huge(1_int64),-huge(1_int64)-1_int64]
    result=searchsorted(source,queries,status=status)
    call require(status%is_ok(),'integer left status')
    call require(all(result%data==[1_int64,2_int64,0_int64]),'exact integer left indices')
    result=searchsorted(source,queries,.true.,status)
    call require(status%is_ok(),'integer right status')
    call require(all(result%data==[1_int64,4_int64,1_int64]),'exact integer right indices')
    call require(result%owns_data .and. result%is_c_contiguous,'owned C result')
    call source%release()
    call queries%release()
    call require(result%data(2)==4_int64,'independent result lifetime')
    bits=owned_descriptor_bool([4_int64])
    bits%data=[0_int8,0_int8,-2_int8,3_int8]
    truth=owned_descriptor_bool([2_int64])
    truth%data=[-1_int8,0_int8]
    result=searchsorted(bits,truth,.true.,status)
    call require(status%is_ok(),'noncanonical bool status')
    call require(all(result%data==[4_int64,2_int64]),'normalized truth ordering')
    virtual=view_descriptor_bool(bits,[huge(1_int64)],[0_int64],1_int64)
    truth=owned_descriptor_bool([integer(int64)::])
    truth%data=1_int8
    result=searchsorted(virtual,truth,status=status)
    call require(status%is_ok() .and. result%rank==0,'virtual source scalar query')
    call require(result%data(1)==huge(1_int64),'midpoint and final index do not overflow')
    virtual=view_descriptor_bool(bits,[shiftr(huge(1_int64),3)+1_int64],[0_int64],1_int64)
    result=searchsorted(bits,virtual,status=status)
    call require(status%code==FRUMPY_STATUS_OVERFLOW,'result byte overflow')
    call require(.not. result%has_storage(),'overflow has no output')
    source=owned_descriptor_i64([1_int64])
    source%data=0_int64
    invalid=view_descriptor_i64(source,[2_int64],[huge(1_int64)],1_int64)
    result=searchsorted(source,invalid,status=status)
    call require(status%code==FRUMPY_STATUS_INVALID_SHAPE,'query bounds validated')
    result=searchsorted(invalid,source,status=status)
    call require(status%code==FRUMPY_STATUS_INVALID_SHAPE,'source bounds validated')
    result=searchsorted(bits,source,status=status)
    call require(status%code==FRUMPY_STATUS_UNSUPPORTED_DTYPE,'mixed dtype rejected')
    result=searchsorted(bits,source)
    call require(.not. result%has_storage(),'optional failure status')
    infinity=ieee_value(0.0_real32,ieee_positive_inf)
    nan=ieee_value(0.0_real32,ieee_quiet_nan)
    floats=owned_descriptor_r32([6_int64])
    floats%data=[-infinity,-0.0_real32,0.0_real32,infinity,nan,nan]
    targets=owned_descriptor_r32([3_int64])
    targets%data=[nan,0.0_real32,infinity]
    result=searchsorted(floats,targets,status=status)
    call require(status%is_ok(),'floating left status')
    call require(all(result%data==[4_int64,1_int64,3_int64]),'NaN and signed-zero left')
    result=searchsorted(floats,targets,.true.,status)
    call require(status%is_ok(),'floating right status')
    call require(all(result%data==[6_int64,3_int64,4_int64]),'NaN and signed-zero right')
  end subroutine exercise
  subroutine require(condition,message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      print *,message
      error stop 1
    end if
  end subroutine require
end program test_searching_dtypes
