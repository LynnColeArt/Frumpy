---
work_package_id: WP03
title: Dtype Metadata Table And Support Docs
dependencies:
- WP01
requirement_refs:
- FR-004
- FR-009
- FR-011
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: kitty/mission-frumpy-dtype-promotion-tooling-and-roadmap-sync-01KTHYR2
base_commit: a45415f9e6a37a3819179547b9f7461896ed1846
created_at: '2026-06-08T04:53:53.471238+00:00'
subtasks:
- T010
- T011
- T012
- T013
- T014
phase: Dtype Foundation
assignee: ''
agent: "codex"
shell_pid: "377853"
history:
- timestamp: '2026-06-07T21:15:00Z'
  agent: codex
  action: Prompt generated during mission task authoring
authoritative_surface: src/frumpy_dtypes.f90
execution_mode: code_change
owned_files:
- src/frumpy_dtypes.f90
- test/test_dtypes.f90
- docs/DTYPE_METADATA.md
tags: []
---

# Work Package Prompt: WP03 - Dtype Metadata Table And Support Docs

## Objective

Make `frumpy_dtypes` the authoritative dtype metadata source before adding
promotion and casting behavior.

## Context

Frumpy currently has dtype IDs for `bool`, `i32`, `i64`, `r32`, and `r64`, but
only `r64` is operationally supported. This WP turns that into an explicit table
with support status and documentation.

## Subtasks

- T010 Expand `frumpy_dtypes` into a table-backed dtype metadata source.
- T011 Track dtype IDs, names, byte sizes, support state, and planned/unsupported status messages.
- T012 Keep `r64` supported while making non-r64 support claims explicit.
- T013 Extend Fortran dtype tests for table lookup and unsupported statuses.
- T014 Start `docs/DTYPE_METADATA.md` with dtype IDs, support states, and unsupported dtype categories.

## Validation

Run `make validate`, or direct full Fortran/Python validation if WP01 has not
landed yet. Include focused dtype metadata tests.

## Review Guidance

Reject if metadata docs claim non-r64 operations work before descriptors,
promotion, and casting support actually land.

## Activity Log

- 2026-06-08T04:59:37Z – codex – shell_pid=377853 – Started review via action command
- 2026-06-08T05:03:07Z – user – shell_pid=377853 – Review passed: table-backed dtype metadata, focused dtype tests, and docs validated with make validate
