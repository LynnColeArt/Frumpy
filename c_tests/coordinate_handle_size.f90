!> Test-only ABI allocation size, derived from the compiler's actual descriptor layout.
function coordinate_handle_size() bind(C) result(bytes)
  use iso_c_binding, only: c_size_t
  use frumpy_c_handles, only: handle_slot
  implicit none
  integer(c_size_t) :: bytes
  type(handle_slot) :: slot
  bytes=shiftr(storage_size(slot,kind=c_size_t),3)
end function coordinate_handle_size
