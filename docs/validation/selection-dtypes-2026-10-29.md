# Five-dtype selection validation

This change extends same-dtype where, take, concatenate and stack from float64
to bool/int32/int64/float32 across native generics, ABI v1 and Python. Float64
kernels are retained. The contract is in [SELECTION_DTYPES.md](../SELECTION_DTYPES.md).
Base: `f522bc5` (PR #3 merged). No version bump or release publication is included.

## Checks

- GNU Fortran 14.2 strict debug: 42 native programs, two examples, standalone C
  caller and 7,966 Python cases pass.
- GNU 13 debug/optimized and GNU 14 debug/optimized: 7,961 cases plus the final
  five installed-package regressions in separate focused runs pass, along with
  the native/example/C gates. Hosted CI checks the combined final count.
- 602 dedicated selection cases compare native, direct ABI and Python behavior
  with NumPy, including irregular layouts, empty/scalar shapes, variable-length
  concatenation, exact int64 values, bool normalization, mixed-dtype rejection,
  floating bit preservation and result lifetime after releasing inputs.
- GNU 14 native ASan/leak and allocation-failure checks pass, including the new
  native selection invariants; 2,647 compiled differential cases pass.
- GNU 14 native signed-overflow/UBSan gate passes, including huge zero-stride
  selection metadata; 2,159 selected differential cases pass. A separate run of
  all 602 selection cases passes against UBSan-instrumented native/C builds.
- C ASan/leak caller passes. 5,286 C/Python address-check cases plus the final
  five package regressions pass. Python-process leak detection is disabled;
  native leak checks remain enabled.
- Source archive builds and installs without cache into a fresh venv. All 391
  committed public package tests pass from outside the repository with Python
  `-I`, without `PYTHONPATH`, `FRUMPY_LIBRARY` or checkout imports. New selection
  cases are now part of that persistent installed-package gate.
- `git diff --check` passes. Fresh Mac validation is not claimed. Flang 19 is
  unavailable locally; its coverage is reported by hosted CI on the review PR.

Linux x86-64, Python 3.12.3, NumPy 2.4.6; local builds link reference LP64
BLAS/LAPACK using `LINALG_LIBS='-l:liblapack.so.3 -l:libblas.so.3'`.

```sh
make validate FC=gfortran-14 BUILD_DIR=build/selection-dtypes/debug
make memory-test integer-overflow-test c-memory-test FC=gfortran-14 BUILD_DIR=build/selection-dtypes
bash scripts/validate_compilers.sh build/selection-dtypes/portability gfortran-13 gfortran-14
```

The added native program is included in Make, fpm auto-discovery, ASan and
integer-overflow targets. The selection differential file is included in the
C/Python memory gate. Existing compiler-generated allocation/finalization
limitations remain; no claim of general allocation-failure recovery is added.

## Review findings addressed

The new scalar cases exposed existing Python wrapper inconsistencies. Scalar
`take` now accepts axes 0/-1, matching its native kernel and NumPy; scalar
concatenation reports ValueError before axis normalization. The C take boundary
also rejects index-buffer byte-count overflow before associating the pointer.
The new kernels validate all inputs and indices before copying/allocating output,
check shape/byte arithmetic, and retain exact dtype payloads without casting.

Performance optimization and mixed-dtype promotion are outside this slice.
No new speed claim is made.
