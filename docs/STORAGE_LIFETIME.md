# Storage Lifetime for Registered Numeric Dtypes

The five registered descriptor types (`ndarray_bool`, `ndarray_i32`,
`ndarray_i64`, `ndarray_r32`, and `ndarray_r64`) now use the same managed lifetime
contract. This remains a bounded contract: intrinsic Fortran container copying
is not supported. The implementation is checked with GNU Fortran 13.3.0 and 14.2.0 and LLVM
Flang 19.1.1. GNU builds also use runtime checks and AddressSanitizer with leak
detection; see the [compiler matrix](COMPILER_PORTABILITY.md).

## Managed arrays

Owned descriptors allocate a private, dtype-specific backing block containing the reference
count and data buffer. Ordinary scalar descriptor assignment copies metadata and
retains that block; it does not copy values. Views retain the same block. A view
therefore remains valid after its original descriptor is released, reassigned,
or finalized on leaving a procedure.

`copy_r64` remains the way to request independent float64 values; this lifetime
contract does not imply general value-copy or arithmetic support. The separate
float32 binary slice is documented in [dtype support](DTYPE_SUPPORT.md). The public `data`
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
so a reported allocation failure leaves the destination unchanged. Scalar `destination =
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

The suffix follows the descriptor dtype: `share_descriptors_bool`,
`share_descriptors_i32`, `share_descriptors_i64`, `share_descriptors_r32`, or
`share_descriptors_r64`; all are exported by the umbrella `frumpy` module.

Both vectors must have equal length. The operation retains every source before
replacing any destination, including overlapping/reversed sections. It stages
all metadata first, then commits without allocating. A length mismatch or any
staging allocation failure leaves every destination unchanged. Passing `[a, b]`
transiently to concatenate/stack is also tested.

## Explicit limits and remaining work

- **Do not use intrinsic bulk descriptor copying**: whole descriptor-array `=`,
  `allocate(..., source=descriptor)`, or intrinsic copying of enclosing derived
  types can bypass scalar defined assignment and its retain operation. Use
  `share_from` or the matching `share_descriptors_*` routine. General container-copy support remains
  an explicit API restriction. Fortran does not route these operations through
  the scalar assignment binding, so they cannot safely retain managed buffers.
  This restriction is not equivalent to full NumPy-style container behavior.
- A metadata-only descriptor with a caller-attached `data` pointer borrows the
  storage. Release/finalization only detach it; the caller must keep it alive and
  free it. Borrowed aliases do not acquire ownership of an external allocation.
- Reference counts are not atomic. Concurrent descriptor retention/release of a
  shared block requires external synchronization. No thread-safety claim is made.
- Compiler-generated allocations for finalizer scratch arrays and function-result
  metadata do not expose a `STAT` recovery path. The status contract covers
  Frumpy's explicit allocations; it does not promise recovery from arbitrary
  process-wide memory exhaustion. Prefer status-bearing `share_from` to observe
  assignment failures.
- Higher-rank Fortran containers and compiler portability beyond the tested
  configuration need additional work. ndarray rank itself is unaffected.

## Allocatable descriptors and enclosing objects

Allocate a descriptor before assigning or sharing into it. The safe alternative
to `allocate(destination, source=source)` is:

```fortran
type(ndarray_r64), allocatable :: destination

allocate(destination)
call destination%share_from(source, status)
```

For an enclosing derived type, share its ndarray components explicitly or write
an enclosing assignment routine that does so. Do not intrinsically assign the
whole enclosing object. Finalization of a component when its enclosing object
is deallocated is supported and tested. Replacing an `intent(out)` descriptor
also releases its previous reference automatically.

The GCC project has dedicated finalization regression tests covering function
results, scope exit, and allocatable components. Those are useful background,
but Frumpy's own lifetime tests and sanitizer runs are the evidence for this
implementation:
[GNU compiler finalization tests](https://gnu.googlesource.com/gcc/+/refs/heads/releases/gcc-15/gcc/testsuite/gfortran.dg/finalize_50.f90).

## Validation

`test/test_storage_lifetime_r64.f90` exercises constructor/function temporaries,
repeated reassignment, independent copies, returned local views, reverse views,
self-assignment, scalar/empty storage, explicit repeated release, borrowed
buffers, allocatable/enclosing owners, `intent(out)` replacement, and overlapping
descriptor vectors. `test/test_storage_lifetime_dtypes.f90` exercises the same
storage foundation for bool, int32, int64, and float32, including exact int64
payloads beyond float64's integer precision. Empty borrowed self-assignment is
covered for all five types.

`python/fortran/differential_driver.f90` now reads inputs into managed storage
and runs each case in procedure scope. All its inputs, intermediates, float32
and float64 outputs, and integer index outputs finalize before process exit.

Run the standard gate with `make validate`. On the tested Linux/GFortran host,
run the dedicated memory gate with:

```sh
make memory-test
```

It builds separate AddressSanitizer executables in `build/memory`, enables leak
detection, runs both lifetime test programs, float32 arithmetic/reduction
invariants, allocation-failure sweeps, and all compiled Frumpy/NumPy differential
cases through the instrumented driver. The gate uses `-no-pie` on
the tested host; it is optional and not a compiler/platform portability claim.

The test-only C shim uses GNU linker wrappers to fail selected allocations in
scalar sharing, vector sharing, and C/F-order constructors for all five dtypes.
Sharing sweeps every allocation until success and checks that failures preserve
all destinations. Constructor sweeps cover its five explicit allocations; they
exclude later compiler-generated function-result copies. The fault driver alone
uses `-fstack-arrays` to move compiler finalizer scratch off the injected heap.
The lifetime programs and differential driver use the ordinary compiler flags
plus sanitizer instrumentation. This gate needs a C compiler and GNU linker.

Observed on 2026-09-07: `make validate` passed 24 standalone Fortran programs,
the example, and 407 Python tests. `make memory-test` passed both lifetime
programs, float32 arithmetic/reduction invariants, the allocation-failure sweeps,
and all 379 compiled differential cases with no reported leaks or memory errors.
Two expected NumPy warnings remained in the standard gate's
existing empty-mean reference test. These checks cover the exercised paths;
they do not establish safety for the unsupported intrinsic copying forms above.
