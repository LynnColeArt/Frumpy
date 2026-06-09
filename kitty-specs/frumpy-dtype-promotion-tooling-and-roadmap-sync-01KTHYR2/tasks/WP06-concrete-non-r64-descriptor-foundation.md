---
work_package_id: WP06
title: Concrete Non-r64 Descriptor Foundation
dependencies:
- WP03
requirement_refs:
- FR-008
- FR-009
- FR-012
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: kitty/mission-frumpy-dtype-promotion-tooling-and-roadmap-sync-01KTHYR2
base_commit: 572e0eebcc0c7a6f7c2e52a503e2bb401bfbb4be
created_at: '2026-06-09T03:27:23.089780+00:00'
subtasks:
- T025
- T026
- T027
- T028
- T029
phase: Descriptor Expansion
assignee: ''
agent: ''
shell_pid: '1947072'
history:
- timestamp: '2026-06-07T21:15:00Z'
  agent: codex
  action: Prompt generated during mission task authoring
authoritative_surface: src/frumpy_ndarray_r32.f90
execution_mode: code_change
owned_files:
- src/frumpy_ndarray_r32.f90
- src/frumpy_ndarray_i32.f90
- src/frumpy_ndarray_i64.f90
- src/frumpy_ndarray_bool.f90
- test/test_ndarray_r32.f90
- test/test_ndarray_i32.f90
- test/test_ndarray_i64.f90
- test/test_ndarray_bool.f90
- src/frumpy.f90
tags: []
---

# Work Package Prompt: WP06 - Concrete Non-r64 Descriptor Foundation

## Objective

Add selected non-r64 ndarray descriptors while preserving the existing r64 path.

## Context

The `ndarray_r64` implementation is the reference descriptor. This WP should
duplicate only as much as needed to prove concrete dtype behavior before any
generic descriptor abstraction is attempted.

## Subtasks

- T025 Choose the smallest concrete non-r64 descriptor subset for this mission.
- T026 Implement descriptor/storage modules for the selected non-r64 dtypes.
- T027 Preserve the `ndarray_r64` invariants for shape, strides, offset, ownership, and contiguity.
- T028 Add descriptor tests for selected non-r64 dtypes.
- T029 Expose only reviewed descriptor surfaces through the umbrella `frumpy` module.

## Validation

Run `make validate` and the selected non-r64 descriptor tests.

## Review Guidance

Reject if the implementation changes `ndarray_r64` behavior without explicit
tests, or if the umbrella module exposes unreviewed dtype surfaces.
