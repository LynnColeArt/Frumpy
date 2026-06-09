# Mission Specification: Frumpy Dtype Promotion, Tooling, And Roadmap Sync

## Mission Intent

Frumpy has moved past the first r64 vertical slice: `main` now contains the
renamed Frumpy modules, constructor/data-movement helpers, broadcasting and
elementwise kernels, reductions, and view/slicing behavior. The next mission
turns that working slice into a sturdier foundation for the next NumPy
compatibility phase.

This mission has three connected goals:

1. Reconcile project and mission artifacts with the Frumpy name and the live
   `main` branch state.
2. Backfill boring build/test tooling so contributors can run the same checks
   without reconstructing long `gfortran` command lines.
3. Expand the dtype system beyond the current r64-only execution path without
   creating a vague generic abstraction layer.

The mission should keep the project NumPy-only. It should improve Frumpy's
ability to represent, promote, cast, and eventually operate on supported numeric
dtypes, while preserving the current readable Fortran 2018 style.

## Current State

`main` currently includes:

- `src/frumpy_*.f90` modules for constants, statuses, dtype IDs, shape, strides,
  the `ndarray_r64` descriptor, constructors, broadcasting, elementwise kernels,
  reductions, slices, and views.
- Fortran tests for statuses, dtype metadata, shape, strides, descriptors,
  constructors, broadcasting, elementwise kernels, reductions, and views.
- Python NumPy differential fixtures for constructors, broadcasting/elementwise
  behavior, reductions, and views.
- An example vertical slice in `examples/first_vertical_slice.f90`.

`main` does not yet include:

- `Makefile` or `fpm.toml` build metadata.
- A stable `make test` or `fpm test` path.
- A benchmark directory or benchmark command surface.
- Concrete array descriptors for `r32`, `i32`, `i64`, or boolean arrays.
- Table-driven dtype promotion and casting behavior.
- Updated mission task metadata that consistently uses Frumpy module paths
  instead of pre-rename paths.

## Scope

### In Scope

- Update project-facing planning artifacts to treat Frumpy as the current
  project name.
- Preserve pre-rename mission slugs where they are identifiers, but avoid
  presenting stale module paths as the current implementation surface.
- Add `Makefile` commands for clean, build, Fortran tests, Python tests, and
  full validation.
- Add `fpm.toml` metadata if it can represent the project cleanly without
  fighting the current source/test layout.
- Add or reserve `bench/` with a minimal benchmark entry point or documented
  placeholder.
- Expand `frumpy_dtypes` into the authoritative table for supported and planned
  dtypes.
- Define supported dtype IDs, names, byte sizes, kind mapping, and support
  status for at least `bool`, `i32`, `i64`, `r32`, and `r64`.
- Implement table-driven promotion for the supported dtype pairs chosen by this
  mission.
- Implement cast/copy kernels for the supported dtype pairs chosen by this
  mission.
- Add concrete descriptor/storage modules for the selected non-r64 dtypes
  without obscuring the existing `ndarray_r64` path.
- Add Fortran tests and NumPy differential fixtures that document the supported
  promotion and casting subset.
- Document unsupported dtype behavior, including object dtype and the complex
  dtype plan.

### Out Of Scope

- Python package or C ABI implementation.
- Torch compatibility, autograd, Diffusers support, GPU runtime design, model
  loading, tokenizers, or SciPy replacement work.
- Full NumPy dtype coverage.
- Object dtype support.
- Complex dtype implementation, except for a written plan.
- Linear algebra, random number generation, FFT implementation, indexing,
  sorting, searching, and selection.
- Performance optimization beyond keeping tests and benchmark hooks useful.

## Functional Requirements

| ID | Requirement | Priority |
| --- | --- | --- |
| FR-001 | Provide a boring local build/test surface with `make` targets for build, Fortran tests, Python differential tests, clean, and full validation. | Must |
| FR-002 | Provide `fpm.toml` package metadata or document precisely why fpm cannot yet represent the current layout. | Must |
| FR-003 | Ensure project-facing docs and active mission artifacts use Frumpy names for current modules and paths while preserving historical identifiers where required. | Must |
| FR-004 | Make `frumpy_dtypes` the single authoritative source for dtype IDs, names, byte sizes, support state, and planned/unsupported status behavior. | Must |
| FR-005 | Define a table-driven dtype promotion API for the supported dtype subset. | Must |
| FR-006 | Match NumPy promotion behavior for the supported dtype pairs, or document and test any intentional difference. | Must |
| FR-007 | Implement cast/copy kernels for the selected supported dtype pairs without duplicating promotion logic in kernel modules. | Must |
| FR-008 | Add concrete descriptor/storage modules for selected non-r64 dtypes in a way that keeps the r64 path readable. | Should |
| FR-009 | Add Fortran tests for dtype metadata, support state, promotion decisions, cast behavior, and unsupported dtype statuses. | Must |
| FR-010 | Add Python NumPy differential fixtures for the supported promotion and casting subset. | Must |
| FR-011 | Document the complex dtype plan and object dtype non-support. | Should |
| FR-012 | Preserve existing r64 constructor, broadcasting, elementwise, reduction, and view behavior. | Must |

## Non-Functional Requirements

- Fortran code must use `implicit none`, explicit kinds, private-by-default
  modules, and direct dtype suffixes as described in `STYLE_GUIDE.md`.
- New generic interfaces must be small and justified by tests.
- Dtype promotion must be centralized. Kernel modules may ask for promotion
  decisions, but they must not encode ad hoc promotion tables.
- Unsupported dtype paths must return `frumpy_status`; library code must not use
  casual `error stop`.
- Python dependencies must stay in a repo-local `.venv/` and remain ignored by
  git.
- All generated build artifacts must remain ignored.

## Acceptance Criteria

- `make test` runs the supported Fortran test suite from a clean checkout.
- `make python-test` runs Python differential tests when dependencies are
  installed in `.venv/`.
- `make validate` runs the full local validation path.
- `fpm test` either works or has a clear documented limitation.
- Existing r64 tests continue to pass.
- New dtype promotion/casting tests pass.
- NumPy differential tests pin the NumPy version observed during validation.
- `git diff --check` is clean.
- The current-surface stale-name check documented in `AGENTS.md` prints no
  matches.
- Docs state what dtype subset is supported, what is planned, and what is
  intentionally unsupported.

## Review Guidance

Reviewers should reject work if:

- It grows a generic dtype abstraction that is harder to follow than the
  concrete r64 path.
- Promotion decisions are duplicated across kernel modules.
- Unsupported dtype behavior is silent or ambiguous.
- Build/test targets hide failures or depend on host-global Python packages.
- Historical mission identifiers are renamed in a way that breaks Spec Kitty
  state.
- The mission drifts into Python packaging, C ABI work, linalg, random,
  indexing, or ML runtime scope.

## Open Questions For Planning

- Which non-r64 concrete descriptor should land first: `r32`, `i32`, `i64`, or
  boolean?
- Should this mission implement all selected dtype descriptors before promotion,
  or land promotion metadata first and cast kernels second?
- Can fpm cleanly discover the current standalone test programs, or should the
  Makefile remain the canonical validation path until the test harness is
  consolidated?
