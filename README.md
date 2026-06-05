# Fenum

Fenum is a Fortran 2018 NumPy-compatible array engine.

It exists because numerical software does not have to be a C++ template jungle
or a Python wrapper labyrinth. It can be direct, readable, explicit, and still
fast.

Fenum's goal is to provide a NumPy-shaped foundation for native Fortran array
programming: an ndarray substrate with familiar semantics, explicit memory
behavior, and source code that remains understandable when you open it.


## Why Fortran?

Fortran is not a nostalgia choice here. It is the point.

We are building Fenum in Fortran because:

- Fortran is comfortable for this kind of numerical work.
- Fortran's array-oriented model makes dense numerical code easy to follow.
- Modern Fortran can be explicit, strongly typed, modular, and fast.
- Scientific software deserves infrastructure that is readable, not just
  clever.
- The language has earned its place in numerical computing, and it still has
  things to say.

Fenum is a deliberate argument:

> Modern numerical infrastructure can be fast, explicit, and humane.


## What Fenum Wants To Be

Fenum is not trying to make Fortran feel like Python. It is trying to implement
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
NumPy-compatible Fenum API
        |
Fortran 2018 ndarray runtime
        |
Shape, stride, dtype, memory, and kernel dispatch
        |
BLAS/LAPACK and native Fortran kernels
        |
C ABI and Python bindings later
```

Fenum is scoped to NumPy right now. Future projects may find it useful as a
numerical floor, but Torch compatibility, Diffusers support, autograd, model
loading, and GPU runtime design are not part of the current project scope.


## Compatibility Philosophy

NumPy compatibility is a contract.

If Fenum behaves differently from NumPy, the difference must be intentional,
documented, and tested. This is especially important for:

- Broadcasting.
- Dtype promotion.
- Axis behavior.
- Empty arrays.
- Singleton dimensions.
- Views versus copies.
- C-order and Fortran-order memory layout.
- Error behavior.

Fenum's public semantics should be NumPy-shaped even when the implementation is
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

Fenum is at the beginning.

The current focus is project definition and the ndarray foundation:

- Array descriptor.
- Shape and stride utilities.
- Constructors.
- Elementwise kernels.
- Broadcasting.
- Reductions.
- NumPy differential tests.

The ambition is large, but the first steps are intentionally concrete.
