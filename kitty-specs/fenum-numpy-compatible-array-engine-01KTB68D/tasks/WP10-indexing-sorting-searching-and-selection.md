---
work_package_id: WP10
title: Indexing, Sorting, Searching, And Selection
dependencies:
- WP09
requirement_refs:
- FR-012
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission target main. During implementation, trust the workspace and branch printed by Spec Kitty.
subtasks:
- T052
- T053
- T054
- T055
- T056
- T057
phase: "Phase 8 - Indexing, Sorting, Searching, And Selection"
assignee: ""
agent: ""
shell_pid: ""
history:
- timestamp: "2026-06-05T06:16:00Z"
  agent: codex
  action: Prompt generated during mission handoff
owned_files:
- src/fenum_indexing.f90
- src/fenum_selection.f90
- src/fenum_sorting.f90
- test/test_indexing.f90
- test/test_selection.f90
- test/test_sorting.f90
- python/tests/test_numpy_indexing_selection_sorting.py
---

# Work Package Prompt: WP10 - Indexing, Sorting, Searching, And Selection

## Objective

Phase in practical non-math ndarray operations.

## Context

Advanced indexing can explode scope. Keep copy-vs-view behavior explicit for
every supported mode.

## Subtasks

- T052 Define integer indexing and boolean mask policies.
- T053 Implement the initial `where` subset.
- T054 Implement the initial `take` subset.
- T055 Implement `concatenate` and `stack`.
- T056 Implement `sort` and `argsort` subsets.
- T057 Add tests for copy-vs-view behavior, empty arrays, repeated values, and axis cases.

## Validation

Run indexing, selection, sorting, and optional NumPy differential tests.

## Review Guidance

Reject if advanced indexing scope expands without explicit acceptance criteria.
