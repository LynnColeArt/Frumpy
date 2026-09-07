!> Managed lifetime invariants for the non-float64 descriptor foundation.
program test_storage_lifetime_dtypes
  use iso_fortran_env, only: int8, int32, int64, real32
  use frumpy_statuses, only: frumpy_status, FRUMPY_STATUS_INVALID_SHAPE
  use frumpy_constants, only: FRUMPY_ORDER_F
  use frumpy_ndarray_bool, only: ndarray_bool, owned_descriptor_bool, &
    view_descriptor_bool, metadata_descriptor_bool, share_descriptors_bool
  use frumpy_ndarray_i32, only: ndarray_i32, owned_descriptor_i32, &
    view_descriptor_i32, metadata_descriptor_i32, share_descriptors_i32
  use frumpy_ndarray_i64, only: ndarray_i64, owned_descriptor_i64, &
    view_descriptor_i64, metadata_descriptor_i64, share_descriptors_i64
  use frumpy_ndarray_r32, only: ndarray_r32, owned_descriptor_r32, &
    view_descriptor_r32, metadata_descriptor_r32, share_descriptors_r32
  implicit none

  call exercise_bool()
  call exercise_i32()
  call exercise_i64()
  call exercise_r32()

contains

  subroutine exercise_bool()
    type(ndarray_bool) :: owner, alias, reversed, vectors(2)
    type(ndarray_bool), allocatable :: allocated_owner
    type(frumpy_status) :: status
    integer(int8), parameter :: values(3) = [1_int8, 0_int8, 1_int8]
    integer(int8), target :: external(3), empty_external(0)
    integer(int32) :: iteration

    owner = owned_descriptor_bool([3_int64], status=status)
    call require(status%is_ok(), 'bool constructor')
    owner%data = values
    alias = owner
    call owner%release()
    call owner%release()
    call require(.not. owner%has_storage(), 'bool release clears storage')
    call require(.not. allocated(owner%shape), 'bool release clears shape')
    call require(all(alias%data == values), 'bool alias retains exact values')
    reversed = view_descriptor_bool(alias, [3_int64], [-1_int64], 3_int64, status)
    call require(status%is_ok(), 'bool reverse view')
    call alias%release()
    call require(reversed%offset == 3_int64, 'bool view offset')
    call require(all(reversed%strides == -1_int64), 'bool view strides')
    call require(all(reversed%data == values), 'bool view survives release')
    call require(.not. reversed%owns_data, 'bool view provenance')
    alias = escaped_bool()
    call require(all(alias%data == values), 'bool returned local view')
    alias = alias
    call require(alias%has_storage(), 'bool self assignment')
    allocate(allocated_owner)
    call allocated_owner%share_from(alias, status)
    call require(status%is_ok(), 'bool explicit share')
    call alias%release()
    alias = allocated_owner
    deallocate(allocated_owner)
    call require(all(alias%data == values), 'bool allocatable owner release')

    vectors(1) = alias
    vectors(2) = reversed
    call alias%release()
    call reversed%release()
    call share_descriptors_bool(vectors, vectors(2:1:-1), status)
    call require(status%is_ok(), 'bool overlapping descriptor vector')
    call require(vectors(1)%offset == 3_int64, 'bool reversed vector metadata')
    call require(vectors(2)%offset == 1_int64, 'bool forward vector metadata')
    call share_descriptors_bool(vectors(:1), vectors, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'bool vector shape failure')

    do iteration = 1_int32, 20_int32
      owner = owned_descriptor_bool([2_int64, 3_int64], FRUMPY_ORDER_F, status)
      call require(status%is_ok(), 'bool repeated constructor')
      owner%data = values(1)
      alias = owner
      owner = owned_descriptor_bool([integer(int64) ::], status=status)
      call require(status%is_ok() .and. owner%size() == 1_int64, 'bool scalar replacement')
      call require(alias%size() == 6_int64 .and. alias%is_f_contiguous, 'bool F-order alias')
    end do
    owner = owned_descriptor_bool([0_int64], status=status)
    call require(status%is_ok(), 'bool empty constructor')
    owner = owner
    alias = owner
    call owner%release()
    call require(alias%has_storage() .and. alias%size() == 0_int64, 'bool empty alias')
    owner = owned_descriptor_bool([-1_int64], status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'bool constructor failure')
    call require(.not. owner%has_storage(), 'bool failed constructor has no storage')

    external = values
    owner = metadata_descriptor_bool([3_int64], [1_int64], 1_int64)
    owner%data => external
    alias = owner
    call owner%release()
    call alias%release()
    call require(all(external == values), 'bool external storage not freed')
    owner = metadata_descriptor_bool([0_int64], [0_int64], 1_int64)
    owner%data => empty_external
    owner = owner
    call require(owner%has_storage(), 'bool borrowed empty self assignment')
  end subroutine exercise_bool

  function escaped_bool() result(view)
    type(ndarray_bool) :: view, local_owner
    type(frumpy_status) :: status

    local_owner = owned_descriptor_bool([3_int64], status=status)
    call require(status%is_ok(), 'bool local owner')
    local_owner%data = [1_int8, 0_int8, 1_int8]
    view = view_descriptor_bool(local_owner, [3_int64], [1_int64], 1_int64, status)
    call require(status%is_ok(), 'bool local view')
  end function escaped_bool

  subroutine exercise_i32()
    type(ndarray_i32) :: owner, alias, reversed, vectors(2)
    type(ndarray_i32), allocatable :: allocated_owner
    type(frumpy_status) :: status
    integer(int32), parameter :: values(3) = [1_int32, 0_int32, 3_int32]
    integer(int32), target :: external(3), empty_external(0)
    integer(int32) :: iteration

    owner = owned_descriptor_i32([3_int64], status=status)
    call require(status%is_ok(), 'i32 constructor')
    owner%data = values
    alias = owner
    call owner%release()
    call owner%release()
    call require(.not. owner%has_storage(), 'i32 release clears storage')
    call require(.not. allocated(owner%shape), 'i32 release clears shape')
    call require(all(alias%data == values), 'i32 alias retains exact values')
    reversed = view_descriptor_i32(alias, [3_int64], [-1_int64], 3_int64, status)
    call require(status%is_ok(), 'i32 reverse view')
    call alias%release()
    call require(reversed%offset == 3_int64, 'i32 view offset')
    call require(all(reversed%strides == -1_int64), 'i32 view strides')
    call require(all(reversed%data == values), 'i32 view survives release')
    call require(.not. reversed%owns_data, 'i32 view provenance')
    alias = escaped_i32()
    call require(all(alias%data == values), 'i32 returned local view')
    alias = alias
    call require(alias%has_storage(), 'i32 self assignment')
    allocate(allocated_owner)
    call allocated_owner%share_from(alias, status)
    call require(status%is_ok(), 'i32 explicit share')
    call alias%release()
    alias = allocated_owner
    deallocate(allocated_owner)
    call require(all(alias%data == values), 'i32 allocatable owner release')

    vectors(1) = alias
    vectors(2) = reversed
    call alias%release()
    call reversed%release()
    call share_descriptors_i32(vectors, vectors(2:1:-1), status)
    call require(status%is_ok(), 'i32 overlapping descriptor vector')
    call require(vectors(1)%offset == 3_int64, 'i32 reversed vector metadata')
    call require(vectors(2)%offset == 1_int64, 'i32 forward vector metadata')
    call share_descriptors_i32(vectors(:1), vectors, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'i32 vector shape failure')

    do iteration = 1_int32, 20_int32
      owner = owned_descriptor_i32([2_int64, 3_int64], FRUMPY_ORDER_F, status)
      call require(status%is_ok(), 'i32 repeated constructor')
      owner%data = values(1)
      alias = owner
      owner = owned_descriptor_i32([integer(int64) ::], status=status)
      call require(status%is_ok() .and. owner%size() == 1_int64, 'i32 scalar replacement')
      call require(alias%size() == 6_int64 .and. alias%is_f_contiguous, 'i32 F-order alias')
    end do
    owner = owned_descriptor_i32([0_int64], status=status)
    call require(status%is_ok(), 'i32 empty constructor')
    owner = owner
    alias = owner
    call owner%release()
    call require(alias%has_storage() .and. alias%size() == 0_int64, 'i32 empty alias')
    owner = owned_descriptor_i32([-1_int64], status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'i32 constructor failure')
    call require(.not. owner%has_storage(), 'i32 failed constructor has no storage')

    external = values
    owner = metadata_descriptor_i32([3_int64], [1_int64], 1_int64)
    owner%data => external
    alias = owner
    call owner%release()
    call alias%release()
    call require(all(external == values), 'i32 external storage not freed')
    owner = metadata_descriptor_i32([0_int64], [0_int64], 1_int64)
    owner%data => empty_external
    owner = owner
    call require(owner%has_storage(), 'i32 borrowed empty self assignment')
  end subroutine exercise_i32

  function escaped_i32() result(view)
    type(ndarray_i32) :: view, local_owner
    type(frumpy_status) :: status

    local_owner = owned_descriptor_i32([3_int64], status=status)
    call require(status%is_ok(), 'i32 local owner')
    local_owner%data = [1_int32, 0_int32, 3_int32]
    view = view_descriptor_i32(local_owner, [3_int64], [1_int64], 1_int64, status)
    call require(status%is_ok(), 'i32 local view')
  end function escaped_i32

  subroutine exercise_i64()
    type(ndarray_i64) :: owner, alias, reversed, vectors(2)
    type(ndarray_i64), allocatable :: allocated_owner
    type(frumpy_status) :: status
    integer(int64), parameter :: values(3) = &
      [9007199254740993_int64, -9007199254740993_int64, 3_int64]
    integer(int64), target :: external(3), empty_external(0)
    integer(int32) :: iteration

    owner = owned_descriptor_i64([3_int64], status=status)
    call require(status%is_ok(), 'i64 constructor')
    owner%data = values
    alias = owner
    call owner%release()
    call owner%release()
    call require(.not. owner%has_storage(), 'i64 release clears storage')
    call require(.not. allocated(owner%shape), 'i64 release clears shape')
    call require(all(alias%data == values), 'i64 alias retains exact values')
    reversed = view_descriptor_i64(alias, [3_int64], [-1_int64], 3_int64, status)
    call require(status%is_ok(), 'i64 reverse view')
    call alias%release()
    call require(reversed%offset == 3_int64, 'i64 view offset')
    call require(all(reversed%strides == -1_int64), 'i64 view strides')
    call require(all(reversed%data == values), 'i64 view survives release')
    call require(.not. reversed%owns_data, 'i64 view provenance')
    alias = escaped_i64()
    call require(all(alias%data == values), 'i64 returned local view')
    alias = alias
    call require(alias%has_storage(), 'i64 self assignment')
    allocate(allocated_owner)
    call allocated_owner%share_from(alias, status)
    call require(status%is_ok(), 'i64 explicit share')
    call alias%release()
    alias = allocated_owner
    deallocate(allocated_owner)
    call require(all(alias%data == values), 'i64 allocatable owner release')

    vectors(1) = alias
    vectors(2) = reversed
    call alias%release()
    call reversed%release()
    call share_descriptors_i64(vectors, vectors(2:1:-1), status)
    call require(status%is_ok(), 'i64 overlapping descriptor vector')
    call require(vectors(1)%offset == 3_int64, 'i64 reversed vector metadata')
    call require(vectors(2)%offset == 1_int64, 'i64 forward vector metadata')
    call share_descriptors_i64(vectors(:1), vectors, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'i64 vector shape failure')

    do iteration = 1_int32, 20_int32
      owner = owned_descriptor_i64([2_int64, 3_int64], FRUMPY_ORDER_F, status)
      call require(status%is_ok(), 'i64 repeated constructor')
      owner%data = values(1)
      alias = owner
      owner = owned_descriptor_i64([integer(int64) ::], status=status)
      call require(status%is_ok() .and. owner%size() == 1_int64, 'i64 scalar replacement')
      call require(alias%size() == 6_int64 .and. alias%is_f_contiguous, 'i64 F-order alias')
    end do
    owner = owned_descriptor_i64([0_int64], status=status)
    call require(status%is_ok(), 'i64 empty constructor')
    owner = owner
    alias = owner
    call owner%release()
    call require(alias%has_storage() .and. alias%size() == 0_int64, 'i64 empty alias')
    owner = owned_descriptor_i64([-1_int64], status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'i64 constructor failure')
    call require(.not. owner%has_storage(), 'i64 failed constructor has no storage')

    external = values
    owner = metadata_descriptor_i64([3_int64], [1_int64], 1_int64)
    owner%data => external
    alias = owner
    call owner%release()
    call alias%release()
    call require(all(external == values), 'i64 external storage not freed')
    owner = metadata_descriptor_i64([0_int64], [0_int64], 1_int64)
    owner%data => empty_external
    owner = owner
    call require(owner%has_storage(), 'i64 borrowed empty self assignment')
  end subroutine exercise_i64

  function escaped_i64() result(view)
    type(ndarray_i64) :: view, local_owner
    type(frumpy_status) :: status

    local_owner = owned_descriptor_i64([3_int64], status=status)
    call require(status%is_ok(), 'i64 local owner')
    local_owner%data = [9007199254740993_int64, -9007199254740993_int64, 3_int64]
    view = view_descriptor_i64(local_owner, [3_int64], [1_int64], 1_int64, status)
    call require(status%is_ok(), 'i64 local view')
  end function escaped_i64

  subroutine exercise_r32()
    type(ndarray_r32) :: owner, alias, reversed, vectors(2)
    type(ndarray_r32), allocatable :: allocated_owner
    type(frumpy_status) :: status
    real(real32), parameter :: values(3) = [1_real32, 0_real32, 3_real32]
    real(real32), target :: external(3), empty_external(0)
    integer(int32) :: iteration

    owner = owned_descriptor_r32([3_int64], status=status)
    call require(status%is_ok(), 'r32 constructor')
    owner%data = values
    alias = owner
    call owner%release()
    call owner%release()
    call require(.not. owner%has_storage(), 'r32 release clears storage')
    call require(.not. allocated(owner%shape), 'r32 release clears shape')
    call require(all(abs(alias%data - values) < epsilon(1.0_real32)), &
      'r32 alias retains exact values')
    reversed = view_descriptor_r32(alias, [3_int64], [-1_int64], 3_int64, status)
    call require(status%is_ok(), 'r32 reverse view')
    call alias%release()
    call require(reversed%offset == 3_int64, 'r32 view offset')
    call require(all(reversed%strides == -1_int64), 'r32 view strides')
    call require(all(abs(reversed%data - values) < epsilon(1.0_real32)), &
      'r32 view survives release')
    call require(.not. reversed%owns_data, 'r32 view provenance')
    alias = escaped_r32()
    call require(all(abs(alias%data - values) < epsilon(1.0_real32)), 'r32 returned local view')
    alias = alias
    call require(alias%has_storage(), 'r32 self assignment')
    allocate(allocated_owner)
    call allocated_owner%share_from(alias, status)
    call require(status%is_ok(), 'r32 explicit share')
    call alias%release()
    alias = allocated_owner
    deallocate(allocated_owner)
    call require(all(abs(alias%data - values) < epsilon(1.0_real32)), &
      'r32 allocatable owner release')

    vectors(1) = alias
    vectors(2) = reversed
    call alias%release()
    call reversed%release()
    call share_descriptors_r32(vectors, vectors(2:1:-1), status)
    call require(status%is_ok(), 'r32 overlapping descriptor vector')
    call require(vectors(1)%offset == 3_int64, 'r32 reversed vector metadata')
    call require(vectors(2)%offset == 1_int64, 'r32 forward vector metadata')
    call share_descriptors_r32(vectors(:1), vectors, status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'r32 vector shape failure')

    do iteration = 1_int32, 20_int32
      owner = owned_descriptor_r32([2_int64, 3_int64], FRUMPY_ORDER_F, status)
      call require(status%is_ok(), 'r32 repeated constructor')
      owner%data = values(1)
      alias = owner
      owner = owned_descriptor_r32([integer(int64) ::], status=status)
      call require(status%is_ok() .and. owner%size() == 1_int64, 'r32 scalar replacement')
      call require(alias%size() == 6_int64 .and. alias%is_f_contiguous, 'r32 F-order alias')
    end do
    owner = owned_descriptor_r32([0_int64], status=status)
    call require(status%is_ok(), 'r32 empty constructor')
    owner = owner
    alias = owner
    call owner%release()
    call require(alias%has_storage() .and. alias%size() == 0_int64, 'r32 empty alias')
    owner = owned_descriptor_r32([-1_int64], status=status)
    call require(status%code == FRUMPY_STATUS_INVALID_SHAPE, 'r32 constructor failure')
    call require(.not. owner%has_storage(), 'r32 failed constructor has no storage')

    external = values
    owner = metadata_descriptor_r32([3_int64], [1_int64], 1_int64)
    owner%data => external
    alias = owner
    call owner%release()
    call alias%release()
    call require(all(abs(external - values) < epsilon(1.0_real32)), &
      'r32 external storage not freed')
    owner = metadata_descriptor_r32([0_int64], [0_int64], 1_int64)
    owner%data => empty_external
    owner = owner
    call require(owner%has_storage(), 'r32 borrowed empty self assignment')
  end subroutine exercise_r32

  function escaped_r32() result(view)
    type(ndarray_r32) :: view, local_owner
    type(frumpy_status) :: status

    local_owner = owned_descriptor_r32([3_int64], status=status)
    call require(status%is_ok(), 'r32 local owner')
    local_owner%data = [1_real32, 0_real32, 3_real32]
    view = view_descriptor_r32(local_owner, [3_int64], [1_int64], 1_int64, status)
    call require(status%is_ok(), 'r32 local view')
  end function escaped_r32

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not. condition) then
      write (*, '(a)') message
      error stop 1
    end if
  end subroutine require
end program test_storage_lifetime_dtypes
