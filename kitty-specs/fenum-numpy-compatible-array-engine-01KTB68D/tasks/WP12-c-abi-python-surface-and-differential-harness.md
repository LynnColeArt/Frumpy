---
work_package_id: WP12
title: C ABI, Python Surface, And Differential Harness
dependencies:
- WP07
- WP09
requirement_refs:
- FR-014
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission target main. During implementation, trust the workspace and branch printed by Spec Kitty.
subtasks:
- T064
- T065
- T066
- T067
- T068
phase: "Phase 10 - C ABI, Python Package, And Differential Testing"
assignee: ""
agent: ""
shell_pid: ""
history:
- timestamp: "2026-06-05T06:16:00Z"
  agent: codex
  action: Prompt generated during mission handoff
owned_files:
- src/fenum_c_api.f90
- include/fenum.h
- python/fenum/**
- python/tests/**
- docs/C_ABI.md
---

# Work Package Prompt: WP12 - C ABI, Python Surface, And Differential Harness

## Objective

Expose Fenum without leaking Fortran compiler-specific internals.

## Context

Python interop should not swallow the Fortran core. The C ABI must have an
explicit descriptor and ownership strategy before package work deepens.

## Subtasks

- T064 Document C ABI descriptor and ownership strategy in `docs/C_ABI.md`.
- T065 Implement the first stable C ABI surface without exposing compiler-specific Fortran layout.
- T066 Add a Python package skeleton and `fenum.ndarray` wrapper.
- T067 Expose Python constructors and basic operations for the supported subset.
- T068 Test ownership, destruction, and NumPy differential behavior from Python.

## Validation

Run ABI tests, Python wrapper tests, and NumPy differential tests where
available.

## Review Guidance

Reject if ABI ownership is ambiguous or if Python packaging changes core
Fortran semantics.
