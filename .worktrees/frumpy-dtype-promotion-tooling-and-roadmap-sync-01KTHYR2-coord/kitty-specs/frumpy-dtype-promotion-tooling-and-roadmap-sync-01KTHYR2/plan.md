# Implementation Plan: Frumpy Dtype Promotion, Tooling, And Roadmap Sync

**Branch**: `main`
**Date**: 2026-06-07
**Spec**: `kitty-specs/frumpy-dtype-promotion-tooling-and-roadmap-sync-01KTHYR2/spec.md`
**Input**: Software-dev mission for Frumpy's next NumPy compatibility phase.

## Summary

This mission moves Frumpy from a validated `r64` vertical slice toward a
multi-dtype NumPy-compatible foundation. It first makes the repo boring to
build and test, then reconciles active project artifacts with the Frumpy rename,
then expands dtype metadata, promotion, casting, and concrete descriptor support.

The plan intentionally avoids a speculative generic dtype machine. The existing
`ndarray_r64` path remains the readable reference implementation. New dtype
support should be introduced through small concrete modules and centralized
promotion/casting tables, with NumPy differential tests documenting the supported
subset.

## Technical Context

**Language/Version**: Fortran 2018 with `gfortran` 13.x used for current local
validation; Python 3.12 is allowed only for repo-local NumPy differential tests.
**Primary Dependencies**: `gfortran`, `make`, optional `fpm`, repo-local Python
`.venv/`, Python `pytest`, Python `numpy`; no runtime Python dependency for the
Fortran core.
**Storage**: In-memory ndarray descriptors and backing buffers; mission
artifacts under `kitty-specs/`; no database or external persistent storage.
**Testing**: Standalone Fortran test programs compiled with strict warnings and
runtime checks; Python NumPy differential fixtures run from `.venv/`; `git diff
--check` before handoff.
**Target Platform**: Linux and macOS developer environments. Current live
validation is on Linux with `gfortran`; fpm support should be portable where the
layout permits.
**Project Type**: Single Fortran library with examples, tests, Python
differential fixtures, and future C ABI/Python package surfaces explicitly
deferred.
**Performance Goals**: Correct dtype semantics first; no speed claims without
benchmarks; avoid hidden allocations and duplicated cast/promotion logic.
**Constraints**: NumPy-only scope, explicit kinds, private-by-default modules,
status-based recoverable errors, no global Python package assumptions, no Torch
or Diffusers scope.
**Scale/Scope**: One reviewable mega mission split into small WPs: tooling,
artifact sync, dtype metadata, promotion, casting, concrete descriptors, tests,
and documentation.

## Charter Check

The current generated runtime charter is still titled "Fenum Runtime Charter",
but its active rules still apply to Frumpy after the rename:

- NumPy compatibility is the contract.
- Fortran 2018 is the core implementation language.
- Python is limited to differential tests and later staged bindings.
- Correctness, explicit memory behavior, status paths, and reviewability come
  before performance claims.
- Torch, autograd, Diffusers, model loading, tokenizers, GPU runtime design, and
  SciPy replacement work remain out of scope.

This mission may update project-facing charter references from Fenum to Frumpy,
but it must preserve historical mission identifiers and avoid breaking existing
Spec Kitty state.

## Project Structure

### Mission Artifacts

```text
kitty-specs/frumpy-dtype-promotion-tooling-and-roadmap-sync-01KTHYR2/
├── meta.json
├── spec.md
├── plan.md
├── tasks.md
└── tasks/
```

### Current Source Layout

```text
src/
├── frumpy.f90
├── frumpy_broadcast.f90
├── frumpy_constants.f90
├── frumpy_constructors_r64.f90
├── frumpy_dtypes.f90
├── frumpy_elementwise_r64.f90
├── frumpy_ndarray_r64.f90
├── frumpy_reductions_r64.f90
├── frumpy_shape.f90
├── frumpy_slices.f90
├── frumpy_statuses.f90
├── frumpy_strides.f90
└── frumpy_views_r64.f90

test/
├── test_broadcast.f90
├── test_constructors_r64.f90
├── test_dtypes.f90
├── test_elementwise_r64.f90
├── test_ndarray_r64.f90
├── test_reductions_r64.f90
├── test_shape.f90
├── test_statuses.f90
├── test_strides.f90
└── test_views_r64.f90

python/tests/
├── test_numpy_broadcast_elementwise.py
├── test_numpy_constructors.py
├── test_numpy_reductions.py
└── test_numpy_views.py

examples/
└── first_vertical_slice.f90
```

### Expected Additions

```text
Makefile
fpm.toml
bench/
docs/
├── BUILDING.md
├── DTYPE_METADATA.md
├── DTYPE_PROMOTION.md
├── CASTING_POLICY.md
├── DTYPE_SUPPORT.md
├── DTYPE_VALIDATION.md
└── COMPLEX_DTYPE_PLAN.md

src/
├── frumpy_casting.f90
├── frumpy_promotion.f90
├── frumpy_ndarray_r32.f90
├── frumpy_ndarray_i32.f90
├── frumpy_ndarray_i64.f90
└── frumpy_ndarray_bool.f90

test/
├── test_dtype_promotion.f90
├── test_casting.f90
├── test_ndarray_r32.f90
├── test_ndarray_i32.f90
├── test_ndarray_i64.f90
└── test_ndarray_bool.f90

python/tests/
├── test_numpy_dtype_promotion.py
└── test_numpy_casting.py
```

**Structure Decision**: Keep Frumpy as a single-library Fortran project. Add
small concrete dtype modules rather than a broad generic descriptor hierarchy.
Use `frumpy_promotion` and `frumpy_casting` as centralized policy modules so
kernel modules do not grow their own promotion rules.

## Architecture Decisions

### AD-001: Tooling Before More Feature Work

Add `Makefile`, `fpm.toml`, and benchmark scaffolding before expanding dtype
behavior.

Rationale:

- Current validation works but relies on long direct `gfortran` invocations.
- Future agents need stable commands before the dtype surface gets wider.

### AD-002: Makefile Is The Canonical Local Gate

Use `make validate` as the mission's canonical local validation target. `fpm`
support should be added where practical, but `make` remains the fallback and
review gate.

Rationale:

- The current test programs are standalone and explicit.
- `make` can orchestrate Fortran tests, Python tests, clean, and diff checks
  without forcing a package-layout migration.

### AD-003: Frumpy Naming Is Current-Surface Truth

Current docs, active mission artifacts, and build commands should use `frumpy_*`
module paths. Historical mission slugs and archived paths may remain unchanged
where they identify previous work.

Rationale:

- Blind renaming historical identifiers risks breaking Spec Kitty state.
- Current-facing instructions must not send contributors to stale `fenum_*`
  paths.

### AD-004: Dtype Metadata Is Centralized

`frumpy_dtypes` owns dtype IDs, names, byte sizes, kind mapping, support state,
and unsupported/planned status behavior.

Rationale:

- Dtype metadata is the foundation for promotion, casting, constructors, and
  future Python/C ABI surfaces.
- A single table prevents drift across modules.

### AD-005: Promotion Is Table-Driven

`frumpy_promotion` owns promotion rules for the supported dtype pairs. Kernel
modules must ask for promotion results instead of encoding their own pairwise
rules.

Rationale:

- NumPy promotion behavior is subtle.
- Duplicated promotion logic creates silent divergence.

### AD-006: Casting Is Separate From Promotion

`frumpy_casting` owns cast/copy kernels and safety policy. Promotion decides a
result dtype; casting performs data conversion.

Rationale:

- Promotion and casting are related but not the same operation.
- Keeping them separate makes tests and error paths easier to review.

### AD-007: Concrete Dtype Modules First

Add concrete descriptor/storage modules for selected dtypes before attempting a
fully generic ndarray representation.

Rationale:

- The existing `ndarray_r64` module is readable and tested.
- Concrete modules expose repeated structure without hiding behavior in clever
  abstractions too early.

## Implementation Concern Map

### IC-01 — Build And Validation Surface

- **Purpose**: Make local validation reproducible with short commands.
- **Relevant requirements**: FR-001, FR-002, FR-012
- **Affected surfaces**: `Makefile`, `fpm.toml`, `.gitignore`, `bench/`,
  `README.md`, `AGENTS.md`
- **Sequencing/depends-on**: none
- **Risks**: fpm may not naturally discover standalone test programs; document
  limitations rather than forcing a disruptive layout change.

### IC-02 — Frumpy Artifact Reconciliation

- **Purpose**: Align current-facing docs and active planning artifacts with the
  Frumpy rename while preserving historical identifiers.
- **Relevant requirements**: FR-003
- **Affected surfaces**: `.kittify/charter/charter.md`, `PROJECT_PLAN.md`,
  `STYLE_GUIDE.md`, `AGENTS.md`, current mission artifacts, old mission docs as
  manual-review surfaces only
- **Sequencing/depends-on**: none
- **Risks**: historical Spec Kitty slugs still contain `fenum`; those must not
  be blindly renamed.

### IC-03 — Dtype Metadata Table

- **Purpose**: Turn the current planned dtype IDs into a coherent support table.
- **Relevant requirements**: FR-004, FR-009, FR-011
- **Affected surfaces**: `src/frumpy_dtypes.f90`, `test/test_dtypes.f90`,
  `docs/DTYPE_SUPPORT.md`
- **Sequencing/depends-on**: IC-01 preferred for validation commands
- **Risks**: changing `is_supported_dtype` semantics too broadly could imply
  operational support before descriptors/casts exist.

### IC-04 — Promotion Policy

- **Purpose**: Define and test supported dtype promotion decisions against
  NumPy.
- **Relevant requirements**: FR-005, FR-006, FR-009, FR-010
- **Affected surfaces**: `src/frumpy_promotion.f90`,
  `test/test_dtype_promotion.f90`,
  `python/tests/test_numpy_dtype_promotion.py`, `docs/DTYPE_SUPPORT.md`
- **Sequencing/depends-on**: IC-03
- **Risks**: NumPy 2.x promotion rules can surprise us; tests must record the
  observed NumPy version.

### IC-05 — Casting Kernels

- **Purpose**: Implement explicit cast/copy behavior for the selected dtype
  subset.
- **Relevant requirements**: FR-007, FR-009, FR-010
- **Affected surfaces**: `src/frumpy_casting.f90`, `test/test_casting.f90`,
  Python dtype fixtures
- **Sequencing/depends-on**: IC-03, IC-04
- **Risks**: overflow and lossy casts need explicit policy; avoid silently
  pretending all casts are safe.

### IC-06 — Concrete Non-r64 Descriptors

- **Purpose**: Add selected concrete ndarray descriptors without disturbing the
  existing `ndarray_r64` behavior.
- **Relevant requirements**: FR-008, FR-009, FR-012
- **Affected surfaces**: `src/frumpy_ndarray_r32.f90`,
  `src/frumpy_ndarray_i32.f90`, `src/frumpy_ndarray_i64.f90`,
  `src/frumpy_ndarray_bool.f90`, descriptor tests
- **Sequencing/depends-on**: IC-03; may run partly in parallel with IC-04
- **Risks**: duplicated descriptor code is acceptable short-term, but exact
  invariants must stay aligned with `ndarray_r64`.

### IC-07 — Documentation And Unsupported Dtypes

- **Purpose**: Make supported, planned, and unsupported dtype behavior visible.
- **Relevant requirements**: FR-011
- **Affected surfaces**: `docs/DTYPE_SUPPORT.md`,
  `docs/COMPLEX_DTYPE_PLAN.md`, `README.md`, `STYLE_GUIDE.md`
- **Sequencing/depends-on**: IC-03, IC-04, IC-05
- **Risks**: docs must not claim full NumPy dtype support before the code has
  it.

## Work Package Strategy

The mission should be split into small WPs in this order:

1. Tooling and validation surface.
2. Frumpy artifact reconciliation.
3. Dtype metadata table and docs.
4. Promotion policy and NumPy differential fixtures.
5. Casting kernels.
6. First concrete non-r64 descriptors.
7. Final dtype support documentation and regression validation.

Each WP must be independently reviewable and must run `make validate` once the
Makefile exists. Before that WP lands, direct `gfortran` validation remains
acceptable.

## Testing Strategy

- Keep the current strict Fortran compilation flags: `-std=f2018 -Wall -Wextra
  -Werror -fcheck=all`.
- Compile all existing r64 tests for every WP unless a WP only touches docs and
  mission artifacts.
- Add focused Fortran tests for dtype table, promotion, casting, and descriptor
  invariants.
- Add Python NumPy fixtures for promotion/casting expectations.
- Pin the observed NumPy version in test output or fixture metadata so future
  changes in NumPy behavior are visible.
- Keep `.venv/`, `.pytest_cache/`, `__pycache__/`, `build/`, `*.o`, and `*.mod`
  ignored.

## Risk Plan

| Risk | Mitigation |
| --- | --- |
| Spec Kitty state still contains historical Fenum paths. | Classify current-facing vs historical identifiers; only rename current-facing surfaces. |
| Dtype support claims outrun implementation. | Track support state separately from planned dtype metadata. |
| Promotion logic becomes scattered. | Require all promotion decisions to pass through `frumpy_promotion`. |
| fpm support fights the current standalone tests. | Keep `make validate` canonical and document fpm limits if needed. |
| Non-r64 descriptors duplicate too much code. | Accept small duplication initially; document shared invariants before abstracting. |
| NumPy promotion behavior changes across versions. | Record observed NumPy version in differential tests and docs. |

## Phase Exit Criteria

The mission is ready for acceptance when:

- `make validate` passes from a clean checkout with local dependencies
  installed.
- Existing r64 behavior remains green.
- Dtype metadata, promotion, casting, and selected non-r64 descriptors have
  focused Fortran tests.
- Python differential tests cover the supported promotion/casting subset.
- Current-facing docs use Frumpy naming and accurately describe dtype support.
- Historical Fenum mission identifiers are preserved where required.
- `git diff --check` is clean.
