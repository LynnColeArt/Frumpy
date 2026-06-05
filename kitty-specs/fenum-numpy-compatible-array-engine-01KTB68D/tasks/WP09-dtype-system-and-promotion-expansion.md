---
work_package_id: WP09
title: Dtype System And Promotion Expansion
dependencies:
- WP08
requirement_refs:
- FR-011
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission target main. During implementation, trust the workspace and branch printed by Spec Kitty.
subtasks:
- T046
- T047
- T048
- T049
- T050
- T051
phase: "Phase 7 - Dtype System And Promotion"
assignee: ""
agent: ""
shell_pid: ""
history:
- timestamp: "2026-06-05T06:16:00Z"
  agent: codex
  action: Prompt generated during mission handoff
owned_files:
- src/fenum_dtypes.f90
- src/fenum_casting.f90
- src/fenum_ndarray_r32.f90
- src/fenum_ndarray_i32.f90
- src/fenum_ndarray_i64.f90
- src/fenum_ndarray_bool.f90
- test/test_dtype_promotion.f90
- python/tests/test_numpy_dtype_promotion.py
---

# Work Package Prompt: WP09 - Dtype System And Promotion Expansion

## Objective

Expand from `r64` into an explicit dtype metadata and promotion system.

## Context

Promotion rules are subtle. Keep the implementation table-driven and tested
against NumPy for the supported subset.

## Subtasks

- T046 Expand dtype metadata for `r32`, `r64`, `i32`, `i64`, and boolean.
- T047 Implement table-driven promotion rules for supported dtype pairs.
- T048 Implement cast/copy kernels for supported dtype pairs.
- T049 Add concrete descriptor rollout for supported dtypes without obscuring the `r64` path.
- T050 Document the complex dtype plan.
- T051 Add NumPy differential dtype promotion tests.

## Validation

Run dtype tests and optional NumPy differential dtype promotion tests.

## Review Guidance

Reject if promotion logic is duplicated across random modules or unsupported
dtypes fail ambiguously.
