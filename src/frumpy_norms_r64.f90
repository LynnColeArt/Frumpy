!> Scaled Euclidean and Frobenius norms avoid intermediate square overflow/underflow.
module frumpy_norms_r64
  use iso_fortran_env, only: int32, int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_nan, ieee_is_finite, ieee_value, &
    ieee_quiet_nan, ieee_positive_inf
  use frumpy_constants, only: FRUMPY_MAX_RANK
  use frumpy_ndarray_r64, only: ndarray_r64, owned_descriptor_r64
  use frumpy_access_r64, only: validate_r64, flat_offset
  use frumpy_shape, only: element_count
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_INVALID_AXIS, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_OVERFLOW
  implicit none
  private
  public :: vector_norm_r64, matrix_norm_r64
contains
  !> Without axis0, treat all elements (including a scalar) as one vector.
  function vector_norm_r64(source, axis0, keepdims, status) result(array)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in), optional :: axis0
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(frumpy_status) :: local_status
    integer(int32) :: axes(FRUMPY_MAX_RANK), dim1, n

    call validate_r64(source, local_status)
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
  end function vector_norm_r64

  !> Frobenius norm over two distinct axes, defaulting to the final two dimensions.
  function matrix_norm_r64(source, axes0, keepdims, status) result(array)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in), optional :: axes0(2)
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(frumpy_status) :: local_status
    integer(int32) :: axes(2)

    call validate_r64(source, local_status)
    if (local_status%is_ok() .and. source%rank < 2_int32) &
      call set_status(local_status, FRUMPY_STATUS_INVALID_SHAPE, "matrix norm requires rank >= 2")
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    axes = [-2_int32, -1_int32]
    if (present(axes0)) axes = axes0
    array = norm_axes(source, axes, keepdims, status)
  end function matrix_norm_r64

  function norm_axes(source, axes0, keepdims, status) result(array)
    type(ndarray_r64), intent(in) :: source
    integer(int32), intent(in) :: axes0(:)
    logical, intent(in), optional :: keepdims
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(frumpy_status) :: local_status
    logical :: reduced(FRUMPY_MAX_RANK), keep, has_nan, has_inf
    integer(int64) :: shape(FRUMPY_MAX_RANK), strides(FRUMPY_MAX_RANK)
    integer(int64) :: red_shape(FRUMPY_MAX_RANK), red_strides(FRUMPY_MAX_RANK)
    integer(int64) :: count, red_count, i0, j0, base, position
    integer(int32) :: dim1, axis0, n, nr
    real(real64) :: scale, squares, magnitude, value

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
      if (count > shiftr(huge(1_int64), 3)) &
        call set_status(local_status, FRUMPY_STATUS_OVERFLOW, "norm result bytes overflow")
    end if
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    array = owned_descriptor_r64(shape(:n), status=local_status)
    if (present(status)) status = local_status
    if (local_status%is_failure()) return
    red_count = element_count(red_shape(:nr))
    do i0 = 0_int64, count - 1_int64
      base = flat_offset(shape(:n), strides(:n), source%offset, i0)
      scale = 0.0_real64
      squares = 1.0_real64
      has_nan = .false.
      has_inf = .false.
      do j0 = 0_int64, red_count - 1_int64
        position = flat_offset(red_shape(:nr), red_strides(:nr), base, j0)
        magnitude = abs(source%data(position))
        if (ieee_is_nan(magnitude)) then
          has_nan = .true.
        else if (.not. ieee_is_finite(magnitude)) then
          has_inf = .true.
        else if (magnitude > 0.0_real64) then
          if (scale < magnitude) then
            squares = 1.0_real64 + squares * (scale / magnitude)**2
            scale = magnitude
          else
            squares = squares + (magnitude / scale)**2
          end if
        end if
      end do
      value = scale * sqrt(squares)
      if (has_inf) value = ieee_value(value, ieee_positive_inf)
      if (has_nan) value = ieee_value(value, ieee_quiet_nan)
      array%data(i0 + 1_int64) = value
    end do
  end function norm_axes
end module frumpy_norms_r64
