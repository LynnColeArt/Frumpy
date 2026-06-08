---
work_package_id: WP02
title: Frumpy Artifact Reconciliation
dependencies:
- WP01
requirement_refs:
- FR-003
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: kitty/mission-frumpy-dtype-promotion-tooling-and-roadmap-sync-01KTHYR2
base_commit: 77360a8a3794f1aa0e5e379b294b24c1fc40476e
created_at: '2026-06-08T04:33:14.259254+00:00'
subtasks:
- T006
- T007
- T008
- T009
phase: Project Reconciliation
assignee: ''
agent: "codex"
shell_pid: "377853"
history:
- timestamp: '2026-06-07T21:15:00Z'
  agent: codex
  action: Prompt generated during mission task authoring
authoritative_surface: AGENTS.md
execution_mode: code_change
owned_files:
- .kittify/charter/charter.md
- PROJECT_PLAN.md
- STYLE_GUIDE.md
- AGENTS.md
- README.md
- SPEC_KITTY_HANDOFF.md
tags: []
---

# Work Package Prompt: WP02 - Frumpy Artifact Reconciliation

## Objective

Align current-facing project and mission guidance with the Frumpy name without
breaking historical Spec Kitty identifiers.

## Context

The source tree is now `frumpy_*`, but older mission files still contain
pre-rename paths. Some are harmless identifiers. Some are current instructions
that would mislead future agents.

## Subtasks

- T006 Classify current-facing Frumpy names versus historical pre-rename identifiers before editing.
- T007 Update current-facing docs and active planning artifacts to use `frumpy_*` module paths.
- T008 Preserve historical mission slugs and archived identifiers that Spec Kitty state depends on.
- T009 Add a stale-name check that ignores intentionally historical mission paths.

## Validation

Run the stale-name check, `make validate`, and `git diff --check`.

## Review Guidance

Reject blind global replacement. Historical mission slugs and branch names may
retain pre-rename text; current contributor instructions and active code paths
should not.

## Activity Log

- 2026-06-08T04:41:24Z – codex – shell_pid=377853 – Ready for review: classified current-facing vs historical pre-rename references; stale-name check clean; make validate and make fpm-test passed with fpm absent and documented.
- 2026-06-08T04:42:05Z – codex – shell_pid=377853 – Started review via action command
- 2026-06-08T04:42:45Z – user – shell_pid=377853 – Review passed: WP02 updates current-facing charter/agent guidance, keeps archived pre-rename identifiers out of scope, and validation passed.
