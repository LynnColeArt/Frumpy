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

The memory gate instruments lifetime tests, integer, float32 and mixed kernel invariants,
and the compiled differential driver with AddressSanitizer/leak detection. It
also injects selected allocation failures. Compiler-temporary limitations are
described in [STORAGE_LIFETIME.md](STORAGE_LIFETIME.md).
The separate integer overflow gate checks integer/mixed invariant programs and
1,328 integer/mixed NumPy comparisons with `-ftrapv`, `-fsanitize=undefined`, and
`-fno-sanitize-recover=undefined`; it does not enable floating-point traps.

## Observed results on 2026-09-07

| Compiler | Debug suite | Optimized suite | GNU memory gate | Integer overflow gate |
| --- | --- | --- | --- | --- |
| GNU Fortran 13.3.0 | Pass | Pass | Pass | Pass |
| GNU Fortran 14.2.0 | Pass | Pass | Pass | Pass |
| LLVM Flang 19.1.1 | Pass | Pass | Not run | Not run |

Both GNU memory gates reported no leaks or memory errors on the exercised
paths. The ordinary Python suite emitted two expected warnings from its
existing empty-mean NumPy reference fixture.

## Scope of the evidence

The matrix covers 26 Fortran test programs, one example, and 1,840 Python tests
(1,812 compiled Frumpy/NumPy comparisons plus 28 NumPy oracle fixtures). The
float32 cases include exact results, signed zeros, NaNs/infinities, scalar and
empty broadcasting, signed/zero strides, reduction axes, keepdims, empty-axis
identities, pairwise summation, and seven unary functions. Unary comparisons
include seeded float32 bit patterns, domain/range events, and a four-ULP finite
result threshold, described in [dtype support](DTYPE_SUPPORT.md#float32-unary-arithmetic).
The [reduction numerical contract](FLOAT32_REDUCTIONS.md)
records intentional rounding-order differences. Lifetime tests cover all five
registered dtypes and the explicit descriptor-vector sharing API. The integer
cases cover both widths, four operations, exact full-range modular results,
float64 true division, broadcasting, and signed/zero strides; see
[integer arithmetic](INTEGER_ARITHMETIC.md). Mixed arithmetic adds 1,200 cases
covering every ordered registered dtype pair, output types, random values,
strides, boolean semantics and invalid shapes. Typed-result replacement and
failure preservation are checked in Fortran; see
[mixed arithmetic](MIXED_ARITHMETIC.md).

These are executable compatibility checks, not a general certification of
Fortran portability. Intrinsic copying of descriptor containers remains
unsupported. Intel, NVIDIA, other compiler releases, Windows, macOS, ARM,
thread-safe reference counting, and compiler-generated allocation-failure
recovery have not been established by this matrix. Flang memory sanitization
has not been claimed; the sanitizer gate is GNU/Linux-specific.
