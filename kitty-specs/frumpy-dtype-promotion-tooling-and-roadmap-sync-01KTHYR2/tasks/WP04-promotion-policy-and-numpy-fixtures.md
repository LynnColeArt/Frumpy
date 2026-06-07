---
work_package_id: WP04
title: Promotion Policy And NumPy Fixtures
dependencies:
- WP03
requirement_refs:
- FR-005
- FR-006
- FR-009
- FR-010
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts are generated on the mission coordination branch; completed changes must merge back into main.
subtasks:
- T015
- T016
- T017
- T018
- T019
phase: Dtype Promotion
assignee: ''
agent: ''
history:
- timestamp: '2026-06-07T21:15:00Z'
  agent: codex
  action: Prompt generated during mission task authoring
authoritative_surface: src/frumpy_promotion.f90
execution_mode: code_change
owned_files:
- src/frumpy_promotion.f90
- test/test_dtype_promotion.f90
- python/tests/test_numpy_dtype_promotion.py
- docs/DTYPE_SUPPORT.md
tags: []
---

# Work Package Prompt: WP04 - Promotion Policy And NumPy Fixtures

## Objective

Introduce table-driven dtype promotion for the selected supported subset.

## Context

Promotion decides result dtype; it should not perform casts and should not live
inside individual kernel modules. NumPy is the oracle for public behavior.

## Subtasks

- T015 Add `frumpy_promotion` with a table-driven promotion API for the selected dtype subset.
- T016 Define unsupported promotion status behavior for pairs outside the selected subset.
- T017 Add Fortran promotion tests for supported, unsupported, scalar-like, and identity pairs.
- T018 Add Python NumPy fixtures for expected promotion behavior and record the observed NumPy version.
- T019 Document the supported promotion subset and any intentional NumPy differences.

## Validation

Run `make validate`, `test/test_dtype_promotion.f90`, and
`python/tests/test_numpy_dtype_promotion.py`.

## Review Guidance

Reject if promotion rules are duplicated in constructor, elementwise, reduction,
or casting modules.
