!> Test-only process bridge: read descriptors, execute Frumpy, emit actual storage.
program differential_driver
  use iso_fortran_env, only: int8, int32, int64, real32, real64
  use frumpy, only: ndarray_r64, ndarray_i64, ndarray_bool, frumpy_status, &
    owned_descriptor_r64, owned_descriptor_bool, view_descriptor_r64, &
    view_descriptor_bool, where_r64, take_r64, &
    concatenate_r64, stack_r64, nonzero_bool, sort_r64, argsort_r64, &
    searchsorted_r64, zeros_r64, full_r64, add_r64, reshape_r64, sum_r64
  use frumpy, only: ndarray_r32, owned_descriptor_r32, view_descriptor_r32, &
    add_r32, subtract_r32, multiply_r32, divide_r32, &
    negate_r32, abs_r32, sqrt_r32, exp_r32, log_r32, sin_r32, cos_r32, &
    sum_r32, prod_r32, mean_r32, min_r32, max_r32
  use frumpy, only: ndarray_i32
  use frumpy, only: owned_descriptor_i32, view_descriptor_i32, &
    add_i32, subtract_i32, multiply_i32, divide_i32
  use frumpy, only: owned_descriptor_i64, view_descriptor_i64, &
    add_i64, subtract_i64, multiply_i64, divide_i64
  implicit none

  call run_case()

contains

  ! Procedure scope makes all test-owned descriptors finalize before process exit.
  subroutine run_case()
    type(ndarray_r64) :: lhs, rhs, output, intermediate, reshaped
    type(ndarray_r32) :: lhs32, rhs32, output32
    type(ndarray_i64) :: indices_output, lhs_i64, rhs_i64
    type(ndarray_i32) :: lhs_i32, rhs_i32, output_i32
    type(ndarray_bool) :: condition
    type(frumpy_status) :: status
    integer(int64), allocatable :: indices(:)
    integer(int32) :: axis0, count, side
    character(len=32) :: operation
    logical :: integer_output

    read (*, *) operation, axis0, side
    integer_output = .false.
    select case (trim(operation))
    case ('add_i32', 'subtract_i32', 'multiply_i32', 'divide_i32')
      call read_i32(lhs_i32)
      call read_i32(rhs_i32)
      select case (operation)
      case ('add_i32')
        output_i32 = add_i32(lhs_i32, rhs_i32, status)
      case ('subtract_i32')
        output_i32 = subtract_i32(lhs_i32, rhs_i32, status)
      case ('multiply_i32')
        output_i32 = multiply_i32(lhs_i32, rhs_i32, status)
      case ('divide_i32')
        output = divide_i32(lhs_i32, rhs_i32, status)
      end select
    case ('add_i64', 'subtract_i64', 'multiply_i64', 'divide_i64')
      call read_i64(lhs_i64)
      call read_i64(rhs_i64)
      select case (operation)
      case ('add_i64')
        indices_output = add_i64(lhs_i64, rhs_i64, status)
      case ('subtract_i64')
        indices_output = subtract_i64(lhs_i64, rhs_i64, status)
      case ('multiply_i64')
        indices_output = multiply_i64(lhs_i64, rhs_i64, status)
      case ('divide_i64')
        output = divide_i64(lhs_i64, rhs_i64, status)
      end select
      integer_output = operation /= 'divide_i64'
    case ('add_r32', 'subtract_r32', 'multiply_r32', 'divide_r32')
      call read_r32(lhs32)
      call read_r32(rhs32)
      select case (trim(operation))
      case ('add_r32')
        output32 = add_r32(lhs32, rhs32, status)
      case ('subtract_r32')
        output32 = subtract_r32(lhs32, rhs32, status)
      case ('multiply_r32')
        output32 = multiply_r32(lhs32, rhs32, status)
      case ('divide_r32')
        output32 = divide_r32(lhs32, rhs32, status)
      end select
    case ('negate_r32', 'abs_r32', 'sqrt_r32', 'exp_r32', 'log_r32', 'sin_r32', 'cos_r32')
      call read_r32(lhs32)
      select case (operation)
      case ('negate_r32')
        output32 = negate_r32(lhs32, status)
      case ('abs_r32')
        output32 = abs_r32(lhs32, status)
      case ('sqrt_r32')
        output32 = sqrt_r32(lhs32, status)
      case ('exp_r32')
        output32 = exp_r32(lhs32, status)
      case ('log_r32')
        output32 = log_r32(lhs32, status)
      case ('sin_r32')
        output32 = sin_r32(lhs32, status)
      case ('cos_r32')
        output32 = cos_r32(lhs32, status)
      end select
    case ('sum_r32', 'prod_r32', 'mean_r32', 'min_r32', 'max_r32')
      call read_r32(lhs32)
      call reduce_float32(operation, lhs32, output32, axis0, side, status)
    case ('vertical_slice')
      lhs = zeros_r64([2_int64, 3_int64], status=status)
      call require_ok(status)
      rhs = full_r64([3_int64], 2.0_real64, status=status)
      call require_ok(status)
      intermediate = add_r64(lhs, rhs, status)
      call require_ok(status)
      reshaped = reshape_r64(intermediate, [3_int64, 2_int64], status)
      call require_ok(status)
      output = sum_r64(reshaped, axis0=1_int32, status=status)
    case ('where')
      call read_bool(condition)
      call read_r64(lhs)
      call read_r64(rhs)
      output = where_r64(condition, lhs, rhs, status)
    case ('nonzero')
      call read_bool(condition)
      indices_output = nonzero_bool(condition, status)
      integer_output = .true.
    case ('take')
      call read_r64(lhs)
      read (*, *) count
      allocate(indices(count))
      read (*, *) indices
      if (side == 1_int32) then
        output = take_r64(lhs, indices, status=status)
      else
        output = take_r64(lhs, indices, axis0, status)
      end if
    case ('concatenate', 'stack')
      call read_r64(lhs)
      call read_r64(rhs)
      if (operation == 'concatenate') then
        output = concatenate_r64([lhs, rhs], axis0, status)
      else
        output = stack_r64([lhs, rhs], axis0, status)
      end if
    case ('sort', 'argsort')
      call read_r64(lhs)
      if (operation == 'sort') then
        output = sort_r64(lhs, axis0, status)
      else
        indices_output = argsort_r64(lhs, axis0, status)
        integer_output = .true.
      end if
    case ('searchsorted')
      call read_r64(lhs)
      call read_r64(rhs)
      indices_output = searchsorted_r64(lhs, rhs, side == 1_int32, status)
      integer_output = .true.
    case default
      error stop 'unknown differential operation'
    end select

    write (*, '(i0)') status%code
    if (status%is_failure()) then
      write (*, '(a)') trim(status%message)
    else if (index(operation, '_r32') > 0) then
      if (associated(output32%data, lhs32%data)) error stop 'result aliases lhs'
      if (associated(output32%data, rhs32%data)) error stop 'result aliases rhs'
      call emit_metadata(output32%shape, output32%strides, output32%offset, &
        output32%is_c_contiguous, output32%is_f_contiguous, output32%owns_data)
      write (*, '(*(es18.9e3,1x))') output32%data
    else if (index(operation, '_i32') > 0 .and. operation /= 'divide_i32') then
      if (associated(output_i32%data, lhs_i32%data)) error stop 'result aliases lhs'
      if (associated(output_i32%data, rhs_i32%data)) error stop 'result aliases rhs'
      call emit_metadata(output_i32%shape, output_i32%strides, output_i32%offset, &
        output_i32%is_c_contiguous, output_i32%is_f_contiguous, output_i32%owns_data)
      write (*, '(*(i0,1x))') output_i32%data
    else if (integer_output) then
      if (associated(indices_output%data, lhs_i64%data)) error stop 'result aliases lhs'
      if (associated(indices_output%data, rhs_i64%data)) error stop 'result aliases rhs'
      call emit_metadata(indices_output%shape, indices_output%strides, indices_output%offset, &
        indices_output%is_c_contiguous, indices_output%is_f_contiguous, indices_output%owns_data)
      write (*, '(*(i0,1x))') indices_output%data
    else
      ! These operations promise independent results; sharing is a test failure.
      if (operation /= 'vertical_slice') then
        if (associated(output%data, lhs%data)) error stop 'result aliases lhs'
        if (associated(output%data, rhs%data)) error stop 'result aliases rhs'
      end if
      call emit_metadata(output%shape, output%strides, output%offset, &
        output%is_c_contiguous, output%is_f_contiguous, output%owns_data)
      write (*, '(*(es26.17e3,1x))') output%data
    end if
  end subroutine run_case

  subroutine reduce_float32(operation, source, output, axis0, flags, status)
    character(len=*), intent(in) :: operation
    type(ndarray_r32), intent(in) :: source
    type(ndarray_r32), intent(out) :: output
    integer(int32), intent(in) :: axis0, flags
    type(frumpy_status), intent(out) :: status
    integer(int32), allocatable :: selected_axis
    logical :: keepdims

    ! An unallocated allocatable actual denotes an absent optional argument.
    if (.not. btest(flags, 1)) then
      allocate(selected_axis)
      selected_axis = axis0
    end if
    keepdims = btest(flags, 0)
    select case (operation)
    case ('sum_r32')
      output = sum_r32(source, axis0=selected_axis, keepdims=keepdims, status=status)
    case ('prod_r32')
      output = prod_r32(source, axis0=selected_axis, keepdims=keepdims, status=status)
    case ('mean_r32')
      output = mean_r32(source, axis0=selected_axis, keepdims=keepdims, status=status)
    case ('min_r32')
      output = min_r32(source, axis0=selected_axis, keepdims=keepdims, status=status)
    case ('max_r32')
      output = max_r32(source, axis0=selected_axis, keepdims=keepdims, status=status)
    end select
  end subroutine reduce_float32

  subroutine read_metadata(shape, strides, offset, storage_count)
    integer(int64), allocatable, intent(out) :: shape(:), strides(:)
    integer(int64), intent(out) :: offset, storage_count
    integer(int32) :: rank

    read (*, *) rank, offset, storage_count
    allocate(shape(rank), strides(rank))
    read (*, *) shape
    read (*, *) strides
  end subroutine read_metadata

  subroutine read_r64(array)
    type(ndarray_r64), intent(out) :: array
    type(ndarray_r64) :: backing
    integer(int64), allocatable :: shape(:), strides(:)
    integer(int64) :: offset, storage_count
    type(frumpy_status) :: read_status

    call read_metadata(shape, strides, offset, storage_count)
    backing = owned_descriptor_r64([storage_count], status=read_status)
    call require_ok(read_status)
    read (*, *) backing%data
    array = view_descriptor_r64(backing, shape, strides, offset, read_status)
    call require_ok(read_status)
  end subroutine read_r64

  subroutine read_r32(array)
    type(ndarray_r32), intent(out) :: array
    type(ndarray_r32) :: backing
    integer(int64), allocatable :: shape(:), strides(:)
    integer(int64) :: offset, storage_count
    type(frumpy_status) :: read_status

    call read_metadata(shape, strides, offset, storage_count)
    backing = owned_descriptor_r32([storage_count], status=read_status)
    call require_ok(read_status)
    read (*, *) backing%data
    array = view_descriptor_r32(backing, shape, strides, offset, read_status)
    call require_ok(read_status)
  end subroutine read_r32

  subroutine read_i32(array)
    type(ndarray_i32), intent(out) :: array
    type(ndarray_i32) :: backing
    integer(int64), allocatable :: shape(:), strides(:)
    integer(int64) :: offset, storage_count
    type(frumpy_status) :: read_status

    call read_metadata(shape, strides, offset, storage_count)
    backing = owned_descriptor_i32([storage_count], status=read_status)
    call require_ok(read_status)
    read (*, *) backing%data
    array = view_descriptor_i32(backing, shape, strides, offset, read_status)
    call require_ok(read_status)
  end subroutine read_i32

  subroutine read_i64(array)
    type(ndarray_i64), intent(out) :: array
    type(ndarray_i64) :: backing
    integer(int64), allocatable :: shape(:), strides(:)
    integer(int64) :: offset, storage_count
    type(frumpy_status) :: read_status

    call read_metadata(shape, strides, offset, storage_count)
    backing = owned_descriptor_i64([storage_count], status=read_status)
    call require_ok(read_status)
    read (*, *) backing%data
    array = view_descriptor_i64(backing, shape, strides, offset, read_status)
    call require_ok(read_status)
  end subroutine read_i64


  subroutine read_bool(array)
    type(ndarray_bool), intent(out) :: array
    type(ndarray_bool) :: backing
    integer(int64), allocatable :: shape(:), strides(:)
    integer(int64) :: offset, storage_count
    type(frumpy_status) :: read_status

    call read_metadata(shape, strides, offset, storage_count)
    backing = owned_descriptor_bool([storage_count], status=read_status)
    call require_ok(read_status)
    read (*, *) backing%data
    array = view_descriptor_bool(backing, shape, strides, offset, read_status)
    call require_ok(read_status)
  end subroutine read_bool

  subroutine emit_metadata(shape, strides, offset, c_order, f_order, owns_data)
    integer(int64), intent(in) :: shape(:), strides(:), offset
    logical, intent(in) :: c_order, f_order, owns_data

    write (*, '(i0)') size(shape)
    write (*, '(*(i0,1x))') shape
    write (*, '(*(i0,1x))') strides
    write (*, '(i0,3(1x,l1))') offset, c_order, f_order, owns_data
  end subroutine emit_metadata

  subroutine require_ok(actual_status)
    type(frumpy_status), intent(in) :: actual_status

    if (actual_status%is_failure()) then
      write (*, '(a)') trim(actual_status%message)
      error stop 'differential input or intermediate failed'
    end if
  end subroutine require_ok
end program differential_driver
