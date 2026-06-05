---
work_package_id: WP01
title: Toolchain And Test Harness
dependencies: []
requirement_refs:
- FR-001
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission target main. During implementation, trust the workspace and branch printed by Spec Kitty.
subtasks:
- T001
- T002
- T003
- T004
- T005
phase: "Phase 1 - Toolchain And Test Harness"
assignee: ""
agent: ""
shell_pid: ""
history:
- timestamp: "2026-06-05T06:16:00Z"
  agent: codex
  action: Prompt generated during mission handoff
owned_files:
- fpm.toml
- Makefile
- src/**
- test/**
- examples/**
- bench/**
- python/tests/**
- README.md
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
