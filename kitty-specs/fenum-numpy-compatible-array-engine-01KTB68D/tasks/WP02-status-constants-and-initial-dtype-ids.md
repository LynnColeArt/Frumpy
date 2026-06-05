---
work_package_id: WP02
title: Status, Constants, And Initial Dtype IDs
dependencies:
- WP01
requirement_refs:
- FR-002
- FR-011
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
subtasks:
- T006
- T007
- T008
- T009
- T010
phase: Phase 2 - Core Descriptor And Metadata
assignee: ''
agent: ''
history:
- timestamp: '2026-06-05T06:16:00Z'
  agent: codex
  action: Prompt generated during mission handoff
authoritative_surface: src/fenum_statuses.f90
execution_mode: code_change
owned_files:
- src/fenum_constants.f90
- src/fenum_statuses.f90
- src/fenum_dtypes.f90
- test/test_statuses.f90
- test/test_dtypes.f90
tags: []
---

# Work Package Prompt: WP02 - Status, Constants, And Initial Dtype IDs

## Objective

Create the project constants, status model, and first dtype identifiers needed
by later ndarray work.

## Context

Core library routines should report recoverable failures through status values,
not casual `error stop`. Dtype work should start concrete and modest.

## Subtasks

- T006 Implement project constants including maximum rank and order IDs.
- T007 Implement `fenum_status` and status codes for expected library failures.
- T008 Implement initial dtype IDs and metadata for `r64` plus planned supported dtypes.
- T009 Add tests for status initialization, failure detection, and unsupported behavior.
- T010 Add tests for dtype metadata and unsupported dtype status paths.

## Validation

Run the Fortran test suite. Status tests must cover OK, failure, invalid shape,
invalid axis, allocation failure, overflow, unsupported dtype, and unsupported
behavior paths.

## Review Guidance

Reject if dtype machinery becomes overly generic before the `r64` path exists.
