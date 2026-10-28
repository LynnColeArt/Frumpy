!> Float32 results with pairwise real64 squares; no widened input buffer.
module frumpy_norms_r32
  use iso_fortran_env, only: int32, int64, real32, real64
  use frumpy_constants, only: FRUMPY_MAX_RANK
  use frumpy_ndarray_r32, only: ndarray_r32, owned_descriptor_r32
  use frumpy_constructors_r32, only: validate_r32
  use frumpy_strides, only: flat_offset
  use frumpy_shape, only: element_count
  use frumpy_linear_arithmetic, only: linear_step
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_INVALID_AXIS, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OVERFLOW
  implicit none
  private
  public :: vector_norm_r32, matrix_norm_r32
contains
  !> Without axis0, treat all elements (including a scalar) as one vector.
  function vector_norm_r32(source, axis0, keepdims, status) result(array)
    type(ndarray_r32), intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: array
    type(frumpy_status) :: local_status
    integer(int32) :: axes(FRUMPY_MAX_RANK), dim1, n

    call validate_r32(source, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    n = source%rank
    do dim1 = 1_int32, n
      axes(dim1) = dim1 - 1_int32
    end do
    if (present(axis0)) then
      n = 1_int32
      axes(1) = axis0
    end if
    array = norm_axes(source, axes(:n), keepdims, status)
  end function vector_norm_r32

  !> Frobenius norm over two distinct axes, defaulting to the final two dimensions.
  function matrix_norm_r32(source, axes0, keepdims, status) result(array)
    type(ndarray_r32), intent(in) :: source
    integer(int32), intent(in), optional :: axes0(2)
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: array
    type(frumpy_status) :: local_status
    integer(int32) :: axes(2)

    call validate_r32(source, local_status)
    if (local_status%is_ok() .and. source%rank < 2_int32) &
      call set_status(local_status, FRUMPY_STATUS_INVALID_SHAPE, "matrix norm requires rank >= 2")
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    axes = [-2_int32, -1_int32]
    if (present(axes0)) axes = axes0
    array = norm_axes(source, axes, keepdims, status)
  end function matrix_norm_r32

  function norm_axes(source, axes0, keepdims, status) result(array)
    type(ndarray_r32), intent(in) :: source
    integer(int32), intent(in) :: axes0(:)
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r32) :: array
    type(frumpy_status) :: local_status
    logical :: reduced(FRUMPY_MAX_RANK), keep, linear
    integer(int64) :: shape(FRUMPY_MAX_RANK), strides(FRUMPY_MAX_RANK)
    integer(int64) :: red_shape(FRUMPY_MAX_RANK), red_strides(FRUMPY_MAX_RANK)
    integer(int64) :: count, red_count, i0, base, step
    integer(int32) :: dim1, axis0, n, nr
    real(real64) :: squares

    keep = .false.
    if (present(keepdims)) keep = keepdims
    reduced = .false.
    do dim1 = 1_int32, int(size(axes0), int32)
      axis0 = axes0(dim1)
      if (axis0 < -source%rank .or. axis0 >= source%rank) then
        call set_status(local_status, FRUMPY_STATUS_INVALID_AXIS, "norm axis is out of bounds")
        if (present(status)) status = local_status
        return
      end if
      if (axis0 < 0_int32) axis0 = axis0 + source%rank
      if (reduced(axis0 + 1_int32)) then
        call set_status(local_status, FRUMPY_STATUS_INVALID_AXIS, "norm axes must be distinct")
        if (present(status)) status = local_status
        return
      end if
      reduced(axis0 + 1_int32) = .true.
    end do
    n = 0_int32
    nr = 0_int32
    do dim1 = 1_int32, source%rank
      if (reduced(dim1)) then
        nr = nr + 1_int32
        red_shape(nr) = source%shape(dim1)
        red_strides(nr) = source%strides(dim1)
        if (.not. keep) cycle
        n = n + 1_int32
        shape(n) = 1_int64
        strides(n) = 0_int64
      else
        n = n + 1_int32
        shape(n) = source%shape(dim1)
        strides(n) = source%strides(dim1)
      end if
    end do
    count = element_count(shape(:n), local_status)
    if (local_status%is_ok()) then
      if (count > shiftr(huge(1_int64), 2)) &
        call set_status(local_status, FRUMPY_STATUS_OVERFLOW, "norm result bytes overflow")
    end if
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    array = owned_descriptor_r32(shape(:n), status=local_status)
    if (present(status)) status = local_status
    if (local_status%is_failure()) return
    red_count = element_count(red_shape(:nr))
    step = linear_step(red_shape(:nr), red_strides(:nr), linear)
    do i0 = 0_int64, count - 1_int64
      base = flat_offset(shape(:n), strides(:n), source%offset, i0)
      if (linear) then
        squares = linear_squares(source%data, base, step, red_count)
      else
        squares = strided_squares(source%data, red_shape(:nr), red_strides(:nr), &
          base, 0_int64, red_count)
      end if
      array%data(i0 + 1_int64) = real(sqrt(squares), real32)
    end do
  end function norm_axes

  ! Finite real32 squares lie in [2**-298, 2**256); even <2**63 terms sum below
  ! 2**319. Thus widening BEFORE multiplication makes scaling unnecessary.
  ! Leaves use at most 64 sequential additions; larger reductions split in half.
  ! IEEE square/add naturally makes NaN dominate infinity without early exits.
  recursive function linear_squares(data, first, step, count) result(total)
    real(real32), intent(in) :: data(:)
    integer(int64), intent(in) :: first, step, count
    real(real64) :: total, value
    integer(int64) :: i, half

    total = 0.0_real64
    if (count <= 64_int64) then
      do i = 0_int64, count - 1_int64
        value = real(data(first + i * step), real64)
        total = total + value * value
      end do
    else
      half = count / 2_int64
      total = linear_squares(data, first, step, half) &
        + linear_squares(data, first + half * step, step, count - half)
    end if
  end function linear_squares

  recursive function strided_squares(data, shape, strides, first, start, count) result(total)
    real(real32), intent(in) :: data(:)
    integer(int64), intent(in) :: shape(:), strides(:), first, start, count
    real(real64) :: total, value
    integer(int64) :: i, half, position

    total = 0.0_real64
    if (count <= 64_int64) then
      do i = start, start + count - 1_int64
        position = flat_offset(shape, strides, first, i)
        value = real(data(position), real64)
        total = total + value * value
      end do
    else
      half = count / 2_int64
      total = strided_squares(data, shape, strides, first, start, half) &
        + strided_squares(data, shape, strides, first, start + half, count - half)
    end if
  end function strided_squares
end module frumpy_norms_r32
