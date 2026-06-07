!> Basic NumPy-style slice descriptors for ndarray views.
module fenum_slices
  use iso_fortran_env, only: int32, int64
  use fenum_statuses, only: FENUM_STATUS_INVALID_SHAPE, FENUM_STATUS_OK, &
    fenum_status, set_status

  implicit none

  private

  public :: slice_spec
  public :: slice_all
  public :: slice_range
  public :: slice_length

  type :: slice_spec
    integer(int64) :: start0 = 0_int64
    integer(int64) :: stop0 = 0_int64
    integer(int64) :: step = 1_int64
    logical :: uses_full_extent = .true.
  end type slice_spec

contains

  function slice_all() result(spec)
    type(slice_spec) :: spec

    spec%start0 = 0_int64
    spec%stop0 = 0_int64
    spec%step = 1_int64
    spec%uses_full_extent = .true.
  end function slice_all

  function slice_range(start0, stop0, step, status) result(spec)
    integer(int64), intent(in) :: start0
    integer(int64), intent(in) :: stop0
    integer(int64), intent(in), optional :: step
    type(fenum_status), intent(out), optional :: status
    type(slice_spec) :: spec
    integer(int64) :: resolved_step

    resolved_step = 1_int64
    if (present(step)) resolved_step = step

    if (resolved_step == 0_int64) then
      call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "slice step must be non-zero")
      return
    end if

    spec%start0 = start0
    spec%stop0 = stop0
    spec%step = resolved_step
    spec%uses_full_extent = .false.
    call set_optional_status(status, FENUM_STATUS_OK)
  end function slice_range

  function slice_length(spec, extent, status) result(length)
    type(slice_spec), intent(in) :: spec
    integer(int64), intent(in) :: extent
    type(fenum_status), intent(out), optional :: status
    integer(int64) :: length
    integer(int64) :: start0
    integer(int64) :: stop0
    integer(int64) :: distance

    if (extent < 0_int64) then
      length = 0_int64
      call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "slice extent must be non-negative")
      return
    end if

    if (spec%uses_full_extent) then
      length = extent
      call set_optional_status(status, FENUM_STATUS_OK)
      return
    end if

    if (spec%step == 0_int64) then
      length = 0_int64
      call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "slice step must be non-zero")
      return
    end if

    start0 = spec%start0
    stop0 = spec%stop0
    if (.not. is_valid_slice_bound(start0, extent, spec%step)) then
      length = 0_int64
      call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "slice start0 is out of bounds")
      return
    end if

    if (.not. is_valid_slice_stop(stop0, extent, spec%step)) then
      length = 0_int64
      call set_optional_status(status, FENUM_STATUS_INVALID_SHAPE, &
        "slice stop0 is out of bounds")
      return
    end if

    if (spec%step > 0_int64) then
      if (stop0 <= start0) then
        length = 0_int64
      else
        distance = stop0 - start0
        length = (distance + spec%step - 1_int64) / spec%step
      end if
    else
      if (stop0 >= start0) then
        length = 0_int64
      else
        distance = start0 - stop0
        length = (distance + abs(spec%step) - 1_int64) / abs(spec%step)
      end if
    end if

    call set_optional_status(status, FENUM_STATUS_OK)
  end function slice_length

  logical function is_valid_slice_bound(bound0, extent, step)
    integer(int64), intent(in) :: bound0
    integer(int64), intent(in) :: extent
    integer(int64), intent(in) :: step

    if (step > 0_int64) then
      is_valid_slice_bound = bound0 >= 0_int64 .and. bound0 <= extent
    else
      if (extent == 0_int64) then
        is_valid_slice_bound = bound0 == -1_int64
      else
        is_valid_slice_bound = bound0 >= 0_int64 .and. bound0 < extent
      end if
    end if
  end function is_valid_slice_bound

  logical function is_valid_slice_stop(stop0, extent, step)
    integer(int64), intent(in) :: stop0
    integer(int64), intent(in) :: extent
    integer(int64), intent(in) :: step

    if (step > 0_int64) then
      is_valid_slice_stop = stop0 >= 0_int64 .and. stop0 <= extent
    else
      is_valid_slice_stop = stop0 >= -1_int64 .and. stop0 < extent
    end if
  end function is_valid_slice_stop

  subroutine set_optional_status(status, code, message)
    type(fenum_status), intent(out), optional :: status
    integer(int32), intent(in) :: code
    character(len=*), intent(in), optional :: message

    if (.not. present(status)) return

    if (present(message)) then
      call set_status(status, code, message)
    else
      call set_status(status, code)
    end if
  end subroutine set_optional_status
end module fenum_slices
