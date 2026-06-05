<!-- spec-kitty intake: ingested from SPEC_KITTY_HANDOFF.md at 2026-06-05T06:06:44.464475+00:00 -->
<!-- brief_hash: 414d6514f1f70948396971a7008b8e2b4ba6a4a6ccf9c1e8b142394a49044478 -->

# Spec Kitty Handoff: Fenum NumPy-Compatible Array Engine

This document is the mission brief for Spec Kitty.

Mission name:

- Fenum NumPy-compatible array engine

Suggested mission slug:

- `fenum-numpy-compatible-array-engine`

Mission type:

- `software-dev`


## Product Intent

Fenum is a Fortran 2018 NumPy-compatible array engine.

The project should implement NumPy-shaped ndarray behavior in readable modern
Fortran. The goal is not to imitate Python syntax. The goal is to provide the
same array semantics NumPy users rely on: shape behavior, dtype handling,
broadcasting, views, copies, strides, reductions, indexing, and linear algebra.

Fenum should make the point that modern numerical infrastructure can be fast,
explicit, humane, and easy to follow.


## Required Context

Spec Kitty should treat these files as authoritative:

- [README.md](README.md): project identity and current scope.
- [STYLE_GUIDE.md](STYLE_GUIDE.md): Fortran coding rules and ndarray semantics.
- [PROJECT_PLAN.md](PROJECT_PLAN.md): phased implementation roadmap.
- [AGENTS.md](AGENTS.md): contributor and agent operating rules.


## Current Scope

The active scope is NumPy only.

Fenum owns:

- NumPy-compatible ndarray semantics.
- Shape, stride, dtype, memory, view, and copy behavior.
- NumPy-compatible creation and manipulation functions.
- Elementwise arithmetic.
- Reductions and axis behavior.
- Indexing, sorting, searching, and selection as phased work.
- CPU reference kernels.
- BLAS/LAPACK-backed dense linear algebra.
- A stable C ABI and eventual Python package surface.
- NumPy differential tests for every supported public behavior.


## Explicit Non-Goals

Do not include these in the current mission scope:

- Torch compatibility.
- Autograd.
- Neural-network modules.
- Training loops.
- Diffusers support.
- Safetensors or model loading.
- Tokenizers.
- GPU runtime design.
- A complete SciPy replacement.

Future projects may use Fenum. They do not belong inside this mission.


## Mission Shape

Give Spec Kitty the full Fenum NumPy replacement as one long-horizon mission.
Do not split the vision into many independent missions yet.

The mission should decompose the work into phased, dependency-aware work
packages. Work packages should be small enough to implement and review, but
they should preserve the long-range project architecture.

The expected phase structure is:

1. Toolchain and test harness.
2. Core descriptor and metadata.
3. Constructors and basic data movement.
4. Broadcasting and elementwise kernels.
5. Reductions and axis semantics.
6. Views, reshape, transpose, and slicing.
7. Dtype system and promotion.
8. Indexing, sorting, searching, and selection.
9. Linear algebra, random, and numerical utilities.
10. C ABI, Python package, and differential testing.
11. Performance and completeness.


## Acceptance Themes

Every generated spec, plan, and WP should preserve these themes:

- NumPy is the oracle for public behavior.
- Fortran code should be explicit, readable, and strongly typed.
- Shape, stride, offset, ownership, and contiguity invariants must be preserved.
- Public APIs use NumPy-facing semantics, including 0-based axes.
- Internal Fortran helpers may use 1-based dimensions, but names must make the
  conversion explicit.
- Hidden copies are bugs unless the API promises a copy.
- Tests should prove Fortran invariants and NumPy compatibility.
- Fast paths are allowed only after correct strided fallbacks exist.
- Library code should use status-based error handling, not casual `error stop`.


## First Vertical Slice

The first satisfying end-to-end slice should be:

```text
a = zeros([2, 3])
b = full([3], 2.0)
c = a + b
d = reshape(c, [3, 2])
e = sum(d, axis0=1)
```

Fortran should execute the slice. NumPy differential tests should verify the
result for the supported subset.


## Review Instructions

A reviewer should reject generated artifacts or implementation WPs when:

- The scope drifts beyond NumPy.
- ndarray metadata is vague.
- dtype promotion is hand-waved.
- view/copy behavior is not explicit.
- tests do not compare against NumPy where public behavior is involved.
- Fortran style rules from `STYLE_GUIDE.md` are ignored.
- work packages are too large to review confidently.

The mission is allowed to be large. The work packages are not allowed to be
foggy.
