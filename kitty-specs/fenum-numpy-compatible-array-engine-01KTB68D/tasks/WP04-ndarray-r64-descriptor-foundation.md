---
work_package_id: WP04
title: ndarray_r64 Descriptor Foundation
dependencies:
- WP03
requirement_refs:
- FR-005
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: kitty/mission-fenum-numpy-compatible-array-engine-01KTB68D
base_commit: 6fcd2ebb42ed66864b0494b2b683d11ac0dd2d29
created_at: '2026-06-05T18:46:20.577910+00:00'
subtasks:
- T017
- T018
- T019
- T020
- T021
phase: Phase 2 - Core Descriptor And Metadata
assignee: ''
agent: "codex:gpt-5:implementer:implementer"
shell_pid: "377853"
history:
- timestamp: '2026-06-05T06:16:00Z'
  agent: codex
  action: Prompt generated during mission handoff
authoritative_surface: src/fenum_ndarray_r64.f90
execution_mode: code_change
owned_files:
- src/fenum.f90
- src/fenum_ndarray_r64.f90
- test/test_ndarray_r64.f90
tags: []
---

# Work Package Prompt: WP04 - ndarray_r64 Descriptor Foundation

## Objective

Implement the first concrete `ndarray_r64` descriptor and descriptor invariant
tests.

## Context

This WP should not implement elementwise math. It proves rank, shape, strides,
offset, ownership, contiguity, and backing storage before operations depend on
them.

## Subtasks

- T017 Implement the public umbrella module `fenum`.
- T018 Implement `ndarray_r64` with rank, shape, strides, offset, ownership, contiguity, and backing storage.
- T019 Add descriptor-only constructors for owned storage and descriptor metadata.
- T020 Add scalar inspection helpers for tests without making them permanent public API unless needed.
- T021 Add descriptor invariant tests before adding math kernels.

## Validation

Run descriptor tests and confirm no math kernels are required for the descriptor
to be testable.

## Review Guidance

Reject if ownership, offset semantics, or axis/dimension naming is vague.

## Activity Log

- 2026-06-05T18:46:30Z – codex:gpt-5:implementer:implementer – shell_pid=377853 – Assigned agent via action command
