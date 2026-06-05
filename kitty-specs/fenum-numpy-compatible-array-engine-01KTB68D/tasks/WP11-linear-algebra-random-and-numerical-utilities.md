---
work_package_id: WP11
title: Linear Algebra, Random, And Numerical Utilities
dependencies:
- WP09
requirement_refs:
- FR-013
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission target main. During implementation, trust the workspace and branch printed by Spec Kitty.
subtasks:
- T058
- T059
- T060
- T061
- T062
- T063
phase: "Phase 9 - Linear Algebra, Random, And Numerical Utilities"
assignee: ""
agent: ""
shell_pid: ""
history:
- timestamp: "2026-06-05T06:16:00Z"
  agent: codex
  action: Prompt generated during mission handoff
owned_files:
- src/fenum_linalg_lapack.f90
- src/fenum_random.f90
- docs/FFT_STRATEGY.md
- test/test_linalg.f90
- test/test_random.f90
- python/tests/test_numpy_linalg_random.py
---

# Work Package Prompt: WP11 - Linear Algebra, Random, And Numerical Utilities

## Objective

Add core numerical operations expected by serious NumPy users.

## Context

BLAS/LAPACK wrappers should be isolated. Random behavior must be documented and
reproducible for supported cases.

## Subtasks

- T058 Implement `matmul`, `dot`, and `outer` for supported dtypes.
- T059 Isolate BLAS/LAPACK wrappers behind Fenum modules.
- T060 Plan and implement a matrix/vector norm subset.
- T061 Document random generator design.
- T062 Implement uniform and normal random distributions.
- T063 Write `docs/FFT_STRATEGY.md` before FFT implementation work.

## Validation

Run linalg/random tests and optional NumPy differential tests with explicit
tolerances.

## Review Guidance

Reject if this WP drifts into SciPy replacement scope.
