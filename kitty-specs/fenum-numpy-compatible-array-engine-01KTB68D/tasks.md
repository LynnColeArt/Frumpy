# Work Packages: Fenum NumPy-Compatible Array Engine

**Inputs**: `spec.md`, `plan.md`, `README.md`, `STYLE_GUIDE.md`,
`PROJECT_PLAN.md`, `AGENTS.md`, `SPEC_KITTY_HANDOFF.md`

**Prerequisites**: Substantive spec and plan are committed on the mission
coordination branch.

**Organization**: Work packages map to the phased Fenum roadmap. Each WP must be
independently reviewable, with tests or explicit skip conditions.

**Mission Scope**: NumPy only. Do not implement Torch, autograd, Diffusers,
model loading, tokenizers, GPU runtime design, or a SciPy replacement.

---

## Work Package WP01: Toolchain And Test Harness

**Dependencies**: None
**Requirements Refs**: FR-001
**Owned Files**: fpm.toml, Makefile, src/**, test/**, examples/**, bench/**, python/tests/**, README.md
**Subtasks**: T001, T002, T003, T004, T005
- [x] T001 Create the canonical source/test/example/bench/python directory layout.
- [x] T002 Add `fpm.toml` for the Fortran package path.
- [x] T003 Add `Makefile` fallback commands for build, test, clean, and optional Python differential tests.
- [x] T004 Add a minimal Fortran test runner and one smoke test.
- [x] T005 Add an optional Python NumPy differential smoke test that skips cleanly without NumPy.

---

## Work Package WP02: Status, Constants, And Initial Dtype IDs

**Dependencies**: WP01
**Requirements Refs**: FR-002, FR-011
**Owned Files**: src/fenum_constants.f90, src/fenum_statuses.f90, src/fenum_dtypes.f90, test/test_statuses.f90, test/test_dtypes.f90
**Subtasks**: T006, T007, T008, T009, T010
- [x] T006 Implement project constants including maximum rank and order IDs.
- [x] T007 Implement `fenum_status` and status codes for expected library failures.
- [x] T008 Implement initial dtype IDs and metadata for `r64` plus planned supported dtypes.
- [x] T009 Add tests for status initialization, failure detection, and unsupported behavior.
- [x] T010 Add tests for dtype metadata and unsupported dtype status paths.

---

## Work Package WP03: Shape And Stride Metadata

**Dependencies**: WP02
**Requirements Refs**: FR-003, FR-004
**Owned Files**: src/fenum_shape.f90, src/fenum_strides.f90, test/test_shape.f90, test/test_strides.f90
**Subtasks**: T011, T012, T013, T014, T015, T016
- [x] T011 Implement shape validation for scalar, empty, singleton, and multidimensional arrays.
- [x] T012 Implement overflow-checked element-count computation.
- [x] T013 Implement C-order stride calculation using signed element strides.
- [x] T014 Implement Fortran-order stride calculation using signed element strides.
- [x] T015 Implement C-contiguity and Fortran-contiguity checks.
- [x] T016 Add tests for zero-sized dimensions, scalar arrays, and negative-stride planning assumptions.

---

## Work Package WP04: `ndarray_r64` Descriptor Foundation

**Dependencies**: WP03
**Requirements Refs**: FR-005
**Owned Files**: src/fenum.f90, src/fenum_ndarray_r64.f90, test/test_ndarray_r64.f90
**Subtasks**: T017, T018, T019, T020, T021
- [x] T017 Implement the public umbrella module `fenum`.
- [x] T018 Implement `ndarray_r64` with rank, shape, strides, offset, ownership, contiguity, and backing storage.
- [x] T019 Add descriptor-only constructors for owned storage and descriptor metadata.
- [x] T020 Add scalar inspection helpers for tests without making them permanent public API unless needed.
- [x] T021 Add descriptor invariant tests before adding math kernels.

---

## Work Package WP05: Constructors And Basic Data Movement

**Dependencies**: WP04
**Requirements Refs**: FR-006
**Owned Files**: src/fenum_ndarray_r64.f90, src/fenum_constructors_r64.f90, test/test_constructors_r64.f90, python/tests/test_numpy_constructors.py
**Subtasks**: T022, T023, T024, T025, T026, T027
- [x] T022 Implement `empty_r64`.
- [x] T023 Implement `zeros_r64`, `ones_r64`, and `full_r64`.
- [x] T024 Implement `arange_r64` and `linspace_r64`.
- [x] T025 Implement `copy_r64`, `asarray_r64`, and `ascontiguousarray_r64`.
- [x] T026 Add Fortran constructor/data-movement tests.
- [x] T027 Add NumPy differential constructor fixtures for the supported subset.

---

## Work Package WP06: Broadcasting And Elementwise `r64` Kernels

**Dependencies**: WP05
**Requirements Refs**: FR-007, FR-008
**Owned Files**: src/fenum_broadcast.f90, src/fenum_elementwise_r64.f90, test/test_broadcast.f90, test/test_elementwise_r64.f90, python/tests/test_numpy_broadcast_elementwise.py
**Subtasks**: T028, T029, T030, T031, T032, T033
- [x] T028 Implement `broadcast_plan` and trailing-dimension shape negotiation.
- [x] T029 Represent broadcasted dimensions with zero strides.
- [x] T030 Implement binary add, subtract, multiply, and divide for `r64`.
- [x] T031 Implement unary negate, abs, exp, log, sqrt, sin, and cos for `r64`.
- [x] T032 Add strided fallback tests before optimized contiguous fast paths.
- [x] T033 Add NumPy differential tests for broadcasting and elementwise kernels.

---

## Work Package WP07: Reductions, Axis Semantics, And First Vertical Slice

**Dependencies**: WP06
**Requirements Refs**: FR-009
**Owned Files**: src/fenum_reductions_r64.f90, test/test_reductions_r64.f90, examples/first_vertical_slice.f90, python/tests/test_numpy_reductions.py
**Subtasks**: T034, T035, T036, T037, T038, T039
- [x] T034 Implement 0-based `axis0` validation helpers.
- [x] T035 Implement `sum_r64`, `prod_r64`, `min_r64`, `max_r64`, and `mean_r64`.
- [x] T036 Implement phased `keepdims` support for reductions.
- [x] T037 Document and test empty-reduction behavior.
- [x] T038 Add the first vertical slice example from `PROJECT_PLAN.md`.
- [x] T039 Add NumPy differential reduction tests.

---

## Work Package WP08: Views, Reshape, Transpose, And Slicing

**Dependencies**: WP07
**Requirements Refs**: FR-010
**Owned Files**: src/fenum_views_r64.f90, src/fenum_slices.f90, test/test_views_r64.f90, python/tests/test_numpy_views.py
**Subtasks**: T040, T041, T042, T043, T044, T045
- [ ] T040 Design and implement view ownership/base lifetime behavior.
- [ ] T041 Implement `reshape_r64`, `ravel_r64`, and `flatten_r64`.
- [ ] T042 Implement `transpose_r64`, `swapaxes_r64`, `squeeze_r64`, and `expand_dims_r64`.
- [ ] T043 Implement basic slice descriptors.
- [ ] T044 Implement slice-to-view and negative-stride view support.
- [ ] T045 Add NumPy differential tests for reshape, transpose, and slicing behavior.

---

## Work Package WP09: Dtype System And Promotion Expansion

**Dependencies**: WP08
**Requirements Refs**: FR-011
**Owned Files**: src/fenum_dtypes.f90, src/fenum_casting.f90, src/fenum_ndarray_r32.f90, src/fenum_ndarray_i32.f90, src/fenum_ndarray_i64.f90, src/fenum_ndarray_bool.f90, test/test_dtype_promotion.f90, python/tests/test_numpy_dtype_promotion.py
**Subtasks**: T046, T047, T048, T049, T050, T051
- [ ] T046 Expand dtype metadata for `r32`, `r64`, `i32`, `i64`, and boolean.
- [ ] T047 Implement table-driven promotion rules for supported dtype pairs.
- [ ] T048 Implement cast/copy kernels for supported dtype pairs.
- [ ] T049 Add concrete descriptor rollout for supported dtypes without obscuring the `r64` path.
- [ ] T050 Document the complex dtype plan.
- [ ] T051 Add NumPy differential dtype promotion tests.

---

## Work Package WP10: Indexing, Sorting, Searching, And Selection

**Dependencies**: WP09
**Requirements Refs**: FR-012
**Owned Files**: src/fenum_indexing.f90, src/fenum_selection.f90, src/fenum_sorting.f90, test/test_indexing.f90, test/test_selection.f90, test/test_sorting.f90, python/tests/test_numpy_indexing_selection_sorting.py
**Subtasks**: T052, T053, T054, T055, T056, T057
- [ ] T052 Define integer indexing and boolean mask policies.
- [ ] T053 Implement the initial `where` subset.
- [ ] T054 Implement the initial `take` subset.
- [ ] T055 Implement `concatenate` and `stack`.
- [ ] T056 Implement `sort` and `argsort` subsets.
- [ ] T057 Add tests for copy-vs-view behavior, empty arrays, repeated values, and axis cases.

---

## Work Package WP11: Linear Algebra, Random, And Numerical Utilities

**Dependencies**: WP09
**Requirements Refs**: FR-013
**Owned Files**: src/fenum_linalg_lapack.f90, src/fenum_random.f90, docs/FFT_STRATEGY.md, test/test_linalg.f90, test/test_random.f90, python/tests/test_numpy_linalg_random.py
**Subtasks**: T058, T059, T060, T061, T062, T063
- [ ] T058 Implement `matmul`, `dot`, and `outer` for supported dtypes.
- [ ] T059 Isolate BLAS/LAPACK wrappers behind Fenum modules.
- [ ] T060 Plan and implement a matrix/vector norm subset.
- [ ] T061 Document random generator design.
- [ ] T062 Implement uniform and normal random distributions.
- [ ] T063 Write `docs/FFT_STRATEGY.md` before FFT implementation work.

---

## Work Package WP12: C ABI, Python Surface, And Differential Harness

**Dependencies**: WP07, WP09
**Requirements Refs**: FR-014
**Owned Files**: src/fenum_c_api.f90, include/fenum.h, python/fenum/**, python/tests/**, docs/C_ABI.md
**Subtasks**: T064, T065, T066, T067, T068
- [ ] T064 Document C ABI descriptor and ownership strategy in `docs/C_ABI.md`.
- [ ] T065 Implement the first stable C ABI surface without exposing compiler-specific Fortran layout.
- [ ] T066 Add a Python package skeleton and `fenum.ndarray` wrapper.
- [ ] T067 Expose Python constructors and basic operations for the supported subset.
- [ ] T068 Test ownership, destruction, and NumPy differential behavior from Python.

---

## Work Package WP13: Performance, Coverage Matrix, And Completeness

**Dependencies**: WP10, WP11, WP12
**Requirements Refs**: FR-015
**Owned Files**: bench/**, docs/NUMPY_COVERAGE.md, docs/PERFORMANCE.md, test/**, python/tests/**
**Subtasks**: T069, T070, T071, T072, T073
- [ ] T069 Add benchmarks for contiguous, strided, and broadcasted cases.
- [ ] T070 Add BLAS backend comparison benchmarks.
- [ ] T071 Add allocation profiling notes and regression checks where practical.
- [ ] T072 Document OpenMP and SIMD strategy notes after measured bottlenecks.
- [ ] T073 Maintain `docs/NUMPY_COVERAGE.md` and document unsupported NumPy features.

---

## Dependency & Execution Summary

- **Core sequence**: WP01 -> WP02 -> WP03 -> WP04 -> WP05 -> WP06 -> WP07.
- **View/dtype sequence**: WP07 -> WP08 -> WP09.
- **Broader NumPy sequence**: WP09 -> WP10 and WP09 -> WP11.
- **Interop sequence**: WP07 + WP09 -> WP12.
- **Completeness sequence**: WP10 + WP11 + WP12 -> WP13.
- **Minimal first release slice**: WP01 through WP07.

---

## Requirements Coverage Summary

| Requirement ID | Covered By Work Package(s) |
| --- | --- |
| FR-001 | WP01 |
| FR-002 | WP02 |
| FR-003 | WP03 |
| FR-004 | WP03 |
| FR-005 | WP04 |
| FR-006 | WP05 |
| FR-007 | WP06 |
| FR-008 | WP06 |
| FR-009 | WP07 |
| FR-010 | WP08 |
| FR-011 | WP02, WP09 |
| FR-012 | WP10 |
| FR-013 | WP11 |
| FR-014 | WP12 |
| FR-015 | WP13 |

---

## Subtask Index

| Subtask ID | Summary | Work Package | Priority | Parallel? |
| --- | --- | --- | --- | --- |
| T001-T005 | Toolchain and smoke tests | WP01 | P0 | Partial |
| T006-T010 | Status/constants/dtype IDs | WP02 | P0 | Partial |
| T011-T016 | Shape and stride utilities | WP03 | P0 | Partial |
| T017-T021 | `ndarray_r64` descriptor | WP04 | P0 | No |
| T022-T027 | Constructors and data movement | WP05 | P0 | Partial |
| T028-T033 | Broadcasting and elementwise kernels | WP06 | P0 | Partial |
| T034-T039 | Reductions and first vertical slice | WP07 | P0 | Partial |
| T040-T045 | Views and slicing | WP08 | P1 | Partial |
| T046-T051 | Dtype promotion | WP09 | P1 | Partial |
| T052-T057 | Indexing, selection, sorting | WP10 | P2 | Partial |
| T058-T063 | Linalg, random, numerical utilities | WP11 | P2 | Partial |
| T064-T068 | C ABI and Python package | WP12 | P2 | Partial |
| T069-T073 | Performance and completeness | WP13 | P3 | Partial |
