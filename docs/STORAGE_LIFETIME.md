# Float64 Storage Lifetime — First Implementation

This branch introduces reference-counted storage for `ndarray_r64`. It is a first
slice, not a complete lifetime guarantee for every Fortran copying construct or
every Frumpy dtype. The current implementation is checked with GNU Fortran
13.3.0, Fortran 2018 runtime checks, and AddressSanitizer with leak detection.

## Managed float64 arrays

Float64 constructors allocate a private backing block containing the reference
count and data buffer. Ordinary scalar descriptor assignment copies metadata and
retains that block; it does not copy values. Views retain the same block. A view
therefore remains valid after its original descriptor is released, reassigned,
or finalized on leaving a procedure.

`copy_r64` remains the way to request independent values. The public `data`
pointer remains available for value access; do not deallocate or retarget it on
a managed descriptor. The backing block is private and determines reclamation.
`owns_data` continues to distinguish original allocated results from views; it
is no longer an instruction to free a raw pointer. Both retain managed storage.

```fortran
use frumpy, only: ndarray_r64, full_r64, reshape_r64, frumpy_status
use iso_fortran_env, only: int64, real64

type(ndarray_r64) :: owner, view
type(frumpy_status) :: status

owner = full_r64([6_int64], 4.0_real64, status=status)
view = reshape_r64(owner, [2_int64, 3_int64], status)
call owner%release()
! view still retains and can access the six values.
call view%release()
```

`release()` is idempotent. It drops this descriptor's storage reference, clears
shape/strides and contiguity flags, and frees the backing block only when its
last reference goes away. Scalar and array finalization call the same release
path. Main-program and saved variables require explicit release when timely
reclamation is needed; do not rely on finalization at program termination.

`call destination%share_from(source, status)` is the recoverable assignment API.
It snapshots metadata and retains the source before releasing the destination,
so allocation failure leaves the destination unchanged. Scalar `destination =
source` invokes the same operation without a status argument; as with other
status-optional APIs, use the explicit call when failure must be observed.
Self-assignment and replacement with a view of the destination are tested.

## Vectors of descriptors

An ndarray can have any supported ndarray rank. A **Fortran array containing
multiple ndarray descriptors** is a separate concept.

For copying vectors of descriptors, allocate the destination vector first and
use the explicit API:

```fortran
use frumpy, only: ndarray_r64, share_descriptors_r64, frumpy_status

type(ndarray_r64), allocatable :: sources(:), destinations(:)
type(frumpy_status) :: status

allocate(sources(2), destinations(2))
! Populate sources through Frumpy constructors.
call share_descriptors_r64(destinations, sources, status)
call share_descriptors_r64(destinations, destinations(2:1:-1), status)
```

Both vectors must have equal length. The operation retains every source before
replacing any destination, including overlapping/reversed sections. A length
mismatch or snapshot allocation failure leaves the destination unchanged. A
later allocation failure during destination replacement may leave a prefix
updated; all descriptors retain valid lifetime bookkeeping and status reports
the failure. Passing `[a, b]` transiently to concatenate/stack is also tested.

## Explicit limits and remaining work

- **Do not use intrinsic bulk descriptor copying**: whole descriptor-array `=`,
  `allocate(..., source=descriptor)`, or intrinsic copying of enclosing derived
  types can bypass scalar defined assignment and its retain operation. Use
  `share_from` or `share_descriptors_r64`. General container-copy support remains
  an open design issue; these restrictions must be resolved or deliberately
  accepted before treating lifetime management as complete.
- A metadata-only descriptor with a caller-attached `data` pointer borrows the
  storage. Release/finalization only detach it; the caller must keep it alive and
  free it. Borrowed aliases do not acquire ownership of an external allocation.
- Boolean, int32, int64, and float32 descriptors still use the earlier unmanaged
  storage model. Generalizing the float64 design comes after this contract is
  reviewed, not by copying it into every dtype immediately.
- Reference counts are not atomic. Concurrent descriptor retention/release of a
  shared block requires external synchronization. No thread-safety claim is made.
- Higher-rank Fortran containers and compiler portability beyond the tested
  configuration need additional work. ndarray rank itself is unaffected.

The GCC project has dedicated finalization regression tests covering function
results, scope exit, and allocatable components. Those are useful background,
but Frumpy's own lifetime tests and sanitizer runs are the evidence for this
implementation:
[GNU compiler finalization tests](https://gnu.googlesource.com/gcc/+/refs/heads/releases/gcc-15/gcc/testsuite/gfortran.dg/finalize_50.f90).

## Validation

`test/test_storage_lifetime_r64.f90` runs constructor/function temporaries,
repeated reassignment, independent copies, returned local views, reverse views,
self-assignment, scalar/empty storage, explicit repeated release, borrowed
buffers, and overlapping descriptor vectors. Tests run inside procedures so
scope-exit finalization is exercised, rather than relying on program shutdown.

Run the standard gate with `make validate`. On the tested Linux/GFortran host,
run the focused memory check with a separate build directory:

```sh
make BUILD_DIR=build/lifetime-asan \
  FFLAGS='-std=f2018 -Wall -Wextra -Werror -fimplicit-none -fcheck=all -fbacktrace -g -fsanitize=address -fno-omit-frame-pointer -no-pie' \
  build/lifetime-asan/bin/test_storage_lifetime_r64
ASAN_OPTIONS=detect_leaks=1 build/lifetime-asan/bin/test_storage_lifetime_r64
```

The focused executable uses only managed float64 allocations and borrowed stack
storage. Its leak-free result does not claim that older dtype tests or the
entire current library are leak-free.

Observed on 2026-09-07: `make validate` passed 21 standalone Fortran programs,
the example, and 157 Python tests. The focused AddressSanitizer executable
passed with leak detection enabled and no reported leaks or memory errors.
Two expected NumPy warnings remained in the existing empty-mean reference test.
