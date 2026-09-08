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

For GNU builds, run the separate allocation/lifetime gate:

```sh
make memory-test FC=gfortran-13 BUILD_DIR=build/gcc13
make memory-test FC=gfortran-14 BUILD_DIR=build/gcc14
```

This instruments the lifetime tests, float32 arithmetic/reduction invariants
and compiled differential driver with AddressSanitizer/leak detection, and injects selected allocation failures. Its
compiler-temporary limitations are described in [STORAGE_LIFETIME.md](STORAGE_LIFETIME.md).

## Observed results on 2026-09-07

| Compiler | Debug suite | Optimized suite | GNU memory gate |
| --- | --- | --- | --- |
| GNU Fortran 13.3.0 | Pass | Pass | Pass |
| GNU Fortran 14.2.0 | Pass | Pass | Pass |
| LLVM Flang 19.1.1 | Pass | Pass | Not run |

Both GNU memory gates reported no leaks or memory errors on the exercised
paths. The ordinary Python suite emitted two expected warnings from its
existing empty-mean NumPy reference fixture.

## Scope of the evidence

The matrix covers 24 Fortran test programs, one example, and 512 Python tests
(484 compiled Frumpy/NumPy comparisons plus 28 NumPy oracle fixtures). The
float32 cases include exact results, signed zeros, NaNs/infinities, scalar and
empty broadcasting, signed/zero strides, reduction axes, keepdims, empty-axis
identities, pairwise summation, and seven unary functions. Unary comparisons
include seeded float32 bit patterns, domain/range events, and a four-ULP finite
result threshold, described in [dtype support](DTYPE_SUPPORT.md#float32-unary-arithmetic).
The [reduction numerical contract](FLOAT32_REDUCTIONS.md)
records intentional rounding-order differences. Lifetime tests cover all five
registered dtypes and the explicit descriptor-vector sharing API.

These are executable compatibility checks, not a general certification of
Fortran portability. Intrinsic copying of descriptor containers remains
unsupported. Intel, NVIDIA, other compiler releases, Windows, macOS, ARM,
thread-safe reference counting, and compiler-generated allocation-failure
recovery have not been established by this matrix. Flang memory sanitization
has not been claimed; the sanitizer gate is GNU/Linux-specific.
