---
work_package_id: WP05
title: Casting Kernels And Safety Policy
dependencies:
- WP04
requirement_refs:
- FR-007
- FR-009
- FR-010
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: kitty/mission-frumpy-dtype-promotion-tooling-and-roadmap-sync-01KTHYR2
base_commit: b10157ea99d8788a94646d0c79f4bd8df2265283
created_at: '2026-06-08T07:38:05.911702+00:00'
subtasks:
- T020
- T021
- T022
- T023
- T024
phase: Dtype Casting
assignee: ''
agent: ''
shell_pid: '377853'
history:
- timestamp: '2026-06-07T21:15:00Z'
  agent: codex
  action: Prompt generated during mission task authoring
authoritative_surface: src/frumpy_casting.f90
execution_mode: code_change
owned_files:
- src/frumpy_casting.f90
- test/test_casting.f90
- python/tests/test_numpy_casting.py
- docs/CASTING_POLICY.md
tags: []
---

# Work Package Prompt: WP05 - Casting Kernels And Safety Policy

## Objective

Implement explicit cast/copy behavior for the selected dtype subset.

## Context

Casting performs data conversion. Promotion selects a result dtype. Keeping them
separate makes behavior testable and prevents kernels from hiding conversion
policy.

## Subtasks

- T020 Add `frumpy_casting` with explicit cast/copy kernels for the selected dtype pairs.
- T021 Separate promotion decisions from cast execution.
- T022 Define status behavior for lossy, overflowing, or unsupported casts.
- T023 Add Fortran cast tests for supported and rejected casts.
- T024 Add Python fixtures for NumPy cast expectations.

## Validation

Run `make validate`, `test/test_casting.f90`, promotion tests, and Python dtype
fixtures.

## Review Guidance

Reject if casts silently overflow, silently narrow, or bypass status handling.
