!> Inject actual allocation failures without changing production allocation code.
program allocation_failure_driver
  use iso_c_binding, only: c_int
  use iso_fortran_env, only: int8, int32, int64, real32, real64
  use frumpy_constants, only: FRUMPY_ORDER_F
  use frumpy_statuses, only: frumpy_status, FRUMPY_STATUS_ALLOCATION_FAILED
  use frumpy_ndarray_bool, only: ndarray_bool, owned_descriptor_bool, share_descriptors_bool
  use frumpy_ndarray_i32, only: ndarray_i32, owned_descriptor_i32, share_descriptors_i32
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64, share_descriptors_i64
  use frumpy_ndarray_r32, only: ndarray_r32, owned_descriptor_r32, share_descriptors_r32
  use frumpy_ndarray_r64, only: ndarray_r64, owned_descriptor_r64, share_descriptors_r64
  implicit none

  interface
    subroutine fail_after(count) bind(c, name="frumpy_test_fail_after")
      import c_int
      integer(c_int), value :: count
    end subroutine fail_after
    subroutine allow_allocations() bind(c, name="frumpy_test_allow_allocations")
    end subroutine allow_allocations
  end interface

  call exercise_bool()
  call exercise_i32()
  call exercise_i64()
  call exercise_r32()
  call exercise_r64()

contains

  subroutine exercise_bool()
    type(ndarray_bool) :: sources(2), destinations(2)
    type(frumpy_status) :: status
    integer(c_int) :: attempt
    integer(int32) :: operation
    logical :: reached_success, constructed_storage
    integer(int64) :: constructed_size

    sources(1) = owned_descriptor_bool([2_int64])
    sources(2) = owned_descriptor_bool([3_int64])
    sources(1)%data = 1_int8
    sources(2)%data = 1_int8

    do operation = 1_int32, 4_int32
      reached_success = .false.
      do attempt = 0_c_int, 63_c_int
        destinations(1) = owned_descriptor_bool([1_int64])
        destinations(2) = owned_descriptor_bool([1_int64])
        destinations(1)%data = 0_int8
        destinations(2)%data = 0_int8
        ! Constructors have five explicit allocations. Beyond those, GFortran
        ! copies function-result metadata without a STAT path; do not inject there.
        if (operation >= 3_int32 .and. attempt == 5_c_int) then
          call allow_allocations()
        else
          call fail_after(attempt)
        end if
        select case (operation)
        case (1)
          call share_descriptors_bool(destinations, sources, status)
        case (2)
          call destinations(1)%share_from(sources(1), status)
        case (3)
          call observe_bool(owned_descriptor_bool([3_int64], status=status), &
            constructed_storage, constructed_size)
        case (4)
          call observe_bool(owned_descriptor_bool([3_int64], &
            order=FRUMPY_ORDER_F, status=status), constructed_storage, constructed_size)
        end select
        call allow_allocations()
        if (status%is_ok()) then
          if (operation <= 2_int32) then
            call require(destinations(1)%size() == 2_int64, 'bool shared size')
            call require(all(destinations(1)%data == 1_int8), 'bool shared values')
          end if
          if (operation == 1_int32) then
            call require(destinations(2)%size() == 3_int64, 'bool second shared size')
            call require(all(destinations(2)%data == 1_int8), &
              'bool second shared values')
          end if
          if (operation >= 3_int32) then
            call require(constructed_storage .and. constructed_size == 3_int64, &
              'constructor success')
          end if
          reached_success = .true.
          exit
        end if
        call require(status%code == FRUMPY_STATUS_ALLOCATION_FAILED, 'bool allocation status')
        call require(all(destinations(1)%shape == [1_int64]), 'bool first shape preserved')
        call require(all(destinations(2)%shape == [1_int64]), 'bool second shape preserved')
        call require(all(destinations(1)%data == 0_int8), 'bool first data preserved')
        call require(all(destinations(2)%data == 0_int8), 'bool second data preserved')
        if (operation >= 3_int32) then
          call require(.not. constructed_storage, 'bool failed constructor has no buffer')
        end if
      end do
      call require(reached_success, 'bool allocation sweep completed')
      if (operation >= 3_int32) then
        call require(attempt == 5_c_int, 'all five constructor allocations exercised')
      end if
      call require(attempt > 0_c_int, 'bool allocation sweep exercised failure')
    end do
  end subroutine exercise_bool

  subroutine observe_bool(array, has_storage, element_count)
    type(ndarray_bool), intent(in) :: array
    logical, intent(out) :: has_storage
    integer(int64), intent(out) :: element_count

    has_storage = array%has_storage()
    element_count = array%size()
  end subroutine observe_bool


  subroutine exercise_i32()
    type(ndarray_i32) :: sources(2), destinations(2)
    type(frumpy_status) :: status
    integer(c_int) :: attempt
    integer(int32) :: operation
    logical :: reached_success, constructed_storage
    integer(int64) :: constructed_size

    sources(1) = owned_descriptor_i32([2_int64])
    sources(2) = owned_descriptor_i32([3_int64])
    sources(1)%data = 1_int32
    sources(2)%data = 1_int32

    do operation = 1_int32, 4_int32
      reached_success = .false.
      do attempt = 0_c_int, 63_c_int
        destinations(1) = owned_descriptor_i32([1_int64])
        destinations(2) = owned_descriptor_i32([1_int64])
        destinations(1)%data = 0_int32
        destinations(2)%data = 0_int32
        ! Constructors have five explicit allocations. Beyond those, GFortran
        ! copies function-result metadata without a STAT path; do not inject there.
        if (operation >= 3_int32 .and. attempt == 5_c_int) then
          call allow_allocations()
        else
          call fail_after(attempt)
        end if
        select case (operation)
        case (1)
          call share_descriptors_i32(destinations, sources, status)
        case (2)
          call destinations(1)%share_from(sources(1), status)
        case (3)
          call observe_i32(owned_descriptor_i32([3_int64], status=status), &
            constructed_storage, constructed_size)
        case (4)
          call observe_i32(owned_descriptor_i32([3_int64], &
            order=FRUMPY_ORDER_F, status=status), constructed_storage, constructed_size)
        end select
        call allow_allocations()
        if (status%is_ok()) then
          if (operation <= 2_int32) then
            call require(destinations(1)%size() == 2_int64, 'i32 shared size')
            call require(all(destinations(1)%data == 1_int32), 'i32 shared values')
          end if
          if (operation == 1_int32) then
            call require(destinations(2)%size() == 3_int64, 'i32 second shared size')
            call require(all(destinations(2)%data == 1_int32), &
              'i32 second shared values')
          end if
          if (operation >= 3_int32) then
            call require(constructed_storage .and. constructed_size == 3_int64, &
              'constructor success')
          end if
          reached_success = .true.
          exit
        end if
        call require(status%code == FRUMPY_STATUS_ALLOCATION_FAILED, 'i32 allocation status')
        call require(all(destinations(1)%shape == [1_int64]), 'i32 first shape preserved')
        call require(all(destinations(2)%shape == [1_int64]), 'i32 second shape preserved')
        call require(all(destinations(1)%data == 0_int32), 'i32 first data preserved')
        call require(all(destinations(2)%data == 0_int32), 'i32 second data preserved')
        if (operation >= 3_int32) then
          call require(.not. constructed_storage, 'i32 failed constructor has no buffer')
        end if
      end do
      call require(reached_success, 'i32 allocation sweep completed')
      if (operation >= 3_int32) then
        call require(attempt == 5_c_int, 'all five constructor allocations exercised')
      end if
      call require(attempt > 0_c_int, 'i32 allocation sweep exercised failure')
    end do
  end subroutine exercise_i32

  subroutine observe_i32(array, has_storage, element_count)
    type(ndarray_i32), intent(in) :: array
    logical, intent(out) :: has_storage
    integer(int64), intent(out) :: element_count

    has_storage = array%has_storage()
    element_count = array%size()
  end subroutine observe_i32


  subroutine exercise_i64()
    type(ndarray_i64) :: sources(2), destinations(2)
    type(frumpy_status) :: status
    integer(c_int) :: attempt
    integer(int32) :: operation
    logical :: reached_success, constructed_storage
    integer(int64) :: constructed_size

    sources(1) = owned_descriptor_i64([2_int64])
    sources(2) = owned_descriptor_i64([3_int64])
    sources(1)%data = 1_int64
    sources(2)%data = 1_int64

    do operation = 1_int32, 4_int32
      reached_success = .false.
      do attempt = 0_c_int, 63_c_int
        destinations(1) = owned_descriptor_i64([1_int64])
        destinations(2) = owned_descriptor_i64([1_int64])
        destinations(1)%data = 0_int64
        destinations(2)%data = 0_int64
        ! Constructors have five explicit allocations. Beyond those, GFortran
        ! copies function-result metadata without a STAT path; do not inject there.
        if (operation >= 3_int32 .and. attempt == 5_c_int) then
          call allow_allocations()
        else
          call fail_after(attempt)
        end if
        select case (operation)
        case (1)
          call share_descriptors_i64(destinations, sources, status)
        case (2)
          call destinations(1)%share_from(sources(1), status)
        case (3)
          call observe_i64(owned_descriptor_i64([3_int64], status=status), &
            constructed_storage, constructed_size)
        case (4)
          call observe_i64(owned_descriptor_i64([3_int64], &
            order=FRUMPY_ORDER_F, status=status), constructed_storage, constructed_size)
        end select
        call allow_allocations()
        if (status%is_ok()) then
          if (operation <= 2_int32) then
            call require(destinations(1)%size() == 2_int64, 'i64 shared size')
            call require(all(destinations(1)%data == 1_int64), 'i64 shared values')
          end if
          if (operation == 1_int32) then
            call require(destinations(2)%size() == 3_int64, 'i64 second shared size')
            call require(all(destinations(2)%data == 1_int64), &
              'i64 second shared values')
          end if
          if (operation >= 3_int32) then
            call require(constructed_storage .and. constructed_size == 3_int64, &
              'constructor success')
          end if
          reached_success = .true.
          exit
        end if
        call require(status%code == FRUMPY_STATUS_ALLOCATION_FAILED, 'i64 allocation status')
        call require(all(destinations(1)%shape == [1_int64]), 'i64 first shape preserved')
        call require(all(destinations(2)%shape == [1_int64]), 'i64 second shape preserved')
        call require(all(destinations(1)%data == 0_int64), 'i64 first data preserved')
        call require(all(destinations(2)%data == 0_int64), 'i64 second data preserved')
        if (operation >= 3_int32) then
          call require(.not. constructed_storage, 'i64 failed constructor has no buffer')
        end if
      end do
      call require(reached_success, 'i64 allocation sweep completed')
      if (operation >= 3_int32) then
        call require(attempt == 5_c_int, 'all five constructor allocations exercised')
      end if
      call require(attempt > 0_c_int, 'i64 allocation sweep exercised failure')
    end do
  end subroutine exercise_i64

  subroutine observe_i64(array, has_storage, element_count)
    type(ndarray_i64), intent(in) :: array
    logical, intent(out) :: has_storage
    integer(int64), intent(out) :: element_count

    has_storage = array%has_storage()
    element_count = array%size()
  end subroutine observe_i64


  subroutine exercise_r32()
    type(ndarray_r32) :: sources(2), destinations(2)
    type(frumpy_status) :: status
    integer(c_int) :: attempt
    integer(int32) :: operation
    logical :: reached_success, constructed_storage
    integer(int64) :: constructed_size

    sources(1) = owned_descriptor_r32([2_int64])
    sources(2) = owned_descriptor_r32([3_int64])
    sources(1)%data = 1_real32
    sources(2)%data = 1_real32

    do operation = 1_int32, 4_int32
      reached_success = .false.
      do attempt = 0_c_int, 63_c_int
        destinations(1) = owned_descriptor_r32([1_int64])
        destinations(2) = owned_descriptor_r32([1_int64])
        destinations(1)%data = 0_real32
        destinations(2)%data = 0_real32
        ! Constructors have five explicit allocations. Beyond those, GFortran
        ! copies function-result metadata without a STAT path; do not inject there.
        if (operation >= 3_int32 .and. attempt == 5_c_int) then
          call allow_allocations()
        else
          call fail_after(attempt)
        end if
        select case (operation)
        case (1)
          call share_descriptors_r32(destinations, sources, status)
        case (2)
          call destinations(1)%share_from(sources(1), status)
        case (3)
          call observe_r32(owned_descriptor_r32([3_int64], status=status), &
            constructed_storage, constructed_size)
        case (4)
          call observe_r32(owned_descriptor_r32([3_int64], &
            order=FRUMPY_ORDER_F, status=status), constructed_storage, constructed_size)
        end select
        call allow_allocations()
        if (status%is_ok()) then
          if (operation <= 2_int32) then
            call require(destinations(1)%size() == 2_int64, 'r32 shared size')
            call require(all(abs(destinations(1)%data - 1_real32) < epsilon(1.0_real32)), &
              'r32 shared values')
          end if
          if (operation == 1_int32) then
            call require(destinations(2)%size() == 3_int64, 'r32 second shared size')
            call require(all(abs(destinations(2)%data - 1.0_real32) < epsilon(1.0_real32)), &
              'r32 second shared values')
          end if
          if (operation >= 3_int32) then
            call require(constructed_storage .and. constructed_size == 3_int64, &
              'constructor success')
          end if
          reached_success = .true.
          exit
        end if
        call require(status%code == FRUMPY_STATUS_ALLOCATION_FAILED, 'r32 allocation status')
        call require(all(destinations(1)%shape == [1_int64]), 'r32 first shape preserved')
        call require(all(destinations(2)%shape == [1_int64]), 'r32 second shape preserved')
        call require(all(abs(destinations(1)%data - 0_real32) < epsilon(1.0_real32)), &
          'r32 first data preserved')
        call require(all(abs(destinations(2)%data - 0_real32) < epsilon(1.0_real32)), &
          'r32 second data preserved')
        if (operation >= 3_int32) then
          call require(.not. constructed_storage, 'r32 failed constructor has no buffer')
        end if
      end do
      call require(reached_success, 'r32 allocation sweep completed')
      if (operation >= 3_int32) then
        call require(attempt == 5_c_int, 'all five constructor allocations exercised')
      end if
      call require(attempt > 0_c_int, 'r32 allocation sweep exercised failure')
    end do
  end subroutine exercise_r32

  subroutine observe_r32(array, has_storage, element_count)
    type(ndarray_r32), intent(in) :: array
    logical, intent(out) :: has_storage
    integer(int64), intent(out) :: element_count

    has_storage = array%has_storage()
    element_count = array%size()
  end subroutine observe_r32


  subroutine exercise_r64()
    type(ndarray_r64) :: sources(2), destinations(2)
    type(frumpy_status) :: status
    integer(c_int) :: attempt
    integer(int32) :: operation
    logical :: reached_success, constructed_storage
    integer(int64) :: constructed_size

    sources(1) = owned_descriptor_r64([2_int64])
    sources(2) = owned_descriptor_r64([3_int64])
    sources(1)%data = 1_real64
    sources(2)%data = 1_real64

    do operation = 1_int32, 4_int32
      reached_success = .false.
      do attempt = 0_c_int, 63_c_int
        destinations(1) = owned_descriptor_r64([1_int64])
        destinations(2) = owned_descriptor_r64([1_int64])
        destinations(1)%data = 0_real64
        destinations(2)%data = 0_real64
        ! Constructors have five explicit allocations. Beyond those, GFortran
        ! copies function-result metadata without a STAT path; do not inject there.
        if (operation >= 3_int32 .and. attempt == 5_c_int) then
          call allow_allocations()
        else
          call fail_after(attempt)
        end if
        select case (operation)
        case (1)
          call share_descriptors_r64(destinations, sources, status)
        case (2)
          call destinations(1)%share_from(sources(1), status)
        case (3)
          call observe_r64(owned_descriptor_r64([3_int64], status=status), &
            constructed_storage, constructed_size)
        case (4)
          call observe_r64(owned_descriptor_r64([3_int64], &
            order=FRUMPY_ORDER_F, status=status), constructed_storage, constructed_size)
        end select
        call allow_allocations()
        if (status%is_ok()) then
          if (operation <= 2_int32) then
            call require(destinations(1)%size() == 2_int64, 'r64 shared size')
            call require(all(abs(destinations(1)%data - 1_real64) < epsilon(1.0_real64)), &
              'r64 shared values')
          end if
          if (operation == 1_int32) then
            call require(destinations(2)%size() == 3_int64, 'r64 second shared size')
            call require(all(abs(destinations(2)%data - 1.0_real64) < epsilon(1.0_real64)), &
              'r64 second shared values')
          end if
          if (operation >= 3_int32) then
            call require(constructed_storage .and. constructed_size == 3_int64, &
              'constructor success')
          end if
          reached_success = .true.
          exit
        end if
        call require(status%code == FRUMPY_STATUS_ALLOCATION_FAILED, 'r64 allocation status')
        call require(all(destinations(1)%shape == [1_int64]), 'r64 first shape preserved')
        call require(all(destinations(2)%shape == [1_int64]), 'r64 second shape preserved')
        call require(all(abs(destinations(1)%data - 0_real64) < epsilon(1.0_real64)), &
          'r64 first data preserved')
        call require(all(abs(destinations(2)%data - 0_real64) < epsilon(1.0_real64)), &
          'r64 second data preserved')
        if (operation >= 3_int32) then
          call require(.not. constructed_storage, 'r64 failed constructor has no buffer')
        end if
      end do
      call require(reached_success, 'r64 allocation sweep completed')
      if (operation >= 3_int32) then
        call require(attempt == 5_c_int, 'all five constructor allocations exercised')
      end if
      call require(attempt > 0_c_int, 'r64 allocation sweep exercised failure')
    end do
  end subroutine exercise_r64

  subroutine observe_r64(array, has_storage, element_count)
    type(ndarray_r64), intent(in) :: array
    logical, intent(out) :: has_storage
    integer(int64), intent(out) :: element_count

    has_storage = array%has_storage()
    element_count = array%size()
  end subroutine observe_r64


  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not. condition) then
      write (*, '(a)') message
      error stop 1
    end if
  end subroutine require
end program allocation_failure_driver
