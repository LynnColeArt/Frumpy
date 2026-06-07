---
work_package_id: WP01
title: Toolchain And Test Harness
dependencies: []
requirement_refs:
- FR-001
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: kitty/mission-fenum-numpy-compatible-array-engine-01KTB68D
base_commit: ebca9716676ab638f5a0de39742256eb12e35058
created_at: '2026-06-05T11:47:39.187293+00:00'
subtasks:
- T001
- T002
- T003
- T004
- T005
phase: Phase 1 - Toolchain And Test Harness
assignee: ''
agent: "codex:gpt-5:reviewer:reviewer"
shell_pid: "377853"
history:
- timestamp: '2026-06-05T06:16:00Z'
  agent: codex
  action: Prompt generated during mission handoff
authoritative_surface: fpm.toml
execution_mode: code_change
owned_files:
- fpm.toml
- Makefile
- src/.gitkeep
- test/.gitkeep
- test/test_runner.f90
- test/test_smoke.f90
- examples/.gitkeep
- bench/.gitkeep
- python/tests/.gitkeep
- python/tests/test_numpy_smoke.py
- README.md
tags: []
---

# Work Package Prompt: WP01 - Toolchain And Test Harness

## Objective

Create the build/test surface Fenum needs before library code begins.

## Context

Fenum is a Fortran 2018 NumPy-compatible array engine. This WP should make the
project boring to build and test locally, with `gfortran` available even when
`fpm` is missing.

## Subtasks

- T001 Create the canonical source/test/example/bench/python directory layout.
- T002 Add `fpm.toml` for the Fortran package path.
- T003 Add `Makefile` fallback commands for build, test, clean, and optional Python differential tests.
- T004 Add a minimal Fortran test runner and one smoke test.
- T005 Add an optional Python NumPy differential smoke test that skips cleanly without NumPy.

## Validation

Run `make test`. If `fpm` is installed, run `fpm test`. Optional Python tests
must skip cleanly when NumPy is unavailable.

## Review Guidance

Reject if tooling is decorative, hard to run, or introduces a dependency not
justified by the current Fortran-first scope.

## Activity Log

- 2026-06-05T11:48:55Z – codex:gpt-5:implementer:implementer – shell_pid=377853 – Assigned agent via action command
- 2026-06-05T11:55:19Z – codex:gpt-5:implementer:implementer – shell_pid=377853 – Ready for review: toolchain and smoke test harness added
- 2026-06-05T11:57:04Z – codex:gpt-5:reviewer:reviewer – shell_pid=377853 – Started review via action command
- 2026-06-05T11:59:12Z – codex:gpt-5:reviewer:reviewer – shell_pid=377853 – Review passed: toolchain, Makefile fallback, Fortran smoke runner, and optional NumPy smoke tests validated
