# Compiler portability

Frumpy's supported contract is checked on Linux x86-64 using GNU Fortran 13.3.0,
GNU Fortran 14.2.0, and LLVM Flang 19.1.1. The independent compiler family matters:
managed descriptor lifetime depends on defined assignment and finalization,
including function results, views, procedure exit, and allocatable components.

## Repeat the matrix

Provide the selected compiler executables on `PATH`, then run:

```sh
make portability-test COMPILERS='gfortran-13 gfortran-14 flang-new-19'
```

The target runs `make validate` twice per compiler, with separate debug and
optimized module/executable directories under `build/portability`. Each run
creates fresh directories so a changed compiler cannot reuse stale modules. It records
compiler versions, flags, and complete output in each directory's
`validation.log`. Missing compilers or a failing build/test stop the gate;
compilers are never silently skipped. Absolute compiler paths also work.

| Compiler | Debug flags | Optimized flags |
| --- | --- | --- |
| GNU Fortran 13 / 14 | `-std=f2018 -Wall -Wextra -Werror -fimplicit-none -fcheck=all -fbacktrace` | `-std=f2018 -O3 -fimplicit-none` |
| LLVM Flang 19 | `-O0 -g -Werror` | `-O3 -Werror` |

Flang's flags differ from GNU's; its debug build does not claim GNU's runtime
bounds-check coverage. The [official Flang driver documentation](https://flang.llvm.org/docs/FlangDriver.html)
explains the compiler driver and option handling. Fast-math is not used in any
of these configurations.

For GNU builds, run the separate memory and integer overflow gates:

```sh
make memory-test FC=gfortran-13 BUILD_DIR=build/gcc13
make memory-test FC=gfortran-14 BUILD_DIR=build/gcc14
make integer-overflow-test FC=gfortran-13 BUILD_DIR=build/gcc13
make integer-overflow-test FC=gfortran-14 BUILD_DIR=build/gcc14
```

The memory gate instruments lifetime tests, integer, float32, mixed and linear algebra invariants,
and the compiled differential driver with AddressSanitizer/leak detection. It
also injects selected allocation failures. Compiler-temporary limitations are
described in [STORAGE_LIFETIME.md](STORAGE_LIFETIME.md).
The separate integer overflow gate checks integer/mixed and linear algebra
invariant programs and 2,159 NumPy comparisons with `-ftrapv`, `-fsanitize=undefined`, and
`-fno-sanitize-recover=undefined`; it does not enable floating-point traps.

## Observed results on 2026-10-26

| Compiler | Debug suite | Optimized suite | GNU memory gate | Integer overflow gate |
| --- | --- | --- | --- | --- |
| GNU Fortran 13.3.0 | Pass | Pass | Pass | Pass |
| GNU Fortran 14.2.0 | Pass | Pass | Pass | Pass |
| LLVM Flang 19.1.1 | Pass | Pass | Not run | Not run |

All configurations linked the system reference BLAS/LAPACK 3.12.0 LP64 runtimes
using `LINALG_LIBS='-l:liblapack.so.3 -l:libblas.so.3'`; these Linux-specific link
flags are recorded in the matrix logs. See [linear algebra](LINEAR_ALGEBRA.md)
for the conventional `-llapack -lblas` development-library default and ABI limits.

Both GNU memory gates reported no leaks or memory errors on the exercised
native paths. Each ordinary configuration passes **35 Fortran test programs,
two examples, 2,758 Python tests, and the standalone C ownership caller**.
The Python total comprises 2,643 compiled native differential cases, 28 NumPy
oracle fixtures, 49 direct ABI tests and 38 public package tests. Six expected
warnings come from NumPy's empty-mean oracle cases.

Both GNU memory suites pass 2,643 compiled comparisons plus lifetime,
allocation-failure and native invariant programs. Both overflow suites pass
2,159 comparisons (484 unrelated cases deselected). Both C memory suites pass
the standalone caller with leak detection and 87 ABI/package cases with address
checks; only the Python process disables leak detection for CPython/NumPy
process-global allocations. Flang sanitization is not claimed.

fpm 0.12.0 passes all 35 native programs with GNU 14 and the Ubuntu
BLAS/LAPACK 3.12.0 development archives extracted into an isolated SDK and supplied
through LIBRARY_PATH. This exercises the conventional `-llapack -lblas` route,
without changing the host package installation. The source archive builds and
installs into a separate virtual environment; all 38 public API tests and the
workflow example pass there without source-tree imports or library overrides.

The measured source snapshot is `3e1a191`. [Machine-readable acceptance evidence](validation/v0.1.json)
records suite counts, configurations and SHA-256 hashes of the complete local
logs. The [operation table](V0_1_COVERAGE.md) maps the exercised surface and its
numerical limits. The GitHub workflow mirrors the matrix, GNU gates, fpm and
clean source installation; a hosted CI execution is not claimed by local results.

## Scope of the evidence

These checks include managed lifetime and views for all five dtypes, modular
integer arithmetic, every mixed arithmetic dtype pair, casts/comparisons,
integer/bool/float reductions, selection/indexing, float64 dot/norms/batched
solve, random state, C handles and Python ownership/coercion. The release-edge
regression tests cover byte-count overflow, nonfinite arange and malformed
float64 copies. Explicit Fortran container-copy restrictions remain in force.

These are executable compatibility checks, not a general certification of
Fortran portability. Intrinsic copying of descriptor containers remains
unsupported. Intel, NVIDIA, other compiler releases, Windows, macOS, ARM,
thread-safe reference counting, and compiler-generated allocation-failure
recovery have not been established by this matrix. Flang memory sanitization
has not been claimed; the sanitizer gate is GNU/Linux-specific.
