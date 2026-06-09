# Work Packages: Frumpy Dtype Promotion, Tooling, And Roadmap Sync

**Inputs**: `spec.md`, `plan.md`, `README.md`, `STYLE_GUIDE.md`,
`PROJECT_PLAN.md`, `AGENTS.md`, current `src/frumpy_*.f90`, current Fortran
tests, current Python NumPy differential fixtures.

**Prerequisites**: The mission specification and implementation plan are
committed on the coordination branch.

**Mission Scope**: NumPy-only dtype/tooling advancement. Do not implement Torch,
autograd, Diffusers, model loading, tokenizers, GPU runtime design, Python
package bindings, C ABI, linalg, random, indexing, sorting, searching, or SciPy
replacement work in this mission.

---

## Work Package WP01: Tooling And Validation Surface

**Dependencies**: None
**Requirements Refs**: FR-001, FR-002, FR-012
**Owned Files**: Makefile, fpm.toml, bench/**, docs/BUILDING.md, .gitignore
**Subtasks**: T001, T002, T003, T004, T005
- [x] T001 Add a `Makefile` with `build`, `test`, `python-test`, `validate`, and `clean` targets.
- [x] T002 Encode the current strict `gfortran` source order and test programs in the Makefile.
- [x] T003 Add `fpm.toml` metadata or a documented limitation if fpm cannot cleanly run the current standalone tests.
- [x] T004 Add or reserve `bench/` with a minimal benchmark/readme surface.
- [x] T005 Add `docs/BUILDING.md` with the canonical local validation commands.

---

## Work Package WP02: Frumpy Artifact Reconciliation

**Dependencies**: WP01
**Requirements Refs**: FR-003
**Owned Files**: .kittify/charter/charter.md, PROJECT_PLAN.md, STYLE_GUIDE.md, AGENTS.md, README.md, SPEC_KITTY_HANDOFF.md
**Subtasks**: T006, T007, T008, T009
- [x] T006 Classify current-facing Frumpy names versus historical pre-rename identifiers before editing.
- [x] T007 Update current-facing docs and active planning artifacts to use `frumpy_*` module paths.
- [x] T008 Preserve historical mission slugs and archived identifiers that Spec Kitty state depends on.
- [x] T009 Add a stale-name check that ignores intentionally historical mission paths.

---

## Work Package WP03: Dtype Metadata Table And Support Docs

**Dependencies**: WP01
**Requirements Refs**: FR-004, FR-009, FR-011
**Owned Files**: src/frumpy_dtypes.f90, test/test_dtypes.f90, docs/DTYPE_METADATA.md
**Subtasks**: T010, T011, T012, T013, T014
- [x] T010 Expand `frumpy_dtypes` into a table-backed dtype metadata source.
- [x] T011 Track dtype IDs, names, byte sizes, support state, and planned/unsupported status messages.
- [x] T012 Keep `r64` supported while making non-r64 support claims explicit.
- [x] T013 Extend Fortran dtype tests for table lookup and unsupported statuses.
- [x] T014 Start `docs/DTYPE_METADATA.md` with dtype IDs, support states, and unsupported dtype categories.

---

## Work Package WP04: Promotion Policy And NumPy Fixtures

**Dependencies**: WP03
**Requirements Refs**: FR-005, FR-006, FR-009, FR-010
**Owned Files**: src/frumpy_promotion.f90, test/test_dtype_promotion.f90, python/tests/test_numpy_dtype_promotion.py, docs/DTYPE_PROMOTION.md
**Subtasks**: T015, T016, T017, T018, T019
- [x] T015 Add `frumpy_promotion` with a table-driven promotion API for the selected dtype subset.
- [x] T016 Define unsupported promotion status behavior for pairs outside the selected subset.
- [x] T017 Add Fortran promotion tests for supported, unsupported, scalar-like, and identity pairs.
- [x] T018 Add Python NumPy fixtures for expected promotion behavior and record the observed NumPy version.
- [x] T019 Document the supported promotion subset and any intentional NumPy differences in `docs/DTYPE_PROMOTION.md`.

---

## Work Package WP05: Casting Kernels And Safety Policy

**Dependencies**: WP04
**Requirements Refs**: FR-007, FR-009, FR-010
**Owned Files**: src/frumpy_casting.f90, test/test_casting.f90, python/tests/test_numpy_casting.py, docs/CASTING_POLICY.md
**Subtasks**: T020, T021, T022, T023, T024
- [x] T020 Add `frumpy_casting` with explicit cast/copy kernels for the selected dtype pairs.
- [x] T021 Separate promotion decisions from cast execution.
- [x] T022 Define status behavior for lossy, overflowing, or unsupported casts.
- [x] T023 Add Fortran cast tests for supported and rejected casts.
- [x] T024 Add Python fixtures for NumPy cast expectations.

---

## Work Package WP06: Concrete Non-r64 Descriptor Foundation

**Dependencies**: WP03
**Requirements Refs**: FR-008, FR-009, FR-012
**Owned Files**: src/frumpy_ndarray_r32.f90, src/frumpy_ndarray_i32.f90, src/frumpy_ndarray_i64.f90, src/frumpy_ndarray_bool.f90, test/test_ndarray_r32.f90, test/test_ndarray_i32.f90, test/test_ndarray_i64.f90, test/test_ndarray_bool.f90, src/frumpy.f90
**Subtasks**: T025, T026, T027, T028, T029
- [ ] T025 Choose the smallest concrete non-r64 descriptor subset for this mission.
- [ ] T026 Implement descriptor/storage modules for the selected non-r64 dtypes.
- [ ] T027 Preserve the `ndarray_r64` invariants for shape, strides, offset, ownership, and contiguity.
- [ ] T028 Add descriptor tests for selected non-r64 dtypes.
- [ ] T029 Expose only reviewed descriptor surfaces through the umbrella `frumpy` module.

---

## Work Package WP07: Final Dtype Documentation And Regression Validation

**Dependencies**: WP02, WP04, WP05, WP06
**Requirements Refs**: FR-003, FR-011, FR-012
**Owned Files**: docs/DTYPE_SUPPORT.md, docs/COMPLEX_DTYPE_PLAN.md, docs/DTYPE_VALIDATION.md
**Subtasks**: T030, T031, T032, T033, T034, T035
- [ ] T030 Write `docs/COMPLEX_DTYPE_PLAN.md`.
- [ ] T031 Document object dtype as intentionally unsupported.
- [ ] T032 Finalize `docs/DTYPE_SUPPORT.md` with implemented, planned, and unsupported dtype behavior.
- [ ] T033 Run `make validate`, Python differential tests, stale-name checks, and `git diff --check`.
- [ ] T034 Confirm existing r64 constructors, broadcasting, elementwise, reductions, and views still pass.
- [ ] T035 Prepare mission acceptance notes with exact validation commands and observed NumPy version.

---

## Dependency & Execution Summary

- **Tooling base**: WP01.
- **Artifact sync**: WP01 -> WP02.
- **Dtype semantic base**: WP01 -> WP03 -> WP04 -> WP05.
- **Descriptor expansion**: WP03 -> WP06.
- **Closeout**: WP02 + WP04 + WP05 + WP06 -> WP07.

---

## Requirements Coverage Summary

| Requirement ID | Covered By Work Package(s) |
| --- | --- |
| FR-001 | WP01 |
| FR-002 | WP01 |
| FR-003 | WP02, WP07 |
| FR-004 | WP03 |
| FR-005 | WP04 |
| FR-006 | WP04 |
| FR-007 | WP05 |
| FR-008 | WP06 |
| FR-009 | WP03, WP04, WP05, WP06 |
| FR-010 | WP04, WP05 |
| FR-011 | WP03, WP07 |
| FR-012 | WP01, WP06, WP07 |
