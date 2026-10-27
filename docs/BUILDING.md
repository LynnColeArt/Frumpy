# Building Frumpy

Frumpy's canonical local validation path is:

```sh
make validate
```

That target keeps the project boring to check out, build, and test. It runs the
standalone Fortran test suite, the first vertical-slice example, Python NumPy
differential tests from a repo-local virtual environment, and `git diff --check`.

## Prerequisites

- `gfortran` with Fortran 2018 support. Current local validation uses GNU
  Fortran 13.x.
- Compatible LP64 BLAS/LAPACK development libraries.
- `make`.
- `python3` with `venv` support for NumPy differential tests.
- Optional memory gate: a C compiler, GNU linker, and AddressSanitizer on Linux.
- Optional: `fpm` for Fortran package-manager builds.

Do not install Python packages into the host interpreter for this project. The
Makefile creates and uses `.venv/`, which is ignored by git.

## BLAS/LAPACK linking

Make links with `LINALG_LIBS ?= -llapack -lblas`. Pass a different `LINALG_LIBS`
value to select a compatible backend. With only versioned runtime libraries on
Linux, the tested override is `LINALG_LIBS='-l:liblapack.so.3 -l:libblas.so.3'`.
The fpm manifest declares `lapack` and `blas` as link dependencies. See
[linear algebra](LINEAR_ALGEBRA.md) for ABI and numerical limits.

## Make Targets

| Target | Purpose |
| --- | --- |
| `make build` | Compile the current Frumpy modules in explicit dependency order. |
| `make test` | Compile and run every standalone Fortran test program. |
| `make examples` | Compile and run example programs, including the first vertical slice. |
| `make python-test` | Create `.venv/` if needed, install `pytest` and `numpy`, and run `python/tests`. |
| `make integer-overflow-test` | Run integer/mixed and linear algebra invariants and NumPy comparisons with GNU signed-overflow traps and undefined-behavior sanitization. |
| `make portability-test` | Validate debug and optimized builds with each compiler in `COMPILERS`; see the portability matrix. |
| `make memory-test` | Run ownership and numeric invariant programs, allocation-failure sweeps, and compiled differential cases under AddressSanitizer with leak detection on GNU/Linux. |
| `make fpm-test` | Run `fpm test` when `fpm` is installed; otherwise explain that fpm is optional. |
| `make validate` | Run Fortran tests, examples, Python differential tests, and whitespace checks. |
| `make clean` | Remove local build products and Python test caches. |

The Makefile intentionally lists source files in dependency order instead of
discovering them dynamically. That makes module ordering reviewable and avoids
hidden build-system behavior while Frumpy is still small.

## Python Differential Tests

`make python-test` uses:

```sh
.venv/bin/python -m pytest -q python/tests
```

The target also compiles `python/fortran/differential_driver.f90` and passes its
absolute path to pytest. `test_frumpy_differential.py` executes that driver and
compares actual Frumpy outputs with NumPy. The older `test_numpy_*.py` files
check NumPy reference fixtures only. Direct pytest invocation builds the driver
in an isolated temporary directory and fails if the compiler/build fails.

On first run it creates `.venv/` and installs `python/requirements-test.txt`
there. NumPy is pinned to `2.4.6`, matching the dtype oracle fixtures; changing
the oracle requires updating those fixtures and the requirement together. If
dependencies need to be refreshed, remove `.venv/.frumpy-python-deps` or recreate
the virtual environment.

## fpm

`fpm.toml` describes Frumpy as a library package with auto-discovered tests and
examples. On this host, `fpm` is not currently installed, so `fpm test` was not
part of WP01 validation. `make validate` is the mission's canonical local gate.

If `fpm` is available on your machine, run:

```sh
make fpm-test
```

If `fpm test` diverges from `make test`, treat `make validate` as authoritative
until the fpm-specific issue is documented and fixed.

## Current Fortran Test Programs

`make test` runs:

- `test/test_statuses.f90`
- `test/test_dtypes.f90`
- `test/test_dtype_promotion.f90`
- `test/test_casting.f90`
- `test/test_shape.f90`
- `test/test_strides.f90`
- `test/test_ndarray_bool.f90`
- `test/test_ndarray_i32.f90`
- `test/test_ndarray_i64.f90`
- `test/test_ndarray_r32.f90`
- `test/test_ndarray_r64.f90`
- `test/test_storage_lifetime_r64.f90`
- `test/test_storage_lifetime_dtypes.f90`
- `test/test_constructors_r64.f90`
- `test/test_broadcast.f90`
- `test/test_linalg_r64.f90`
- `test/test_arithmetic.f90`
- `test/test_elementwise_integer.f90`
- `test/test_elementwise_r32.f90`
- `test/test_elementwise_r64.f90`
- `test/test_reductions_r32.f90`
- `test/test_reductions_r64.f90`
- `test/test_views_r64.f90`
- `test/test_selection_r64.f90`
- `test/test_selection_validation.f90`
- `test/test_sorting_r64.f90`
- `test/test_searching_r64.f90`

Compiler flags default to:

```text
-std=f2018 -Wall -Wextra -Werror -fimplicit-none -fcheck=all -fbacktrace
```

Override `FC`, `FFLAGS`, `PYTHON`, `FPM`, `BUILD_DIR`, or `VENV` on the command
line when needed.

For an independent fresh build without removing existing build products:

```sh
make validate BUILD_DIR=build/review
```

Make serializes builds because compiler module files are shared within a build directory. Use separate
`BUILD_DIR` values for concurrent make processes.

The numeric-descriptor lifetime and `make memory-test` gate are documented in
[STORAGE_LIFETIME.md](STORAGE_LIFETIME.md).

See [COMPILER_PORTABILITY.md](COMPILER_PORTABILITY.md) for the tested compiler
matrix and [PERFORMANCE.md](PERFORMANCE.md) for reproducible timed comparisons.

## Native C/Python release surface

`make shared` builds `$(BUILD_DIR)/libfrumpy.so`; `make c-test` compiles and runs
`c_tests/test_c_api.c`. `make validate` includes those checks and the direct ABI
and public package tests, in addition to the native/NumPy suite. The core is
compiled once into PIC objects per build directory and reused by executables
and the shared library. Use a fresh `BUILD_DIR` (or clean it) when changing
compiler or flags; module files and object profiles must not be mixed.

`make c-memory-test FC=gfortran-14` checks standalone C ownership with ASan/leak
detection, then the ABI/Python suite with ASan address checks. Only the Python
process disables leak detection to exclude CPython/NumPy global allocations.
The native memory and integer-overflow gates remain separate.

See [PYTHON.md](PYTHON.md) for isolated source installation and [C_ABI.md](C_ABI.md)
for buffer, status and serialization requirements. `examples/v01_workflow.f90`
and `examples/v01_workflow.py` show equivalent workflows, including ownership
and NumPy-checked results. The GitHub workflow `.github/workflows/linux.yml`
defines the supported Linux matrix, GNU sanitizers, fpm and source-install jobs.
