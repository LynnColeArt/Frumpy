---
work_package_id: WP08
title: Views, Reshape, Transpose, And Slicing
dependencies:
- WP07
requirement_refs:
- FR-010
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission target main. During implementation, trust the workspace and branch printed by Spec Kitty.
subtasks:
- T040
- T041
- T042
- T043
- T044
- T045
phase: "Phase 6 - Views, Reshape, Transpose, And Slicing"
assignee: ""
agent: ""
shell_pid: ""
history:
- timestamp: "2026-06-05T06:16:00Z"
  agent: codex
  action: Prompt generated during mission handoff
owned_files:
- src/fenum_views_r64.f90
- src/fenum_slices.f90
- test/test_views_r64.f90
- python/tests/test_numpy_views.py
---

# Work Package Prompt: WP08 - Views, Reshape, Transpose, And Slicing

## Objective

Implement the first real view-like ndarray behavior.

## Context

Views are not copies. Slicing, transpose, and reshape must preserve backing
storage where NumPy would preserve it.

## Subtasks

- T040 Design and implement view ownership/base lifetime behavior.
- T041 Implement `reshape_r64`, `ravel_r64`, and `flatten_r64`.
- T042 Implement `transpose_r64`, `swapaxes_r64`, `squeeze_r64`, and `expand_dims_r64`.
- T043 Implement basic slice descriptors.
- T044 Implement slice-to-view and negative-stride view support.
- T045 Add NumPy differential tests for reshape, transpose, and slicing behavior.

## Validation

Run view tests and optional NumPy differential view tests.

## Review Guidance

Reject if lifetime/ownership is implicit or if non-contiguous arrays stop
working with existing kernels.
