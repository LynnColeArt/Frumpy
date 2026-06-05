---
work_package_id: WP06
title: Broadcasting And Elementwise r64 Kernels
dependencies:
- WP05
requirement_refs:
- FR-007
- FR-008
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission target main. During implementation, trust the workspace and branch printed by Spec Kitty.
subtasks:
- T028
- T029
- T030
- T031
- T032
- T033
phase: "Phase 4 - Broadcasting And Elementwise Kernels"
assignee: ""
agent: ""
shell_pid: ""
history:
- timestamp: "2026-06-05T06:16:00Z"
  agent: codex
  action: Prompt generated during mission handoff
owned_files:
- src/fenum_broadcast.f90
- src/fenum_elementwise_r64.f90
- test/test_broadcast.f90
- test/test_elementwise_r64.f90
- python/tests/test_numpy_broadcast_elementwise.py
---

# Work Package Prompt: WP06 - Broadcasting And Elementwise r64 Kernels

## Objective

Implement NumPy-compatible broadcasting and initial `r64` elementwise kernels.

## Context

Broadcasting must use zero strides, not materialized copies. Correct strided
fallbacks must exist before optimized contiguous fast paths are trusted.

## Subtasks

- T028 Implement `broadcast_plan` and trailing-dimension shape negotiation.
- T029 Represent broadcasted dimensions with zero strides.
- T030 Implement binary add, subtract, multiply, and divide for `r64`.
- T031 Implement unary negate, abs, exp, log, sqrt, sin, and cos for `r64`.
- T032 Add strided fallback tests before optimized contiguous fast paths.
- T033 Add NumPy differential tests for broadcasting and elementwise kernels.

## Validation

Run broadcast, elementwise, and optional NumPy differential tests.

## Review Guidance

Reject if broadcasting is implemented as eager materialization or if scalar
operations allocate pretend scalar arrays.
