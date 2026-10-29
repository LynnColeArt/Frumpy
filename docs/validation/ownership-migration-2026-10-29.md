# Managed ownership migration: issue #2

Baseline: v0.1.0 (`66210871a033d1182cf3f334dab687cce364d1fd`).
[Issue and Linux reproduction](https://github.com/LynnColeArt/Frumpy/issues/2#issuecomment-6495652706).

## Reproduction

The ticket's downstream Fortran/ctypes adapter was built against a clean export
of the release on Linux x86-64, GNU Fortran 14.2.0 and Python 3.12.3. Ordinary
execution aborted with SIGABRT (-6), `free(): double free detected in tcache 2`.
With both the core and adapter instrumented, AddressSanitizer reported allocation
in `owned_descriptor_r64`, the first free at the adapter's manual deallocation,
and the second through `ndarray_r64_finalize` and `ndarray_r64_release`.

Replacing only raw `deallocate(output%data)` with `call output%release()` passed
10,000 calls with correct values, exit zero and empty stderr in ordinary and
ASan builds. Python ASan used `detect_leaks=0:halt_on_error=1`; no Python-process
leak claim follows. This reproduces a legacy downstream contract violation;
there is no upstream production adapter fix in this change.

## Audit

Reviewed deallocations, data-pointer associations and cleanup in tracked native
sources, benchmarks, examples, Python/Fortran bridges, C callers and tests.
A case-insensitive multiline search for `deallocate(...)` and `%data =>`, plus
Python/C `free` and release calls, supported the manual review.

- No upstream adapter directly deallocates a descriptor's public data pointer.
- All five `frumpy_ndarray_*` modules reclaim private backing values only through
  their reference-counted release routines. Their data associations implement
  construction, retained sharing and views.
- `frumpy_c_handles` deallocates the scalar polymorphic descriptor, which invokes
  finalization, then the slot. Its registry bucket allocation is unrelated to
  numerical payload ownership.
- `frumpy_operands` holds call-scoped, non-owning typed pointers; it does not free
  their payloads. Metadata-only borrows in tests intentionally attach external
  storage; malformed-descriptor tests alter metadata to exercise validation.
- The Python package calls `frumpy_release` through an `OwnedHandle` finalizer;
  `close()` invokes that finalizer once. The differential driver uses managed
  procedure-local descriptors. C callers use the published handle ABI.

The deliberately broken adapter is retained only in ignored local reproduction
files, not production sources or the regular test suite.

## Added regression coverage

The native lifetime program repeats a small adapter-style addition 10,000 times,
borrowing external inputs and retaining a view of its owned result. It alternates
explicit repeated release with automatic cleanup, checks views after owner
release, exercises empty arrays and incompatible-shape failure cleanup, and
checks caller-owned input values survive. Procedure exit exercises finalization
of both released descriptors and still-live views. Existing lifetime programs
cover the other four dtype implementations and allocation-failure recovery.

The ctypes boundary suite adds ten cases (all five dtypes, empty/nonempty).
Each repeats 1,000 import/add/view/export/release cycles, releases inputs and the
result before reading the view, checks caller buffers, and verifies failed
shape/invalid-handle calls clear output handles. Native repeated release is safe;
releasing a stale C handle must instead return status 8.

Both additions run through existing validation and memory targets. The native
memory gate checks leaks; C/Python address checks exclude Python-process leak
detection. No ABI, production kernel, storage layout or release artifact changes.

## Validation

Linux x86-64, Python 3.12.3 / NumPy 2.4.6, reference LP64 BLAS/LAPACK:

- GNU 14.2 strict debug: 41 native programs, two examples, C caller and **7,359
  Python tests** passed (12 expected oracle warnings).
- GNU 13 debug and optimized: the same full suite passed in both profiles.
- GNU 14 `make memory-test`: native invariants, the repeated adapter-cleanup
  regression and allocation-failure tests passed with ASan leak detection;
  **2,647 differential tests** passed (four oracle warnings).
- GNU 14 `make c-memory-test`: standalone C leak checks and **4,684 C/Python
  tests** passed (six oracle warnings). Python address checks disable leak
  detection for interpreter/NumPy process globals.
- `git diff --check` passed. Flang 19 was unavailable locally; no fresh local
  Flang or Mac validation is claimed. Hosted CI is reported on the review PR.

Commands used `LINALG_LIBS='-l:liblapack.so.3 -l:libblas.so.3'`:

```sh
make validate FC=gfortran-14 BUILD_DIR=build/issue-2-validation/debug
make memory-test c-memory-test FC=gfortran-14 BUILD_DIR=build/issue-2-validation
bash scripts/validate_compilers.sh build/issue-2-validation/portability gfortran-13
```

Local log SHA-256 values (logs are not bundled in the source package):

- `/tmp/frumpy-issue2-debug.log`: `e52057210b613aa9776538790459bdcb3c13f4c5558f45cddcb14e537cc571ed`.

- `/tmp/frumpy-issue2-memory.log`: `b3ed2f042ef5ca3d7417f1f1b547d6447b2d344102b2cf9af7b49754e16325a0`.

- `build/issue-2-validation/portability/gfortran-13/release.cu3UMT/validation.log`: `397391de4d2de6f40ef95fd550ab2373da578ac6922443e217ad933f2c55cd2a`.

- `build/issue-2-validation/portability/gfortran-13/debug.TBqZWn/validation.log`: `c0d39c0a454caf1ef2379db93adf2043bcbea2c6432922a7e34ca861c385ead9`.
