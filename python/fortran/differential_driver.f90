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
  use frumpy, only: add, subtract, multiply, divide, binary_result_dtype
  use frumpy, only: dot, outer, matmul
  use frumpy_promotion, only: promote_dtypes
  use frumpy, only: equal, not_equal, less, less_equal, greater, greater_equal, &
    logical_and_bool, logical_or_bool, logical_xor_bool, logical_not_bool
  use frumpy, only: sum_i32, prod_i32, min_i32, max_i32, mean_i32, &
    sum_i64, prod_i64, min_i64, max_i64, mean_i64, all_bool, any_bool
  use frumpy, only: mask_select_r64, assign_r64, mask_select, assign, mask_assign
  use frumpy, only: where, take, concatenate, stack
  use frumpy, only: searchsorted
  use frumpy, only: sort, argsort
  use frumpy, only: argmin, argmax
  use frumpy, only: astype
  use frumpy, only: random_generator, uniform_r64, normal_r64
  use frumpy, only: vector_norm_r64, matrix_norm_r64, vector_norm_r32, matrix_norm_r32
  use frumpy, only: matmul_r32, solve_r32, dot_r32, outer_r32
  use frumpy, only: matmul_r64, solve_r64, outer_r64, dot_r64
  use frumpy, only: copy_bool, asarray_bool, ascontiguousarray_bool, &
    zeros_bool, ones_bool, full_bool
  use frumpy, only: copy_i32, asarray_i32, ascontiguousarray_i32, &
    zeros_i32, ones_i32, full_i32
  use frumpy, only: copy_i64, asarray_i64, ascontiguousarray_i64, &
    zeros_i64, ones_i64, full_i64
  use frumpy, only: copy_r32, asarray_r32, ascontiguousarray_r32, &
    zeros_r32, ones_r32, full_r32
  use frumpy, only: reshape_bool, ravel_bool, flatten_bool, transpose_bool, &
    swapaxes_bool, squeeze_bool, expand_dims_bool, slice_bool
  use frumpy, only: reshape_i32, ravel_i32, flatten_i32, transpose_i32, &
    swapaxes_i32, squeeze_i32, expand_dims_i32, slice_i32
  use frumpy, only: reshape_i64, ravel_i64, flatten_i64, transpose_i64, &
    swapaxes_i64, squeeze_i64, expand_dims_i64, slice_i64
  use frumpy, only: reshape_r32, ravel_r32, flatten_r32, transpose_r32, &
    swapaxes_r32, squeeze_r32, expand_dims_r32, slice_r32
  use frumpy, only: reshape_r64, ravel_r64, flatten_r64, transpose_r64, &
    swapaxes_r64, squeeze_r64, expand_dims_r64, slice_r64
  use frumpy, only: slice_spec, slice_all, slice_range
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
    type(random_generator) :: generator
    integer(int64) :: seed
    logical :: integer_output

    read (*, *) operation, axis0, side
    integer_output = .false.
    if (index(operation, 'select_') == 1) then
      call run_selection(operation(8:), axis0, side)
      return
    end if
    if (operation == 'search_typed') then
      call run_search(axis0,side)
      return
    end if
    if (index(operation, 'order_') == 1) then
      call run_order(operation(7:),axis0,side)
      return
    end if
    if (index(operation, 'reduce_') == 1) then
      call run_reduce(operation(8:), axis0, side)
      return
    end if
    if (index(operation, 'compare_') == 1) then
      call run_compare(operation(9:), axis0, side)
      return
    end if
    if (operation == 'cast_array') then
      call run_cast(axis0, side)
      return
    end if
    if (index(operation, 'view_') == 1) then
      call run_views(operation(6:), axis0)
      return
    end if
    if (index(operation, 'construct_') == 1) then
      call run_constructors(operation(11:), axis0, side)
      return
    end if
    select case (trim(operation))
    case ('mixed_add', 'mixed_subtract', 'mixed_multiply', 'mixed_divide', &
        'mixed_dot', 'mixed_outer', 'mixed_matmul')
      call run_mixed(operation(7:), axis0, side)
      return
    case ('mask_select_r64')
      call read_r64(lhs)
      call read_bool(condition)
      output = mask_select_r64(lhs, condition, status)
    case ('assign_r64')
      call read_r64(lhs)
      call read_r64(rhs)
      call assign_r64(lhs, rhs, status)
      write (*, '(i0)') status%code
      if (status%is_ok()) then
        call emit_metadata(lhs%shape, lhs%strides, lhs%offset, &
          lhs%is_c_contiguous, lhs%is_f_contiguous, lhs%owns_data)
        write (*, '(*(es26.17e3,1x))') lhs%data
      end if
      return
    case ('uniform_r64', 'normal_r64')
      call read_r64(lhs)
      read (*, *) count
      read (*, *) seed
      call generator%seed(seed)
      if (operation == 'uniform_r64') then
        output = uniform_r64(generator, lhs%shape, status)
      else
        output = normal_r64(generator, lhs%shape, status)
      end if
    case ('vector_norm_r64', 'matrix_norm_r64', 'matrix_norm_axes')
      call read_r64(lhs)
      if (operation == 'matrix_norm_axes') then
        read (*, *) count
        allocate(indices(count))
        read (*, *) indices
        output = matrix_norm_r64(lhs, int(indices, int32), side == 1, status)
      else if (operation == 'matrix_norm_r64') then
        output = matrix_norm_r64(lhs, keepdims=side == 1, status=status)
      else if (axis0 == 99) then
        output = vector_norm_r64(lhs, keepdims=side == 1, status=status)
      else
        output = vector_norm_r64(lhs, axis0, side == 1, status)
      end if
    case ('vector_norm_r32', 'matrix_norm_r32', 'matrix_norm_axes_r32')
      call read_r32(lhs32)
      if (operation == 'matrix_norm_axes_r32') then
        read (*, *) count
        allocate(indices(count))
        read (*, *) indices
        output32 = matrix_norm_r32(lhs32, int(indices, int32), side == 1, status)
      else if (operation == 'matrix_norm_r32') then
        output32 = matrix_norm_r32(lhs32, keepdims=side == 1, status=status)
      else if (axis0 == 99) then
        output32 = vector_norm_r32(lhs32, keepdims=side == 1, status=status)
      else
        output32 = vector_norm_r32(lhs32, axis0, side == 1, status)
      end if
    case ('matmul_r32', 'solve_r32', 'dot_r32', 'outer_r32')
      call read_r32(lhs32)
      call read_r32(rhs32)
      if (operation == 'matmul_r32') then
        output32 = matmul_r32(lhs32, rhs32, status)
      else if (operation == 'dot_r32') then
        output32 = dot_r32(lhs32, rhs32, status)
      else if (operation == 'outer_r32') then
        output32 = outer_r32(lhs32, rhs32, status)
      else
        output32 = solve_r32(lhs32, rhs32, status)
      end if
    case ('matmul_r64', 'solve_r64', 'outer_r64', 'dot_r64')
      call read_r64(lhs)
      call read_r64(rhs)
      if (operation == 'matmul_r64') then
        output = matmul_r64(lhs, rhs, status)
      else if (operation == 'dot_r64') then
        output = dot_r64(lhs, rhs, status)
      else if (operation == 'outer_r64') then
        output = outer_r64(lhs, rhs, status)
      else
        output = solve_r64(lhs, rhs, status)
      end if
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

  subroutine run_mixed(operation, lhs_dtype, rhs_dtype)
    character(len=*), intent(in) :: operation
    integer(int32), intent(in) :: lhs_dtype, rhs_dtype
    class(*), allocatable :: left, right, output
    type(frumpy_status) :: status
    integer(int32) :: output_dtype

    call allocate_mixed(left, lhs_dtype)
    call allocate_mixed(right, rhs_dtype)
    call read_mixed(left)
    call read_mixed(right)
    if (operation == 'dot' .or. operation == 'outer' .or. operation == 'matmul') then
      output_dtype = promote_dtypes(lhs_dtype, rhs_dtype, status)
    else
      output_dtype = binary_result_dtype(lhs_dtype, rhs_dtype, operation, status)
    end if
    if (status%is_failure()) then
      write (*, '(i0)') status%code
      write (*, '(a)') trim(status%message)
      return
    end if
    call allocate_mixed(output, output_dtype)
    select case (operation)
    case ('dot')
      call dot(left, right, output, status)
    case ('outer')
      call outer(left, right, output, status)
    case ('matmul')
      call matmul(left, right, output, status)
    case ('add')
      call add(left, right, output, status)
    case ('subtract')
      call subtract(left, right, output, status)
    case ('multiply')
      call multiply(left, right, output, status)
    case ('divide')
      call divide(left, right, output, status)
    end select
    write (*, '(i0)') status%code
    if (status%is_failure()) then
      write (*, '(a)') trim(status%message)
      return
    end if
    call emit_mixed(output)
  end subroutine run_mixed

  subroutine emit_mixed(output)
    class(*), intent(in) :: output
    select type (output)
    type is (ndarray_bool)
      write (*, '(i0)') 1
      call emit_metadata(output%shape, output%strides, output%offset, &
        output%is_c_contiguous, output%is_f_contiguous, output%owns_data)
      write (*, '(*(i0,1x))') output%data
    type is (ndarray_i32)
      write (*, '(i0)') 2
      call emit_metadata(output%shape, output%strides, output%offset, &
        output%is_c_contiguous, output%is_f_contiguous, output%owns_data)
      write (*, '(*(i0,1x))') output%data
    type is (ndarray_i64)
      write (*, '(i0)') 3
      call emit_metadata(output%shape, output%strides, output%offset, &
        output%is_c_contiguous, output%is_f_contiguous, output%owns_data)
      write (*, '(*(i0,1x))') output%data
    type is (ndarray_r32)
      write (*, '(i0)') 4
      call emit_metadata(output%shape, output%strides, output%offset, &
        output%is_c_contiguous, output%is_f_contiguous, output%owns_data)
      write (*, '(*(es18.9e3,1x))') output%data
    type is (ndarray_r64)
      write (*, '(i0)') 5
      call emit_metadata(output%shape, output%strides, output%offset, &
        output%is_c_contiguous, output%is_f_contiguous, output%owns_data)
      write (*, '(*(es26.17e3,1x))') output%data
    end select
  end subroutine emit_mixed

  subroutine run_constructors(operation, dtype, order)
    character(len=*), intent(in) :: operation
    integer(int32), intent(in) :: dtype, order
    type(frumpy_status) :: status
    type(ndarray_bool) :: source_bool, result_bool, flat_bool
    type(ndarray_i32) :: source_i32, result_i32, flat_i32
    type(ndarray_i64) :: source_i64, result_i64, flat_i64
    type(ndarray_r32) :: source_r32, result_r32, flat_r32

    select case (dtype)
    case (1)
      call read_bool(source_bool)
      select case (operation)
      case ('copy')
        result_bool = copy_bool(source_bool, order, status)
      case ('ascontiguousarray')
        result_bool = ascontiguousarray_bool(source_bool, status)
      case ('asarray')
        flat_bool = copy_bool(source_bool)
        result_bool = asarray_bool(flat_bool%data /= 0_int8, &
          source_bool%shape, order, status)
      case ('zeros')
        result_bool = zeros_bool(source_bool%shape, order, status)
      case ('ones')
        result_bool = ones_bool(source_bool%shape, order, status)
      case ('full')
        result_bool = full_bool(source_bool%shape, .true., order, status)
      end select
      write (*, '(i0)') status%code
      if (status%is_ok()) call emit_mixed(result_bool)
    case (2)
      call read_i32(source_i32)
      select case (operation)
      case ('copy')
        result_i32 = copy_i32(source_i32, order, status)
      case ('ascontiguousarray')
        result_i32 = ascontiguousarray_i32(source_i32, status)
      case ('asarray')
        flat_i32 = copy_i32(source_i32)
        result_i32 = asarray_i32(flat_i32%data, &
          source_i32%shape, order, status)
      case ('zeros')
        result_i32 = zeros_i32(source_i32%shape, order, status)
      case ('ones')
        result_i32 = ones_i32(source_i32%shape, order, status)
      case ('full')
        result_i32 = full_i32(source_i32%shape, 7_int32, order, status)
      end select
      write (*, '(i0)') status%code
      if (status%is_ok()) call emit_mixed(result_i32)
    case (3)
      call read_i64(source_i64)
      select case (operation)
      case ('copy')
        result_i64 = copy_i64(source_i64, order, status)
      case ('ascontiguousarray')
        result_i64 = ascontiguousarray_i64(source_i64, status)
      case ('asarray')
        flat_i64 = copy_i64(source_i64)
        result_i64 = asarray_i64(flat_i64%data, &
          source_i64%shape, order, status)
      case ('zeros')
        result_i64 = zeros_i64(source_i64%shape, order, status)
      case ('ones')
        result_i64 = ones_i64(source_i64%shape, order, status)
      case ('full')
        result_i64 = full_i64(source_i64%shape, 7_int64, order, status)
      end select
      write (*, '(i0)') status%code
      if (status%is_ok()) call emit_mixed(result_i64)
    case (4)
      call read_r32(source_r32)
      select case (operation)
      case ('copy')
        result_r32 = copy_r32(source_r32, order, status)
      case ('ascontiguousarray')
        result_r32 = ascontiguousarray_r32(source_r32, status)
      case ('asarray')
        flat_r32 = copy_r32(source_r32)
        result_r32 = asarray_r32(flat_r32%data, &
          source_r32%shape, order, status)
      case ('zeros')
        result_r32 = zeros_r32(source_r32%shape, order, status)
      case ('ones')
        result_r32 = ones_r32(source_r32%shape, order, status)
      case ('full')
        result_r32 = full_r32(source_r32%shape, 7.0_real32, order, status)
      end select
      write (*, '(i0)') status%code
      if (status%is_ok()) call emit_mixed(result_r32)
    end select
  end subroutine run_constructors

  subroutine run_views(operation, dtype)
    character(len=*), intent(in) :: operation
    integer(int32), intent(in) :: dtype
    type(frumpy_status) :: status
    type(slice_spec), allocatable :: specs(:)
    type(ndarray_bool) :: source_bool, result_bool
    type(ndarray_i32) :: source_i32, result_i32
    type(ndarray_i64) :: source_i64, result_i64
    type(ndarray_r32) :: source_r32, result_r32
    type(ndarray_r64) :: source_r64, result_r64

    select case (dtype)
    case (1)
      call read_bool(source_bool)
      select case (operation)
      case ('reshape')
        result_bool = reshape_bool(source_bool, [source_bool%size()], status)
      case ('ravel')
        result_bool = ravel_bool(source_bool, status)
      case ('flatten')
        result_bool = flatten_bool(source_bool, status)
      case ('transpose')
        result_bool = transpose_bool(source_bool, status)
      case ('swapaxes')
        result_bool = swapaxes_bool(source_bool, 0_int32, max(0_int32, source_bool%rank-1), status)
      case ('squeeze')
        result_bool = squeeze_bool(source_bool, status=status)
      case ('expand_dims')
        result_bool = expand_dims_bool(source_bool, 0_int32, status)
      case ('slice')
        allocate(specs(source_bool%rank))
        specs = slice_all()
        if (source_bool%rank > 0) specs(source_bool%rank) = &
          slice_range(source_bool%shape(source_bool%rank)-1_int64, -1_int64, -1_int64)
        result_bool = slice_bool(source_bool, specs, status)
      end select
      write (*, '(i0)') status%code
      if (status%is_ok()) call emit_mixed(result_bool)
    case (2)
      call read_i32(source_i32)
      select case (operation)
      case ('reshape')
        result_i32 = reshape_i32(source_i32, [source_i32%size()], status)
      case ('ravel')
        result_i32 = ravel_i32(source_i32, status)
      case ('flatten')
        result_i32 = flatten_i32(source_i32, status)
      case ('transpose')
        result_i32 = transpose_i32(source_i32, status)
      case ('swapaxes')
        result_i32 = swapaxes_i32(source_i32, 0_int32, max(0_int32, source_i32%rank-1), status)
      case ('squeeze')
        result_i32 = squeeze_i32(source_i32, status=status)
      case ('expand_dims')
        result_i32 = expand_dims_i32(source_i32, 0_int32, status)
      case ('slice')
        allocate(specs(source_i32%rank))
        specs = slice_all()
        if (source_i32%rank > 0) specs(source_i32%rank) = &
          slice_range(source_i32%shape(source_i32%rank)-1_int64, -1_int64, -1_int64)
        result_i32 = slice_i32(source_i32, specs, status)
      end select
      write (*, '(i0)') status%code
      if (status%is_ok()) call emit_mixed(result_i32)
    case (3)
      call read_i64(source_i64)
      select case (operation)
      case ('reshape')
        result_i64 = reshape_i64(source_i64, [source_i64%size()], status)
      case ('ravel')
        result_i64 = ravel_i64(source_i64, status)
      case ('flatten')
        result_i64 = flatten_i64(source_i64, status)
      case ('transpose')
        result_i64 = transpose_i64(source_i64, status)
      case ('swapaxes')
        result_i64 = swapaxes_i64(source_i64, 0_int32, max(0_int32, source_i64%rank-1), status)
      case ('squeeze')
        result_i64 = squeeze_i64(source_i64, status=status)
      case ('expand_dims')
        result_i64 = expand_dims_i64(source_i64, 0_int32, status)
      case ('slice')
        allocate(specs(source_i64%rank))
        specs = slice_all()
        if (source_i64%rank > 0) specs(source_i64%rank) = &
          slice_range(source_i64%shape(source_i64%rank)-1_int64, -1_int64, -1_int64)
        result_i64 = slice_i64(source_i64, specs, status)
      end select
      write (*, '(i0)') status%code
      if (status%is_ok()) call emit_mixed(result_i64)
    case (4)
      call read_r32(source_r32)
      select case (operation)
      case ('reshape')
        result_r32 = reshape_r32(source_r32, [source_r32%size()], status)
      case ('ravel')
        result_r32 = ravel_r32(source_r32, status)
      case ('flatten')
        result_r32 = flatten_r32(source_r32, status)
      case ('transpose')
        result_r32 = transpose_r32(source_r32, status)
      case ('swapaxes')
        result_r32 = swapaxes_r32(source_r32, 0_int32, max(0_int32, source_r32%rank-1), status)
      case ('squeeze')
        result_r32 = squeeze_r32(source_r32, status=status)
      case ('expand_dims')
        result_r32 = expand_dims_r32(source_r32, 0_int32, status)
      case ('slice')
        allocate(specs(source_r32%rank))
        specs = slice_all()
        if (source_r32%rank > 0) specs(source_r32%rank) = &
          slice_range(source_r32%shape(source_r32%rank)-1_int64, -1_int64, -1_int64)
        result_r32 = slice_r32(source_r32, specs, status)
      end select
      write (*, '(i0)') status%code
      if (status%is_ok()) call emit_mixed(result_r32)
    case (5)
      call read_r64(source_r64)
      select case (operation)
      case ('reshape')
        result_r64 = reshape_r64(source_r64, [source_r64%size()], status)
      case ('ravel')
        result_r64 = ravel_r64(source_r64, status)
      case ('flatten')
        result_r64 = flatten_r64(source_r64, status)
      case ('transpose')
        result_r64 = transpose_r64(source_r64, status)
      case ('swapaxes')
        result_r64 = swapaxes_r64(source_r64, 0_int32, max(0_int32, source_r64%rank-1), status)
      case ('squeeze')
        result_r64 = squeeze_r64(source_r64, status=status)
      case ('expand_dims')
        result_r64 = expand_dims_r64(source_r64, 0_int32, status)
      case ('slice')
        allocate(specs(source_r64%rank))
        specs = slice_all()
        if (source_r64%rank > 0) specs(source_r64%rank) = &
          slice_range(source_r64%shape(source_r64%rank)-1_int64, -1_int64, -1_int64)
        result_r64 = slice_r64(source_r64, specs, status)
      end select
      write (*, '(i0)') status%code
      if (status%is_ok()) call emit_mixed(result_r64)
    end select
  end subroutine run_views

  subroutine run_cast(source_dtype, target_dtype)
    integer(int32), intent(in) :: source_dtype, target_dtype
    class(*), allocatable :: source, result
    type(frumpy_status) :: status
    integer(int32) :: count, mode

    call allocate_mixed(source, source_dtype)
    call allocate_mixed(result, target_dtype)
    call read_mixed(source)
    read (*, *) count
    read (*, *) mode
    call astype(source, result, mode, status)
    write (*, '(i0)') status%code
    if (status%is_ok()) call emit_mixed(result)
  end subroutine run_cast

  subroutine run_compare(operation, left_dtype, right_dtype)
    character(len=*), intent(in) :: operation
    integer(int32), intent(in) :: left_dtype, right_dtype
    class(*), allocatable :: left, right
    type(ndarray_bool) :: result
    type(frumpy_status) :: status

    call allocate_mixed(left, left_dtype)
    call allocate_mixed(right, right_dtype)
    call read_mixed(left)
    call read_mixed(right)
    select case (operation)
    case ('equal')
      result = equal(left, right, status)
    case ('not_equal')
      result = not_equal(left, right, status)
    case ('less')
      result = less(left, right, status)
    case ('less_equal')
      result = less_equal(left, right, status)
    case ('greater')
      result = greater(left, right, status)
    case ('greater_equal')
      result = greater_equal(left, right, status)
    case ('logical_and')
      result = logical_and_bool(left, right, status)
    case ('logical_or')
      result = logical_or_bool(left, right, status)
    case ('logical_xor')
      result = logical_xor_bool(left, right, status)
    case ('logical_not')
      result = logical_not_bool(left, status)
    end select
    write (*, '(i0)') status%code
    if (status%is_ok()) call emit_mixed(result)
  end subroutine run_compare

  subroutine run_selection(operation, dtype, axis)
    character(len=*), intent(in) :: operation
    integer(int32), intent(in) :: dtype, axis
    type(ndarray_bool) :: condition
    type(frumpy_status) :: status
    integer(int64), allocatable :: indices(:)
    integer :: count

    if (operation == 'where' .or. operation == 'mask' .or. operation == 'mask_assign') call read_mixed(condition)
    select case (dtype)
    case (1)
      block
        type(ndarray_bool) :: inputs(2), output

        call read_mixed(inputs(1))
        select case (operation)
        case ('mask')
          output = mask_select(inputs(1), condition, status)
        case ('take', 'take_flat')
          read (*, *) count
          allocate(indices(count))
          read (*, *) indices
          if (operation == 'take_flat') then
            output = take(inputs(1), indices, status=status)
          else
            output = take(inputs(1), indices, axis, status)
          end if
        case default
          call read_mixed(inputs(2))
          select case (operation)
          case ('assign')
            call assign(inputs(1), inputs(2), status)
            if (status%is_ok()) call output%share_from(inputs(1), status)
          case ('mask_assign')
            call mask_assign(inputs(1), condition, inputs(2), status)
            if (status%is_ok()) call output%share_from(inputs(1), status)
          case ('where')
            output = where(condition, inputs(1), inputs(2), status)
          case ('concatenate')
            output = concatenate(inputs, axis, status)
          case ('stack')
            output = stack(inputs, axis, status)
          end select
        end select
        write (*, '(i0)') status%code
        if (status%is_ok()) call emit_mixed(output)
        call inputs(1)%release()
        call inputs(2)%release()
      end block
    case (2)
      block
        type(ndarray_i32) :: inputs(2), output

        call read_mixed(inputs(1))
        select case (operation)
        case ('mask')
          output = mask_select(inputs(1), condition, status)
        case ('take', 'take_flat')
          read (*, *) count
          allocate(indices(count))
          read (*, *) indices
          if (operation == 'take_flat') then
            output = take(inputs(1), indices, status=status)
          else
            output = take(inputs(1), indices, axis, status)
          end if
        case default
          call read_mixed(inputs(2))
          select case (operation)
          case ('assign')
            call assign(inputs(1), inputs(2), status)
            if (status%is_ok()) call output%share_from(inputs(1), status)
          case ('mask_assign')
            call mask_assign(inputs(1), condition, inputs(2), status)
            if (status%is_ok()) call output%share_from(inputs(1), status)
          case ('where')
            output = where(condition, inputs(1), inputs(2), status)
          case ('concatenate')
            output = concatenate(inputs, axis, status)
          case ('stack')
            output = stack(inputs, axis, status)
          end select
        end select
        write (*, '(i0)') status%code
        if (status%is_ok()) call emit_mixed(output)
        call inputs(1)%release()
        call inputs(2)%release()
      end block
    case (3)
      block
        type(ndarray_i64) :: inputs(2), output

        call read_mixed(inputs(1))
        select case (operation)
        case ('mask')
          output = mask_select(inputs(1), condition, status)
        case ('take', 'take_flat')
          read (*, *) count
          allocate(indices(count))
          read (*, *) indices
          if (operation == 'take_flat') then
            output = take(inputs(1), indices, status=status)
          else
            output = take(inputs(1), indices, axis, status)
          end if
        case default
          call read_mixed(inputs(2))
          select case (operation)
          case ('assign')
            call assign(inputs(1), inputs(2), status)
            if (status%is_ok()) call output%share_from(inputs(1), status)
          case ('mask_assign')
            call mask_assign(inputs(1), condition, inputs(2), status)
            if (status%is_ok()) call output%share_from(inputs(1), status)
          case ('where')
            output = where(condition, inputs(1), inputs(2), status)
          case ('concatenate')
            output = concatenate(inputs, axis, status)
          case ('stack')
            output = stack(inputs, axis, status)
          end select
        end select
        write (*, '(i0)') status%code
        if (status%is_ok()) call emit_mixed(output)
        call inputs(1)%release()
        call inputs(2)%release()
      end block
    case (4)
      block
        type(ndarray_r32) :: inputs(2), output

        call read_mixed(inputs(1))
        select case (operation)
        case ('mask')
          output = mask_select(inputs(1), condition, status)
        case ('take', 'take_flat')
          read (*, *) count
          allocate(indices(count))
          read (*, *) indices
          if (operation == 'take_flat') then
            output = take(inputs(1), indices, status=status)
          else
            output = take(inputs(1), indices, axis, status)
          end if
        case default
          call read_mixed(inputs(2))
          select case (operation)
          case ('assign')
            call assign(inputs(1), inputs(2), status)
            if (status%is_ok()) call output%share_from(inputs(1), status)
          case ('mask_assign')
            call mask_assign(inputs(1), condition, inputs(2), status)
            if (status%is_ok()) call output%share_from(inputs(1), status)
          case ('where')
            output = where(condition, inputs(1), inputs(2), status)
          case ('concatenate')
            output = concatenate(inputs, axis, status)
          case ('stack')
            output = stack(inputs, axis, status)
          end select
        end select
        write (*, '(i0)') status%code
        if (status%is_ok()) call emit_mixed(output)
        call inputs(1)%release()
        call inputs(2)%release()
      end block
    case (5)
      block
        type(ndarray_r64) :: inputs(2), output

        call read_mixed(inputs(1))
        select case (operation)
        case ('mask')
          output = mask_select(inputs(1), condition, status)
        case ('take', 'take_flat')
          read (*, *) count
          allocate(indices(count))
          read (*, *) indices
          if (operation == 'take_flat') then
            output = take(inputs(1), indices, status=status)
          else
            output = take(inputs(1), indices, axis, status)
          end if
        case default
          call read_mixed(inputs(2))
          select case (operation)
          case ('assign')
            call assign(inputs(1), inputs(2), status)
            if (status%is_ok()) call output%share_from(inputs(1), status)
          case ('mask_assign')
            call mask_assign(inputs(1), condition, inputs(2), status)
            if (status%is_ok()) call output%share_from(inputs(1), status)
          case ('where')
            output = where(condition, inputs(1), inputs(2), status)
          case ('concatenate')
            output = concatenate(inputs, axis, status)
          case ('stack')
            output = stack(inputs, axis, status)
          end select
        end select
        write (*, '(i0)') status%code
        if (status%is_ok()) call emit_mixed(output)
        call inputs(1)%release()
        call inputs(2)%release()
      end block
    end select
  end subroutine run_selection

  subroutine run_search(dtype,side)
    integer(int32), intent(in) :: dtype,side
    class(*), allocatable :: source,queries
    type(ndarray_i64) :: output
    type(frumpy_status) :: status

    call allocate_mixed(source,dtype)
    call allocate_mixed(queries,dtype)
    call read_mixed(source)
    call read_mixed(queries)
    output=searchsorted(source,queries,side==1,status)
    write (*,'(i0)') status%code
    if (status%is_ok()) call emit_mixed(output)
  end subroutine run_search

  subroutine run_order(operation,dtype,axis)
    character(len=*), intent(in) :: operation
    integer(int32), intent(in) :: dtype,axis
    class(*), allocatable :: source,output
    type(ndarray_i64) :: indices
    type(frumpy_status) :: status

    call allocate_mixed(source,dtype)
    call read_mixed(source)
    if (operation=='argsort') then
      indices=argsort(source,axis,status)
      write (*,'(i0)') status%code
      if (status%is_ok()) call emit_mixed(indices)
      return
    end if
    call allocate_mixed(output,dtype)
    select type (source)
    type is (ndarray_bool)
      select type (output)
      type is (ndarray_bool)
        output=sort(source,axis,status)
      end select
    type is (ndarray_i32)
      select type (output)
      type is (ndarray_i32)
        output=sort(source,axis,status)
      end select
    type is (ndarray_i64)
      select type (output)
      type is (ndarray_i64)
        output=sort(source,axis,status)
      end select
    type is (ndarray_r32)
      select type (output)
      type is (ndarray_r32)
        output=sort(source,axis,status)
      end select
    type is (ndarray_r64)
      select type (output)
      type is (ndarray_r64)
        output=sort(source,axis,status)
      end select
    end select
    write (*,'(i0)') status%code
    if (status%is_ok()) call emit_mixed(output)
  end subroutine run_order

  subroutine run_reduce(operation, dtype, selected_axis)
    character(len=*), intent(in) :: operation
    integer(int32), intent(in) :: dtype, selected_axis
    integer(int32), allocatable :: axis0
    integer(int32) :: count, keep
    type(frumpy_status) :: status
    type(ndarray_bool) :: source_bool, result_bool
    type(ndarray_i32) :: source_i32, result_i32
    type(ndarray_i64) :: source_i64, result_i64
    type(ndarray_r64) :: result_r64
    class(*), allocatable :: arg_source

    if (selected_axis /= 99) axis0 = selected_axis
    if (operation == 'argmin' .or. operation == 'argmax') then
      call allocate_mixed(arg_source, dtype)
      call read_mixed(arg_source)
      read (*, *) count
      read (*, *) keep
      if (operation == 'argmin') then
        result_i64 = argmin(arg_source, axis0, keep == 1, status)
      else
        result_i64 = argmax(arg_source, axis0, keep == 1, status)
      end if
      write (*, '(i0)') status%code
      if (status%is_ok()) call emit_mixed(result_i64)
      return
    end if
    select case (dtype)
    case (1)
      call read_bool(source_bool)
    case (2)
      call read_i32(source_i32)
    case (3)
      call read_i64(source_i64)
    end select
    read (*, *) count
    read (*, *) keep
    select case (dtype)
    case (1)
      select case (operation)
      case ('all')
        result_bool = all_bool(source_bool, axis0, keep == 1, status)
        write (*, '(i0)') status%code
        if (status%is_ok()) call emit_mixed(result_bool)
      case ('any')
        result_bool = any_bool(source_bool, axis0, keep == 1, status)
        write (*, '(i0)') status%code
        if (status%is_ok()) call emit_mixed(result_bool)
      end select
    case (2)
      select case (operation)
      case ('sum')
        result_i64 = sum_i32(source_i32, axis0, keep == 1, status)
        write (*, '(i0)') status%code
        if (status%is_ok()) call emit_mixed(result_i64)
      case ('prod')
        result_i64 = prod_i32(source_i32, axis0, keep == 1, status)
        write (*, '(i0)') status%code
        if (status%is_ok()) call emit_mixed(result_i64)
      case ('min')
        result_i32 = min_i32(source_i32, axis0, keep == 1, status)
        write (*, '(i0)') status%code
        if (status%is_ok()) call emit_mixed(result_i32)
      case ('max')
        result_i32 = max_i32(source_i32, axis0, keep == 1, status)
        write (*, '(i0)') status%code
        if (status%is_ok()) call emit_mixed(result_i32)
      case ('mean')
        result_r64 = mean_i32(source_i32, axis0, keep == 1, status)
        write (*, '(i0)') status%code
        if (status%is_ok()) call emit_mixed(result_r64)
      end select
    case (3)
      select case (operation)
      case ('sum')
        result_i64 = sum_i64(source_i64, axis0, keep == 1, status)
        write (*, '(i0)') status%code
        if (status%is_ok()) call emit_mixed(result_i64)
      case ('prod')
        result_i64 = prod_i64(source_i64, axis0, keep == 1, status)
        write (*, '(i0)') status%code
        if (status%is_ok()) call emit_mixed(result_i64)
      case ('min')
        result_i64 = min_i64(source_i64, axis0, keep == 1, status)
        write (*, '(i0)') status%code
        if (status%is_ok()) call emit_mixed(result_i64)
      case ('max')
        result_i64 = max_i64(source_i64, axis0, keep == 1, status)
        write (*, '(i0)') status%code
        if (status%is_ok()) call emit_mixed(result_i64)
      case ('mean')
        result_r64 = mean_i64(source_i64, axis0, keep == 1, status)
        write (*, '(i0)') status%code
        if (status%is_ok()) call emit_mixed(result_r64)
      end select
    end select
  end subroutine run_reduce

  subroutine allocate_mixed(array, dtype_id)
    class(*), allocatable, intent(out) :: array
    integer(int32), intent(in) :: dtype_id

    select case (dtype_id)
    case (1)
      allocate(ndarray_bool :: array)
    case (2)
      allocate(ndarray_i32 :: array)
    case (3)
      allocate(ndarray_i64 :: array)
    case (4)
      allocate(ndarray_r32 :: array)
    case (5)
      allocate(ndarray_r64 :: array)
    case default
      error stop 'unknown test dtype'
    end select
  end subroutine allocate_mixed

  subroutine read_mixed(array)
    class(*), intent(inout) :: array

    select type (array)
    type is (ndarray_bool)
      call read_bool(array)
    type is (ndarray_i32)
      call read_i32(array)
    type is (ndarray_i64)
      call read_i64(array)
    type is (ndarray_r32)
      call read_r32(array)
    type is (ndarray_r64)
      call read_r64(array)
    end select
  end subroutine read_mixed

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
