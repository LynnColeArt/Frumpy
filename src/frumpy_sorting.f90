!> Stable index merge sorting for the remaining concrete dtypes.
module frumpy_sorting
  use iso_fortran_env, only: int8, int32, int64, real32, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
  use frumpy_operands, only: operand, bind_operand, integer_value, real64_value
  use frumpy_constants, only: FRUMPY_ORDER_C, FRUMPY_ORDER_F
  use frumpy_strides, only: flat_offset
  use frumpy_shape, only: element_count
  use frumpy_reduction_plans, only: reduction_plan, plan_reduction
  use frumpy_sorting_r64, only: sort_r64, argsort_r64
  use frumpy_ndarray_bool, only: ndarray_bool, owned_descriptor_bool
  use frumpy_ndarray_i32, only: ndarray_i32, owned_descriptor_i32
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64
  use frumpy_ndarray_r32, only: ndarray_r32, owned_descriptor_r32
  use frumpy_ndarray_r64, only: ndarray_r64
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_INVALID_AXIS, &
    FRUMPY_STATUS_OVERFLOW, FRUMPY_STATUS_ALLOCATION_FAILED
  implicit none
  private
  public :: sort, argsort, sort_bool, sort_i32, sort_i64, sort_r32
  interface sort
    module procedure sort_bool, sort_i32, sort_i64, sort_r32
    procedure :: sort_r64
  end interface sort
contains
  function argsort(source, axis0, status) result(array)
    class(*), target, intent(in) :: source
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i64) :: array
    type(operand) :: input
    type(frumpy_status) :: local
    type(reduction_plan) :: plan, output_plan
    integer(int64), allocatable :: indices(:), work(:)
    integer(int64) :: count, extent, i, j, base, output_base
    integer(int32) :: axis
    integer :: alloc_stat

    ! The existing r64 kernel validates its own descriptor; avoid doing it twice.
    select type (source)
    type is (ndarray_r64)
      array=argsort_r64(source,axis0,status)
      return
    end select
    call bind_operand(source, input, local)
    if (local%is_failure()) then
      if (present(status)) status=local
      return
    end if
    axis=-1_int32
    if (present(axis0)) axis=axis0
    if (size(input%shape)==0) then
      if (axis/=-1_int32 .and. axis/=0_int32) then
        call set_status(local,FRUMPY_STATUS_INVALID_AXIS,'scalar argsort axis out of bounds')
      else
        array=owned_descriptor_i64([1_int64],status=local)
        if (local%is_ok()) array%data=0_int64
      end if
      if (present(status)) status=local
      return
    end if
    if (axis < -size(input%shape) .or. axis >= size(input%shape)) then
      call set_status(local,FRUMPY_STATUS_INVALID_AXIS,'argsort axis out of bounds')
    else
      if (axis<0_int32) axis=axis+int(size(input%shape),int32)
      count=element_count(input%shape,local)
      if (local%is_ok()) then
        if (count>shiftr(huge(1_int64),3)) &
          call set_status(local,FRUMPY_STATUS_OVERFLOW,'argsort result bytes overflow')
      end if
      if (local%is_ok()) array=owned_descriptor_i64(input%shape,status=local)
    end if
    if (local%is_failure()) then
      if (present(status)) status=local
      return
    end if
    if (array%size()>0_int64) then
      plan=plan_reduction(input%shape,input%strides,axis,.false.,.false.,local)
      output_plan=plan_reduction(array%shape,array%strides,axis,.false.,.false.,local)
      extent=input%shape(axis+1_int32)
      allocate(indices(extent),stat=alloc_stat)
      if (alloc_stat/=0) then
        call set_status(local,FRUMPY_STATUS_ALLOCATION_FAILED, &
          'sort index workspace allocation failed')
      else
        do i=0_int64,plan%count-1_int64
          base=flat_offset(plan%shape(:plan%rank),plan%strides(:plan%rank),input%offset,i)
          do j=1_int64,extent
            indices(j)=j-1_int64
          end do
          call merge_indices(input,base,input%strides(axis+1),indices,work,local)
          if (local%is_failure()) exit
          output_base=flat_offset(output_plan%shape(:output_plan%rank), &
            output_plan%strides(:output_plan%rank),1_int64,i)
          do j=1_int64,extent
            array%data(output_base+(j-1_int64)*array%strides(axis+1))=indices(j)
          end do
        end do
      end if
    end if
    if (local%is_failure()) call array%release()
    if (present(status)) status=local
  end function argsort

  logical function precedes(source,base,step,left,right)
    type(operand), intent(in) :: source
    integer(int64), intent(in) :: base,step,left,right
    real(real64) :: lhs,rhs

    if (source%dtype_id<=3_int32) then
      precedes=integer_value(source,base+left*step)<=integer_value(source,base+right*step)
    else
      lhs=real64_value(source,base+left*step)
      rhs=real64_value(source,base+right*step)
      ! Equal keys stay in original order, including signed zeros and all NaNs.
      if (ieee_is_nan(rhs)) then
        precedes=.true.
      else if (ieee_is_nan(lhs)) then
        precedes=.false.
      else
        precedes=lhs<=rhs
      end if
    end if
  end function precedes

  subroutine merge_indices(source,base,step,indices,work,status)
    type(operand), intent(in) :: source
    integer(int64), intent(in) :: base,step
    integer(int64), intent(inout) :: indices(:)
    integer(int64), allocatable, intent(inout) :: work(:)
    type(frumpy_status), intent(out) :: status
    integer(int64) :: count,first,last,middle,width,i,j,key,left,right,k
    integer :: alloc_stat

    call set_status(status,0_int32)
    count=size(indices,kind=int64)
    first=1_int64
    do while (first<=count)
      last=first+min(32_int64,count-first+1_int64)-1_int64
      do i=first+1_int64,last
        key=indices(i)
        j=i-1_int64
        do while (j>=first)
          if (precedes(source,base,step,indices(j),key)) exit
          indices(j+1_int64)=indices(j)
          j=j-1_int64
        end do
        indices(j+1_int64)=key
      end do
      first=last+1_int64
    end do
    width=32_int64
    do while (width<count)
      first=1_int64
      do while (first<=count-width)
        middle=first+width-1_int64
        last=middle+min(width,count-middle)
        if (.not. precedes(source,base,step,indices(middle),indices(middle+1_int64))) then
          if (.not. allocated(work)) then
            allocate(work(count),stat=alloc_stat)
            if (alloc_stat/=0) then
              call set_status(status,FRUMPY_STATUS_ALLOCATION_FAILED,'sort merge allocation failed')
              return
            end if
          end if
          left=first
          right=middle+1_int64
          do k=first,last
            if (left>middle) then
              work(k)=indices(right)
              right=right+1_int64
            else if (right>last) then
              work(k)=indices(left)
              left=left+1_int64
            else if (precedes(source,base,step,indices(left),indices(right))) then
              work(k)=indices(left)
              left=left+1_int64
            else
              work(k)=indices(right)
              right=right+1_int64
            end if
          end do
          indices(first:last)=work(first:last)
        end if
        first=last+1_int64
      end do
      if (width>=count-width) exit
      width=width*2_int64
    end do
  end subroutine merge_indices

  function sort_bool(source,axis0,status) result(array)
    type(ndarray_bool), target, intent(in) :: source
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_bool) :: array
    type(ndarray_i64) :: indices
    type(frumpy_status) :: local
    integer(int32) :: axis,order
    integer(int64) :: i,position,axis_index

    indices=argsort(source,axis0,local)
    if (local%is_failure()) then
      if (present(status)) status=local
      return
    end if
    if (source%rank==0_int32) then
      call set_status(local,FRUMPY_STATUS_INVALID_AXIS,'sort requires a non-scalar input')
      if (present(status)) status=local
      return
    end if
    axis=-1_int32
    if (present(axis0)) axis=axis0
    if (axis<0_int32) axis=axis+source%rank
    axis=axis+1_int32
    order=FRUMPY_ORDER_C
    if (source%is_f_contiguous .and. .not. source%is_c_contiguous) order=FRUMPY_ORDER_F
    array=owned_descriptor_bool(source%shape,order,local)
    if (local%is_ok()) then
      do i=0_int64,indices%size()-1_int64
        axis_index=modulo(i/indices%strides(axis),source%shape(axis))
        position=flat_offset(source%shape,source%strides,source%offset,i)
        position=position+(indices%data(i+1_int64)-axis_index)*source%strides(axis)
        array%data(flat_offset(array%shape,array%strides,1_int64,i))= &
          merge(1_int8,0_int8,source%data(position)/=0_int8)
      end do
    end if
    if (present(status)) status=local
  end function sort_bool

  function sort_i32(source,axis0,status) result(array)
    type(ndarray_i32), target, intent(in) :: source
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i32) :: array
    type(ndarray_i64) :: indices
    type(frumpy_status) :: local
    integer(int32) :: axis,order
    integer(int64) :: i,position,axis_index

    indices=argsort(source,axis0,local)
    if (local%is_failure()) then
      if (present(status)) status=local
      return
    end if
    if (source%rank==0_int32) then
      call set_status(local,FRUMPY_STATUS_INVALID_AXIS,'sort requires a non-scalar input')
      if (present(status)) status=local
      return
    end if
    axis=-1_int32
    if (present(axis0)) axis=axis0
    if (axis<0_int32) axis=axis+source%rank
    axis=axis+1_int32
    order=FRUMPY_ORDER_C
    if (source%is_f_contiguous .and. .not. source%is_c_contiguous) order=FRUMPY_ORDER_F
    array=owned_descriptor_i32(source%shape,order,local)
    if (local%is_ok()) then
      do i=0_int64,indices%size()-1_int64
        axis_index=modulo(i/indices%strides(axis),source%shape(axis))
        position=flat_offset(source%shape,source%strides,source%offset,i)
        position=position+(indices%data(i+1_int64)-axis_index)*source%strides(axis)
        array%data(flat_offset(array%shape,array%strides,1_int64,i))=source%data(position)
      end do
    end if
    if (present(status)) status=local
  end function sort_i32

  function sort_i64(source,axis0,status) result(array)
    type(ndarray_i64), target, intent(in) :: source
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_i64) :: array
    type(ndarray_i64) :: indices
    type(frumpy_status) :: local
    integer(int32) :: axis,order
    integer(int64) :: i,position,axis_index

    indices=argsort(source,axis0,local)
    if (local%is_failure()) then
      if (present(status)) status=local
      return
    end if
    if (source%rank==0_int32) then
      call set_status(local,FRUMPY_STATUS_INVALID_AXIS,'sort requires a non-scalar input')
      if (present(status)) status=local
      return
    end if
    axis=-1_int32
    if (present(axis0)) axis=axis0
    if (axis<0_int32) axis=axis+source%rank
    axis=axis+1_int32
    order=FRUMPY_ORDER_C
    if (source%is_f_contiguous .and. .not. source%is_c_contiguous) order=FRUMPY_ORDER_F
    array=owned_descriptor_i64(source%shape,order,local)
    if (local%is_ok()) then
      do i=0_int64,indices%size()-1_int64
        axis_index=modulo(i/indices%strides(axis),source%shape(axis))
        position=flat_offset(source%shape,source%strides,source%offset,i)
        position=position+(indices%data(i+1_int64)-axis_index)*source%strides(axis)
        array%data(flat_offset(array%shape,array%strides,1_int64,i))=source%data(position)
      end do
    end if
    if (present(status)) status=local
  end function sort_i64

  function sort_r32(source,axis0,status) result(array)
    type(ndarray_r32), target, intent(in) :: source
    integer(int32), optional, intent(in) :: axis0
    type(frumpy_status), optional, intent(out) :: status
    type(ndarray_r32) :: array
    type(ndarray_i64) :: indices
    type(frumpy_status) :: local
    integer(int32) :: axis,order
    integer(int64) :: i,position,axis_index

    indices=argsort(source,axis0,local)
    if (local%is_failure()) then
      if (present(status)) status=local
      return
    end if
    if (source%rank==0_int32) then
      call set_status(local,FRUMPY_STATUS_INVALID_AXIS,'sort requires a non-scalar input')
      if (present(status)) status=local
      return
    end if
    axis=-1_int32
    if (present(axis0)) axis=axis0
    if (axis<0_int32) axis=axis+source%rank
    axis=axis+1_int32
    order=FRUMPY_ORDER_C
    if (source%is_f_contiguous .and. .not. source%is_c_contiguous) order=FRUMPY_ORDER_F
    array=owned_descriptor_r32(source%shape,order,local)
    if (local%is_ok()) then
      do i=0_int64,indices%size()-1_int64
        axis_index=modulo(i/indices%strides(axis),source%shape(axis))
        position=flat_offset(source%shape,source%strides,source%offset,i)
        position=position+(indices%data(i+1_int64)-axis_index)*source%strides(axis)
        array%data(flat_offset(array%shape,array%strides,1_int64,i))=source%data(position)
      end do
    end if
    if (present(status)) status=local
  end function sort_r32
end module frumpy_sorting
