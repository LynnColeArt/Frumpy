---
work_package_id: WP07
title: Reductions, Axis Semantics, And First Vertical Slice
dependencies:
- WP06
requirement_refs:
- FR-009
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
subtasks:
- T034
- T035
- T036
- T037
- T038
- T039
phase: Phase 5 - Reductions And Axis Semantics
assignee: ''
agent: ''
history:
- timestamp: '2026-06-05T06:16:00Z'
  agent: codex
  action: Prompt generated during mission handoff
authoritative_surface: src/fenum_reductions_r64.f90
execution_mode: code_change
owned_files:
- src/fenum_reductions_r64.f90
- test/test_reductions_r64.f90
- examples/first_vertical_slice.f90
- python/tests/test_numpy_reductions.py
tags: []
---

# Work Package Prompt: WP07 - Reductions, Axis Semantics, And First Vertical Slice

## Objective

Implement initial reductions and prove the first end-to-end NumPy-compatible
vertical slice.

## Context

Public axes are NumPy-facing and 0-based. Internal Fortran dimensions must be
named distinctly when converted.

## Subtasks

- T034 Implement 0-based `axis0` validation helpers.
- T035 Implement `sum_r64`, `prod_r64`, `min_r64`, `max_r64`, and `mean_r64`.
- T036 Implement phased `keepdims` support for reductions.
- T037 Document and test empty-reduction behavior.
- T038 Add the first vertical slice example from `PROJECT_PLAN.md`.
- T039 Add NumPy differential reduction tests.

## Validation

Run reduction tests, the first vertical slice example, and optional NumPy
differential reduction tests.

## Review Guidance

Reject if axis handling silently uses Fortran dimension semantics at the public
boundary.
