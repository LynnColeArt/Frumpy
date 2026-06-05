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
branch_strategy: Planning artifacts for this mission target main. During implementation, trust the workspace and branch printed by Spec Kitty.
subtasks:
- T017
- T018
- T019
- T020
- T021
phase: "Phase 2 - Core Descriptor And Metadata"
assignee: ""
agent: ""
shell_pid: ""
history:
- timestamp: "2026-06-05T06:16:00Z"
  agent: codex
  action: Prompt generated during mission handoff
owned_files:
- src/fenum.f90
- src/fenum_ndarray_r64.f90
- test/test_ndarray_r64.f90
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
