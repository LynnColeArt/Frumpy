!> Same-dtype binary search with exact integer keys and NaNs-last real ordering.
module frumpy_searching
  use iso_fortran_env, only: int32, int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
  use frumpy_operands, only: operand, bind_operand, integer_value, real64_value
  use frumpy_dtypes, only: FRUMPY_DTYPE_I64
  use frumpy_shape, only: element_count
  use frumpy_strides, only: flat_offset
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64
  use frumpy_ndarray_r64, only: ndarray_r64
  use frumpy_searching_r64, only: searchsorted_r64
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_INVALID_SHAPE, &
    FRUMPY_STATUS_UNSUPPORTED_DTYPE, FRUMPY_STATUS_OVERFLOW
  implicit none
  private
  public :: searchsorted
contains
  function searchsorted(source,values,side_right,status) result(array)
    class(*), target, intent(in) :: source,values
    logical, optional, intent(in) :: side_right
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i64) :: array
    type(operand) :: input,queries
    type(frumpy_status) :: local
    integer(int64) :: count,i,position
    logical :: right

    ! Retain the established float64 kernel without duplicate metadata validation.
    select type (source)
    type is (ndarray_r64)
      select type (values)
      type is (ndarray_r64)
        array=searchsorted_r64(source,values,side_right,status)
        return
      end select
    end select
    call bind_operand(source,input,local)
    if (local%is_ok()) call bind_operand(values,queries,local)
    if (local%is_ok()) then
      if (input%dtype_id/=queries%dtype_id) then
        call set_status(local,FRUMPY_STATUS_UNSUPPORTED_DTYPE, &
          'searchsorted requires matching dtypes')
      else if (size(input%shape)/=1) then
        call set_status(local,FRUMPY_STATUS_INVALID_SHAPE,'searchsorted source must be a vector')
      end if
    end if
    if (local%is_ok()) then
      count=element_count(queries%shape,local)
      if (local%is_ok()) then
        if (count>shiftr(huge(1_int64),3)) &
          call set_status(local,FRUMPY_STATUS_OVERFLOW,'searchsorted result bytes overflow')
      end if
    end if
    if (local%is_ok()) array=owned_descriptor_i64(queries%shape,status=local)
    if (present(status)) status=local
    if (local%is_failure()) return
    right=.false.
    if (present(side_right)) right=side_right
    do i=0_int64,count-1_int64
      position=flat_offset(queries%shape,queries%strides,queries%offset,i)
      if (input%dtype_id<=FRUMPY_DTYPE_I64) then
        array%data(i+1_int64)=integer_search(input,integer_value(queries,position),right)
      else
        array%data(i+1_int64)=real_search(input,real64_value(queries,position),right)
      end if
    end do
  end function searchsorted

  function integer_search(source,target,right) result(position)
    type(operand), intent(in) :: source
    integer(int64), intent(in) :: target
    logical, intent(in) :: right
    integer(int64) :: position,lower,upper,middle,value

    lower=0_int64
    upper=source%shape(1)
    do while (lower<upper)
      middle=lower+(upper-lower)/2_int64
      value=integer_value(source,source%offset+middle*source%strides(1))
      if (value<target .or. (right .and. value==target)) then
        lower=middle+1_int64
      else
        upper=middle
      end if
    end do
    position=lower
  end function integer_search

  function real_search(source,target,right) result(position)
    type(operand), intent(in) :: source
    real(real64), intent(in) :: target
    logical, intent(in) :: right
    integer(int64) :: position,lower,upper,middle
    real(real64) :: value
    logical :: advance,target_nan

    target_nan=ieee_is_nan(target)
    lower=0_int64
    upper=source%shape(1)
    do while (lower<upper)
      middle=lower+(upper-lower)/2_int64
      value=real64_value(source,source%offset+middle*source%strides(1))
      if (ieee_is_nan(value)) then
        advance=right .and. target_nan
      else if (target_nan) then
        advance=.true.
      else if (right) then
        advance=value<=target
      else
        advance=value<target
      end if
      if (advance) then
        lower=middle+1_int64
      else
        upper=middle
      end if
    end do
    position=lower
  end function real_search
end module frumpy_searching
