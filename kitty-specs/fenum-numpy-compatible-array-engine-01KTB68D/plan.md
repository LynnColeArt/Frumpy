# Implementation Plan: Fenum NumPy-Compatible Array Engine

**Branch**: `main`  
**Date**: 2026-06-05  
**Spec**: `kitty-specs/fenum-numpy-compatible-array-engine-01KTB68D/spec.md`  
**Input**: Long-horizon software-dev mission for Fenum.


## Summary

Build Fenum as a Fortran 2018 NumPy-compatible ndarray engine. The work should
be decomposed into phased, dependency-aware work packages while preserving the
full long-range mission shape.

The implementation strategy is descriptor-first:

1. Establish build and test infrastructure.
2. Implement status, constants, dtype IDs, shape, and stride metadata.
3. Implement a concrete `ndarray_r64` descriptor and descriptor tests.
4. Add constructors and data movement.
5. Add broadcasting, elementwise kernels, reductions, and view operations.
6. Expand dtype, indexing, linalg, random, interop, and performance coverage.

NumPy is the behavior oracle for public semantics. Fortran is the implementation
language and should remain direct, explicit, and readable.


## Technical Context

**Language/Version**: Fortran 2018, with Python 3 used only for optional NumPy
differential tests and future package tooling.  
**Primary Dependencies**: `gfortran`; optional `fpm`; optional Python `numpy`
for differential tests; BLAS/LAPACK later behind dedicated Fenum modules.  
**Storage**: In-memory ndarray descriptors and contiguous backing buffers;
mission artifacts in `kitty-specs/`; no database or external persistent
storage.  
**Testing**: Fortran invariant tests, optional NumPy differential tests, future
benchmarks for contiguous/strided/broadcasted kernels.  
**Target Platform**: Local Linux development first; portable Fortran package
layout for other platforms later.  
**Project Type**: Single Fortran library with eventual C ABI and Python package
surface.  
**Performance Goals**: Correct strided fallbacks before fast paths; benchmarked
contiguous and BLAS-backed optimizations after semantics are stable.  
**Constraints**: NumPy-only scope; Fortran 2018; explicit kinds; no hidden
copies; status-based library errors; public axes are 0-based.  
**Scale/Scope**: Long-horizon NumPy-compatible array engine, decomposed into
small reviewable WPs.


## Charter Check

No formal project charter has been generated yet. For this mission, governance
comes from:

- `README.md`
- `STYLE_GUIDE.md`
- `PROJECT_PLAN.md`
- `AGENTS.md`
- `SPEC_KITTY_HANDOFF.md`

The mission must be rejected or revised if planning introduces Torch, autograd,
Diffusers, model loading, tokenizers, GPU runtime design, or a SciPy replacement
as current scope.


## Project Structure

### Documentation And Mission Artifacts

```text
README.md
STYLE_GUIDE.md
PROJECT_PLAN.md
AGENTS.md
SPEC_KITTY_HANDOFF.md
kitty-specs/fenum-numpy-compatible-array-engine-01KTB68D/
├── meta.json
├── spec.md
├── plan.md
├── tasks.md
└── tasks/
```

### Source Layout

```text
src/
├── fenum.f90
├── fenum_constants.f90
├── fenum_statuses.f90
├── fenum_dtypes.f90
├── fenum_shape.f90
├── fenum_strides.f90
├── fenum_ndarray_r64.f90
├── fenum_broadcast.f90
├── fenum_elementwise_r64.f90
├── fenum_reductions_r64.f90
├── fenum_views_r64.f90
└── fenum_linalg_lapack.f90

test/
├── test_runner.f90
├── test_statuses.f90
├── test_shape.f90
├── test_strides.f90
├── test_ndarray_r64.f90
├── test_broadcast.f90
├── test_elementwise_r64.f90
├── test_reductions_r64.f90
└── test_views_r64.f90

python/
├── tests/
│   └── test_numpy_differential.py
└── fenum/

examples/
bench/
```

**Structure Decision**: Use a single-library Fortran layout with dtype-specific
modules. Keep Python under `python/` as compatibility/differential tooling until
the Fortran core is stable enough for a package surface.


## Architecture Decisions

### AD-001: Descriptor-First Implementation

Build metadata and descriptor correctness before math kernels.

Rationale:

- Broadcasting, reductions, views, and dtype expansion all rely on correct
  shape/stride/offset behavior.
- A wrong descriptor will infect every later phase.

### AD-002: Initial Concrete Dtype Is `r64`

Start with `ndarray_r64` before building a generic dtype system.

Rationale:

- Concrete code will reveal the real ndarray shape.
- Premature dtype machinery risks cleverness and unreadability.

### AD-003: NumPy-Facing Axes Are 0-Based

Public APIs use 0-based `axis0` semantics. Internal Fortran helpers may convert
to 1-based `dim1` values, but names must make the basis explicit.

Rationale:

- Fenum's compatibility target is NumPy, not Fortran's native indexing model.
- Naming prevents accidental axis/dimension drift.

### AD-004: Strides Are Signed Element Strides

Store strides as signed `integer(int64)` values measured in elements.

Rationale:

- Negative strides are required for NumPy-style reversed views.
- Byte strides should be derived or separately named when needed.

### AD-005: Status-Based Library Errors

Core library routines use a status path for invalid input, allocation failure,
overflow, unsupported dtype, and unsupported behavior.

Rationale:

- Library callers should be able to recover.
- Tests and examples can still use `error stop`.

### AD-006: Correct Strided Kernels Before Fast Paths

Every optimized contiguous path must have a tested correct strided fallback.

Rationale:

- NumPy compatibility depends on non-contiguous arrays and views.
- Performance work must not replace semantic correctness.


## Phase Plan

### Phase 1: Toolchain And Test Harness

Deliver:

- `fpm.toml`
- `Makefile`
- `src/`, `test/`, `examples/`, `bench/`, `python/`
- Minimal Fortran test runner
- Optional Python NumPy differential smoke test

Review focus:

- Build commands are boring.
- Test commands fail clearly.
- Optional Python tests skip cleanly without NumPy.

### Phase 2: Core Descriptor And Metadata

Deliver:

- `fenum_statuses`
- `fenum_constants`
- `fenum_dtypes`
- `fenum_shape`
- `fenum_strides`
- `ndarray_r64` descriptor
- C/F contiguity tests
- Overflow tests

Review focus:

- Shape values are non-negative `integer(int64)`.
- Strides are signed element strides.
- Offset semantics are explicit.
- Scalar and empty arrays are covered.

### Phase 3: Constructors And Basic Data Movement

Deliver:

- `empty_r64`
- `zeros_r64`
- `ones_r64`
- `full_r64`
- `arange_r64`
- `linspace_r64`
- `copy_r64`
- `asarray_r64`
- `ascontiguousarray_r64`

Review focus:

- Copies are explicit.
- Constructors compare against NumPy.
- Allocation failure paths report status.

### Phase 4: Broadcasting And Elementwise Kernels

Deliver:

- `broadcast_plan`
- Binary `r64` add/subtract/multiply/divide
- Initial unary `r64` kernels
- Strided fallback paths
- Contiguous fast paths only after fallback tests

Review focus:

- Broadcast dimensions use zero strides.
- Incompatible shapes fail clearly.
- Scalar-array operations avoid fake allocations.

### Phase 5: Reductions And Axis Semantics

Deliver:

- `sum_r64`
- `prod_r64`
- `min_r64`
- `max_r64`
- `mean_r64`
- `keepdims`
- Invalid-axis helpers

Review focus:

- Public axis values are 0-based.
- Empty reductions match or intentionally document NumPy behavior.
- Scalar, singleton, empty, and multidimensional arrays are covered.

### Phase 6: Views, Reshape, Transpose, And Slicing

Deliver:

- `reshape_r64`
- `ravel_r64`
- `flatten_r64`
- `transpose_r64`
- `swapaxes_r64`
- `squeeze_r64`
- `expand_dims_r64`
- slice descriptors
- negative-stride views

Review focus:

- View operations do not copy unless promised.
- Backing lifetime and ownership are explicit.
- Non-contiguous arrays still work with existing kernels.

### Phase 7: Dtype System And Promotion

Deliver:

- Dtype metadata table
- `r32`, `r64`, `i32`, `i64`, boolean rollout
- Promotion rules for supported pairs
- Cast/copy kernels
- Complex dtype plan

Review focus:

- Promotion behavior is tested against NumPy.
- Unsupported dtypes fail clearly.
- Generic machinery remains readable.

### Phase 8: Indexing, Sorting, Searching, And Selection

Deliver:

- Integer indexing policy
- Boolean mask strategy
- `where` subset
- `take` subset
- `concatenate`
- `stack`
- `sort` subset
- `argsort` subset

Review focus:

- Copy-vs-view behavior is explicit.
- Advanced indexing does not explode scope.
- Empty and repeated-value cases are tested.

### Phase 9: Linear Algebra, Random, And Numerical Utilities

Deliver:

- `matmul`
- `dot`
- `outer`
- norm subset
- BLAS/LAPACK backend module
- random generator design
- uniform and normal distributions
- FFT strategy document

Review focus:

- Backend wrappers are isolated.
- Numerical tolerance expectations are explicit.
- Reproducibility is documented.

### Phase 10: C ABI, Python Package, And Differential Testing

Deliver:

- C ABI design and implementation
- Python package skeleton
- Python `fenum.ndarray` wrapper
- Python constructors and basic operations
- NumPy differential tests

Review focus:

- ABI does not expose compiler-specific Fortran internals.
- Ownership and destruction are tested.
- Python tooling does not swallow the Fortran core.

### Phase 11: Performance And Completeness

Deliver:

- Benchmark suite
- Contiguous vs strided benchmarks
- Broadcast benchmarks
- BLAS comparison
- allocation profiling
- OpenMP/SIMD notes
- NumPy coverage matrix
- unsupported feature documentation

Review focus:

- Performance claims are measured.
- Fast paths preserve semantics.
- Unsupported behavior is discoverable.


## Testing Strategy

Fortran tests:

- Status propagation
- Shape validation
- Stride calculation
- Element-count overflow
- Descriptor invariants
- Broadcasting plans
- Elementwise strided and contiguous paths
- Reductions over supported axes
- View/copy behavior

Python differential tests:

- Constructor parity with NumPy
- Broadcast parity with NumPy
- Elementwise parity with NumPy
- Reduction parity with NumPy
- Reshape/transpose/slicing parity where implemented
- Error behavior where supported

Test rule:

- If public behavior is NumPy-compatible, compare against NumPy.
- If behavior intentionally differs, document the difference and test it.


## Risk Register

| Risk | Mitigation |
| --- | --- |
| Descriptor semantics are wrong early | Implement descriptor and invariant tests before kernels. |
| Fortran memory order leaks into public behavior | Keep C-order/F-order explicit in shape and stride utilities. |
| Dtype promotion becomes a swamp | Delay dtype expansion until `r64` proves the core shape; table-drive promotions. |
| View lifetime is unsafe | Design ownership/base lifetime before implementing slicing. |
| Python interop distracts too early | Keep Python as differential tooling until core phases are stable. |
| Performance work breaks semantics | Require tested strided fallbacks before fast paths. |
| Spec scope drifts into ML | Reject Torch, Diffusers, autograd, model-loading, tokenizers, and GPU runtime work. |


## Work Package Guidance

Tasks should be generated as dependency-aware WPs that map to phases. A WP can
cover multiple small files, but it must have a clear review boundary and tests.

Preferred early WP shape:

1. Toolchain and smoke-test harness.
2. Status/constants/dtype IDs.
3. Shape utilities and tests.
4. Stride utilities and tests.
5. `ndarray_r64` descriptor and tests.
6. Constructors and data movement.
7. Broadcast planning.
8. First elementwise operations.
9. First reductions.
10. First vertical slice.

Later WPs should continue the phase order from `PROJECT_PLAN.md`.


## Gates Before Implementation

- `spec.md` must remain NumPy-only and substantive.
- `plan.md` must preserve descriptor-first architecture.
- `tasks.md` must contain concrete, reviewable WPs.
- WPs must include validation commands or clear skip conditions.
- WPs must not hide open product decisions as implementation details.


## Open Planning Questions

- What exact Fortran ownership representation should back views?
- Should initial storage use allocatable arrays only, pointer handles, or a
  split owned/buffer handle?
- How should fpm and Makefile source lists avoid drift?
- What is the smallest useful Python differential test before Python bindings?
- Which dtype promotion subset comes first after `r64`?
