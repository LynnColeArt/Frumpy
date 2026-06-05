---
work_package_id: WP03
title: Shape And Stride Metadata
dependencies:
- WP02
requirement_refs:
- FR-003
- FR-004
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission target main. During implementation, trust the workspace and branch printed by Spec Kitty.
subtasks:
- T011
- T012
- T013
- T014
- T015
- T016
phase: "Phase 2 - Core Descriptor And Metadata"
assignee: ""
agent: ""
shell_pid: ""
history:
- timestamp: "2026-06-05T06:16:00Z"
  agent: codex
  action: Prompt generated during mission handoff
owned_files:
- src/fenum_shape.f90
- src/fenum_strides.f90
- test/test_shape.f90
- test/test_strides.f90
---

# Work Package Prompt: WP03 - Shape And Stride Metadata

## Objective

Implement shape, element-count, stride, and contiguity utilities before any
ndarray math exists.

## Context

Shape and stride metadata are the load-bearing ndarray foundation. Public
NumPy semantics default to C order; Fortran's native order must not leak by
accident.

## Subtasks

- T011 Implement shape validation for scalar, empty, singleton, and multidimensional arrays.
- T012 Implement overflow-checked element-count computation.
- T013 Implement C-order stride calculation using signed element strides.
- T014 Implement Fortran-order stride calculation using signed element strides.
- T015 Implement C-contiguity and Fortran-contiguity checks.
- T016 Add tests for zero-sized dimensions, scalar arrays, and negative-stride planning assumptions.

## Validation

Run Fortran shape and stride tests. Include scalar, empty, singleton,
multidimensional, C-order, F-order, and overflow cases.

## Review Guidance

Reject if shape values are default integers, strides are unsigned, or stride
units are ambiguous.
