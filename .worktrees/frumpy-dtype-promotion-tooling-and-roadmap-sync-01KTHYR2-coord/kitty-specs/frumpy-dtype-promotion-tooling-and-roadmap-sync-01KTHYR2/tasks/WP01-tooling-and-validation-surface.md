---
work_package_id: WP01
title: Tooling And Validation Surface
dependencies: []
requirement_refs:
- FR-001
- FR-002
- FR-012
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: kitty/mission-frumpy-dtype-promotion-tooling-and-roadmap-sync-01KTHYR2
base_commit: e8fa65daadcba7abe7fa0ab66488a91d4c1004a8
created_at: '2026-06-08T04:21:32.110753+00:00'
subtasks:
- T001
- T002
- T003
- T004
- T005
phase: Tooling Foundation
assignee: ''
agent: "codex"
shell_pid: "377853"
history:
- timestamp: '2026-06-07T21:15:00Z'
  agent: codex
  action: Prompt generated during mission task authoring
authoritative_surface: Makefile
execution_mode: code_change
owned_files:
- Makefile
- fpm.toml
- bench/**
- docs/BUILDING.md
- .gitignore
tags: []
---

# Work Package Prompt: WP01 - Tooling And Validation Surface

## Objective

Make Frumpy boring to build and test locally.

## Context

The current source validates with direct `gfortran` commands, but the command
line is too long for routine contributor use. This WP creates the stable local
validation surface that later dtype WPs can depend on.

## Subtasks

- T001 Add a `Makefile` with `build`, `test`, `python-test`, `validate`, and `clean` targets.
- T002 Encode the current strict `gfortran` source order and test programs in the Makefile.
- T003 Add `fpm.toml` metadata or a documented limitation if fpm cannot cleanly run the current standalone tests.
- T004 Add or reserve `bench/` with a minimal benchmark/readme surface.
- T005 Add `docs/BUILDING.md` with the canonical local validation commands.

## Validation

Run `make validate` if available by the end of the WP. Before that target is
complete, run the current direct `gfortran` full test stack, Python differential
tests from `.venv/`, and `git diff --check`.

## Review Guidance

Reject if targets depend on host-global Python packages, hide failing test
programs, or make fpm support look complete when it is only partial.

## Activity Log

- 2026-06-08T04:27:52Z – codex – shell_pid=377853 – Ready for review: WP01 tooling committed at 4197e8e; make clean && make validate && make fpm-test passed, with fpm absent and documented.
- 2026-06-08T04:28:52Z – codex – shell_pid=377853 – Started review via action command
- 2026-06-08T04:29:50Z – user – shell_pid=377853 – Review passed: WP01 adds scoped Makefile/fpm/docs/bench tooling, keeps Python dependencies repo-local, and make clean && make validate && make fpm-test passed.
