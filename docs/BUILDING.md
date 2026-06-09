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
- `make`.
- `python3` with `venv` support for NumPy differential tests.
- Optional: `fpm` for Fortran package-manager builds.

Do not install Python packages into the host interpreter for this project. The
Makefile creates and uses `.venv/`, which is ignored by git.

## Make Targets

| Target | Purpose |
| --- | --- |
| `make build` | Compile the current Frumpy modules in explicit dependency order. |
| `make test` | Compile and run every standalone Fortran test program. |
| `make examples` | Compile and run example programs, including the first vertical slice. |
| `make python-test` | Create `.venv/` if needed, install `pytest` and `numpy`, and run `python/tests`. |
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

On first run it creates `.venv/` and installs `pytest` and `numpy` there. If
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
- `test/test_constructors_r64.f90`
- `test/test_broadcast.f90`
- `test/test_elementwise_r64.f90`
- `test/test_reductions_r64.f90`
- `test/test_views_r64.f90`

Compiler flags default to:

```text
-std=f2018 -Wall -Wextra -Werror -fimplicit-none -fcheck=all -fbacktrace
```

Override `FC`, `FFLAGS`, `PYTHON`, `FPM`, `BUILD_DIR`, or `VENV` on the command
line when needed.
