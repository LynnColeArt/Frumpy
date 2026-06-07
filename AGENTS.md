# AGENTS.md

This file is for agents and contributors working in Fenum.

Fenum is a Fortran 2018 NumPy-compatible array engine. Treat that sentence as a
scope boundary, not a slogan.

Read these first:

- [README.md](README.md)
- [STYLE_GUIDE.md](STYLE_GUIDE.md)
- [PROJECT_PLAN.md](PROJECT_PLAN.md)


## Engineering Philosophy

This project values small, direct, understandable numerical code.

Prefer the simplest implementation that preserves NumPy semantics without
creating downstream complexity. Simple does not mean naive. It means the
shortest clear path from the current requirement to correct behavior, with the
fewest moving parts required to keep the system testable, maintainable, and
easy to reason about.

Avoid ceremony unless the problem clearly earns it. Fenum should feel like
precise Fortran, not a framework that happens to compile.


## Core Principles

### NumPy Is The Oracle

When public behavior is meant to match NumPy, verify it against NumPy.

Do not guess shape behavior, broadcasting, dtype promotion, axis handling,
empty-array behavior, or copy-vs-view semantics. Check NumPy, encode the
behavior in tests, and document intentional departures.

If Fenum behaves differently from NumPy, the difference must be:

- Intentional.
- Documented.
- Tested.
- Visible to users.


### Scope Discipline

Fenum is scoped to NumPy right now.

Do not implement Torch compatibility, autograd, Diffusers support, model
loading, GPU runtime design, or training infrastructure in this repo unless the
project scope has explicitly changed.

Future ML ecosystem work may sit on top of Fenum. It must not distort the
current ndarray design.


### Code Minimalism

Write less code when less code is enough.

Every abstraction, dependency, helper module, generic interface, or backend
layer must earn its place. If the code is easier to understand without it,
remove it.

Do not build speculative flexibility. Solve the current NumPy-compatible
behavior cleanly, leaving the code easy to change later.


### DRY, Correctly Applied

Avoid needless repetition, but do not create premature abstractions just to
remove duplicated lines.

Duplication is sometimes cheaper than indirection. Abstract only when the
shared shape is real, stable, and improves clarity.

This matters especially for dtype work. Do not create a generic dtype machine
before the concrete `r64` path teaches us the real shape of the code.


### Test-Driven Compatibility

Use TDD as a design discipline.

For Fenum, a test should usually prove one of two things:

- A Fortran invariant is true.
- Fenum matches NumPy for a supported behavior.

Remember the three rules of TDD:

1. Do not write production code unless it is needed to make a failing test pass.
2. Do not write more of a test than is sufficient to fail.
3. Do not write more production code than is sufficient to pass the failing
   test.

Tests should drive the shape of the code, not merely decorate it after the
fact.


### Shape And Stride Honesty

Shape, stride, offset, ownership, and contiguity metadata are not bookkeeping
details. They are the ndarray.

Every operation that changes array interpretation must preserve or recompute:

- Rank.
- Shape.
- Strides.
- Offset.
- Ownership.
- C-contiguity.
- Fortran-contiguity.
- Copy-vs-view behavior.

Hidden copies are bugs unless the API explicitly promises a copy.


### Separation Of Concerns

Keep concerns compartmentalized and easy to reason about.

Shape utilities should not allocate storage. Broadcasting plans should not run
kernels. Kernels should not decide dtype promotion. Python interop should not
leak into the Fortran core.

Each module should have a clear responsibility. Avoid broad modules named
`utils`, `helpers`, `common`, or `misc`.


### Fits-In-Head Rule

A module should fit in a developer's head.

When reading a module, it should be possible to understand what it does, why it
exists, and how it interacts with the rest of the system without spelunking
through hidden dependencies.

If a module becomes difficult to hold mentally, split it by ndarray
responsibility: shape, strides, broadcasting, dtype, storage, kernels,
reductions, views, or interop.


## Fortran Mindset

Approach this project with a modern Fortran mindset:

- Be explicit.
- Use `implicit none`.
- Use `only:` lists on imports.
- Prefer clear ownership.
- Prefer concrete code over clever abstraction.
- Treat allocation, failure, and state as visible and intentional.
- Use explicit kinds for numeric declarations.
- Keep array memory order explicit.
- Avoid magic.
- Avoid hidden behavior.
- Make the cost of code obvious.

The goal is not to imitate Python. The goal is to implement NumPy-compatible
semantics in Fortran with clarity and confidence.


## Error Handling

Library code should not casually terminate the process.

Use `fenum_status` or another documented status path for:

- Invalid shapes.
- Invalid axes.
- Allocation failures.
- Overflow.
- Unsupported dtype behavior.
- Unsupported NumPy behavior.

Tests and examples may use `error stop`. Core library routines should preserve
the caller's ability to recover.


## Comments

Comments are a time machine for the team.

Use comments to explain why something exists, not what the code mechanically
does.

Good comments clarify intent, constraints, tradeoffs, surprising NumPy
compatibility details, or historical context. Bad comments narrate obvious
code.

Use comments sparingly. Add them when the code diverges from an expected
outcome or pattern, or when future readers will need context they cannot infer
from the implementation alone.


## Review Standard

Assume this code will be reviewed by a QA agent with standards higher than your
own.

Before presenting work as complete, check for:

- NumPy behavior verified or intentionally documented as unsupported.
- Shape, stride, offset, ownership, and contiguity invariants preserved.
- No hidden copies in view-like operations.
- No accidental future-ML scope creep.
- No unnecessary abstractions.
- No unjustified dependencies.
- No overly clever control flow.
- No hidden global state.
- Good separation of concerns.
- Missing tests.
- Weak error handling.
- Comments that explain what instead of why.
- Code that solves a larger problem than the one actually requested.

If the solution feels impressive but not obvious, simplify it.


## Antipatterns

Avoid:

- Enterprise ceremonial dogma.
- Abstractions that cannot be justified.
- Dependencies that cannot be justified.
- Cleverness.
- Speculative architecture.
- Configuration sprawl.
- Hidden global state.
- Framework-first thinking.
- Overbroad modules.
- Tests that only verify mocks.
- Comments that restate the code.
- Indirection that exists only to look professional.
- Treating Fortran's memory order as NumPy's public default.
- Treating broadcasting as materialization.
- Treating dtype promotion as an afterthought.
- Writing Torch, Diffusers, or autograd code in Fenum.

Prefer code that is boring, sharp, readable, and correct.


## Default Work Pattern

When changing Fenum:

1. Identify the NumPy behavior being implemented.
2. Add or update the smallest useful compatibility or invariant test.
3. Implement the smallest Fortran change that passes it.
4. Run the relevant tests.
5. Update documentation when behavior, scope, or compatibility changes.

Keep the mountain visible, but climb the next rock.


## Python Environment Policy

Do not assume a rich host Python environment.

Fenum may use Python to compare behavior against NumPy, but host Python
configuration can be unstable across machines. Treat the system `python3` as a
minimal tool for basic scripts only.

If NumPy, pytest, or other Python packages are needed for local compatibility
checks, create a repo-local virtual environment such as `.venv/`. Keep virtual
environments out of git and do not install project-specific Python packages into
the host Python environment.
