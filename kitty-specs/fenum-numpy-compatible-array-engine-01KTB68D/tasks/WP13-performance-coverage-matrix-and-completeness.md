---
work_package_id: WP13
title: Performance, Coverage Matrix, And Completeness
dependencies:
- WP10
- WP11
- WP12
requirement_refs:
- FR-015
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
subtasks:
- T069
- T070
- T071
- T072
- T073
phase: Phase 11 - Performance And Completeness
assignee: ''
agent: ''
history:
- timestamp: '2026-06-05T06:16:00Z'
  agent: codex
  action: Prompt generated during mission handoff
authoritative_surface: bench/fenum_benchmarks.f90
execution_mode: code_change
owned_files:
- bench/fenum_benchmarks.f90
- bench/run_benchmarks.sh
- docs/NUMPY_COVERAGE.md
- docs/PERFORMANCE.md
- docs/OPENMP_SIMD_NOTES.md
tags: []
---

# Work Package Prompt: WP13 - Performance, Coverage Matrix, And Completeness

## Objective

Make Fenum faster and more complete without sacrificing correctness or
readability.

## Context

Performance claims must be measured. Unsupported NumPy features must be
discoverable.

## Subtasks

- T069 Add benchmarks for contiguous, strided, and broadcasted cases.
- T070 Add BLAS backend comparison benchmarks.
- T071 Add allocation profiling notes and regression checks where practical.
- T072 Document OpenMP and SIMD strategy notes after measured bottlenecks.
- T073 Maintain `docs/NUMPY_COVERAGE.md` and document unsupported NumPy features.

## Validation

Run benchmark smoke checks, full available tests, and coverage documentation
checks.

## Review Guidance

Reject if fast paths replace correctness paths or if unsupported features are
hidden from users.
