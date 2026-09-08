# Frumpy

Frumpy is a Fortran 2018 NumPy-compatible array engine.

It exists because numerical software does not have to be a C++ template jungle
or a Python wrapper labyrinth. It can be direct, readable, explicit, and still
fast.

Frumpy's goal is to provide a NumPy-shaped foundation for native Fortran array
programming: an ndarray substrate with familiar semantics, explicit memory
behavior, and source code that remains understandable when you open it.


## Why Fortran?

Fortran is not a nostalgia choice here. It is the point.

We are building Frumpy in Fortran because:

- Fortran is comfortable for this kind of numerical work.
- Fortran's array-oriented model makes dense numerical code easy to follow.
- Modern Fortran can be explicit, strongly typed, modular, and fast.
- Scientific software deserves infrastructure that is readable, not just
  clever.
- The language has earned its place in numerical computing, and it still has
  things to say.

Frumpy is a deliberate argument:

> Modern numerical infrastructure can be fast, explicit, and humane.


## What Frumpy Wants To Be

Frumpy is not trying to make Fortran feel like Python. It is trying to implement
the array semantics NumPy users already understand, using Fortran's strengths.

That means:

- NumPy-compatible shape behavior.
- Explicit dtype handling.
- Broadcasting.
- Views and copies with clear ownership rules.
- Strides, offsets, and contiguity metadata.
- Reductions over axes.
- Linear algebra backed by proven numerical libraries.
- A stable interop boundary for Python, C, and other runtimes.

The first serious milestone is the ndarray core. Everything else builds from
there.


## Design Direction

The intended architecture is:

```text
NumPy-compatible Frumpy API
        |
Fortran 2018 ndarray runtime
        |
Shape, stride, dtype, memory, and kernel dispatch
        |
BLAS/LAPACK and native Fortran kernels
        |
C ABI and Python bindings later
```

Frumpy is scoped to NumPy right now. Future projects may find it useful as a
numerical floor, but Torch compatibility, Diffusers support, autograd, model
loading, and GPU runtime design are not part of the current project scope.


## Compatibility Philosophy

NumPy compatibility is a contract.

If Frumpy behaves differently from NumPy, the difference must be intentional,
documented, and tested. This is especially important for:

- Broadcasting.
- Dtype promotion.
- Axis behavior.
- Empty arrays.
- Singleton dimensions.
- Views versus copies.
- C-order and Fortran-order memory layout.
- Error behavior.

Frumpy's public semantics should be NumPy-shaped even when the implementation is
deeply Fortran-native.


## Project Standards

See [STYLE_GUIDE.md](STYLE_GUIDE.md) for the coding standards.

The short version:

- Use explicit kinds.
- Keep modules private by default.
- Name shape, axis, stride, and dtype concepts precisely.
- Do not hide copies.
- Do not let Fortran's default memory order leak through public behavior by
  accident.
- Test compatibility against NumPy.
- Keep the code readable enough that the next person can follow it without a
  decoder ring.


## Status

Frumpy has a working float64 array core: descriptors, constructors, broadcasting,
elementwise arithmetic, reductions, views, and slicing. Boolean, int32, int64,
and float32 descriptors plus dtype promotion and scalar casting policies are
also implemented. Float32 supports binary arithmetic with broadcasting; negation,
absolute value, square root, exp, log, sine and cosine; and sum, product, mean,
minimum and maximum reductions. See the
[float32 unary contract](docs/DTYPE_SUPPORT.md#float32-unary-arithmetic) and the
[float32 reduction contract](docs/FLOAT32_REDUCTIONS.md) for axes and numerical
limits. Int32 and int64 support add, subtract, multiply, and float64 true
division with broadcasting; see [integer arithmetic](docs/INTEGER_ARITHMETIC.md).
Broader dtype kernels and mixed-dtype execution remain future work.

The selection subset adds `where`, `take`, `concatenate`, `stack`, stable sorting,
`argsort`, `searchsorted`, and flat nonzero indices. See
[selection support](docs/SELECTION_SUPPORT.md) for the exact contract and limits,
and [dtype support](docs/DTYPE_SUPPORT.md) for the type coverage matrix.

Run `make validate` to compile/run Fortran tests and the example, execute Python
reference fixtures and direct Frumpy-versus-NumPy comparisons, and check patch
whitespace. See [building](docs/BUILDING.md), [compiler portability](docs/COMPILER_PORTABILITY.md),
and [performance measurements](docs/PERFORMANCE.md).

Linear algebra, random generation, a C ABI, Python bindings, and measured
performance work remain unfinished. Managed storage for all five registered
dtypes now retains aliases and views, with explicit limits on Fortran container
copying. Borrowed external buffers still require caller lifetime management. See
[storage lifetime](docs/STORAGE_LIFETIME.md). This is not yet a drop-in NumPy
replacement.
