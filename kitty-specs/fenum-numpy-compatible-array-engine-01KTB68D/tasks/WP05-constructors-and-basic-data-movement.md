---
work_package_id: WP05
title: Constructors And Basic Data Movement
dependencies:
- WP04
requirement_refs:
- FR-006
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: kitty/mission-fenum-numpy-compatible-array-engine-01KTB68D
base_commit: 532a5d48dedd5acceee443415b749669f3a2d370
created_at: '2026-06-07T01:22:53.242887+00:00'
subtasks:
- T022
- T023
- T024
- T025
- T026
- T027
phase: Phase 3 - Constructors And Basic Data Movement
assignee: ''
agent: "codex:gpt-5:reviewer:reviewer"
shell_pid: "377853"
history:
- timestamp: '2026-06-05T06:16:00Z'
  agent: codex
  action: Prompt generated during mission handoff
authoritative_surface: src/fenum_constructors_r64.f90
execution_mode: code_change
owned_files:
- src/fenum_constructors_r64.f90
- test/test_constructors_r64.f90
- python/tests/test_numpy_constructors.py
tags: []
---

# Work Package Prompt: WP05 - Constructors And Basic Data Movement

## Objective

Implement initial `r64` constructors and copy/data-movement operations.

## Context

Copies must be explicit. Constructor behavior should match NumPy for the
supported subset.

## Subtasks

- T022 Implement `empty_r64`.
- T023 Implement `zeros_r64`, `ones_r64`, and `full_r64`.
- T024 Implement `arange_r64` and `linspace_r64`.
- T025 Implement `copy_r64`, `asarray_r64`, and `ascontiguousarray_r64`.
- T026 Add Fortran constructor/data-movement tests.
- T027 Add NumPy differential constructor fixtures for the supported subset.

## Validation

Run Fortran constructor tests and optional NumPy differential constructor tests.

## Review Guidance

Reject if a view-like operation hides a copy or allocation failure is not
reported through status.

## Activity Log

- 2026-06-07T01:25:56Z – codex:gpt-5:implementer:implementer – shell_pid=377853 – Assigned agent via action command
- 2026-06-07T01:35:31Z – codex:gpt-5:implementer:implementer – shell_pid=377853 – Ready for review: r64 constructors, copy/asarray/ascontiguousarray, Fortran tests, and NumPy fixtures
- 2026-06-07T01:35:55Z – codex:gpt-5:reviewer:reviewer – shell_pid=377853 – Started review via action command
- 2026-06-07T01:38:40Z – user – shell_pid=377853 – Review passed: Fortran constructor stack/tests green; Python fixture py_compile green; pytest unavailable because pytest is not installed. Shared-file note: src/fenum.f90 exports WP05 constructors through the public umbrella API.
