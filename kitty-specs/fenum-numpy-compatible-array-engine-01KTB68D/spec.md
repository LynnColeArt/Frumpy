# Specification: Fenum NumPy-Compatible Array Engine

Mission slug:

- `fenum-numpy-compatible-array-engine-01KTB68D`

Mission type:

- `software-dev`

Target branch:

- `main`


## Summary

Fenum is a Fortran 2018 NumPy-compatible array engine.

This mission covers the full long-horizon implementation of Fenum as a
NumPy-shaped ndarray library. The mission should be decomposed into phased,
dependency-aware work packages that preserve the long-range architecture while
remaining small enough to implement, test, and review.

The current scope is NumPy only. Future ML ecosystem use may benefit from
Fenum, but Torch compatibility, autograd, Diffusers support, model loading,
tokenizers, GPU runtime design, and training infrastructure are explicit
non-goals for this mission.


## Authoritative Project Context

Agents and reviewers must use these files as mission context:

- `README.md`: project identity and active scope.
- `STYLE_GUIDE.md`: Fortran coding standards and ndarray semantic rules.
- `PROJECT_PLAN.md`: phased roadmap and Spec Kitty handoff model.
- `AGENTS.md`: agent operating rules and review expectations.
- `SPEC_KITTY_HANDOFF.md`: mission brief ingested by Spec Kitty.


## Product Goals

- Build a readable modern Fortran 2018 ndarray engine.
- Match NumPy public behavior for the supported subset.
- Use NumPy as the reference oracle for compatibility tests.
- Preserve explicit shape, stride, offset, ownership, dtype, and contiguity
  semantics.
- Provide a clean foundation for later Python/C interop without leaking Fortran
  compiler-specific internals into public APIs.
- Keep each implementation phase concrete, testable, and reviewable.


## Non-Goals

This mission must not implement:

- Torch compatibility.
- Autograd.
- Neural-network modules.
- Training loops.
- Diffusers support.
- Safetensors or model loading.
- Tokenizers.
- GPU runtime design.
- A complete SciPy replacement.


## Functional Requirements

| ID | Requirement | Priority |
| --- | --- | --- |
| FR-001 | Provide a Fortran 2018 build and test surface with fpm metadata, Makefile fallback, source/test/example/bench/python layout, and local `gfortran` validation. | Must |
| FR-002 | Provide status-based library error handling for invalid input, allocation failure, overflow, unsupported dtype, and unsupported behavior. | Must |
| FR-003 | Represent shape metadata explicitly with non-negative `integer(int64)` dimensions, scalar/empty behavior, and overflow-checked element counts. | Must |
| FR-004 | Represent signed element strides, offset, C-contiguity, Fortran-contiguity, and layout metadata explicitly. | Must |
| FR-005 | Implement the initial `ndarray_r64` descriptor with rank, shape, strides, offset, ownership, contiguity, and backing storage. | Must |
| FR-006 | Implement initial constructors and copy/data-movement operations with clear ownership and NumPy-compatible behavior. | Must |
| FR-007 | Implement NumPy-compatible broadcasting with trailing-dimension negotiation and zero-stride broadcast dimensions. | Must |
| FR-008 | Implement initial `r64` elementwise kernels with correct strided fallbacks before optimized fast paths. | Must |
| FR-009 | Implement reductions with NumPy-compatible 0-based axis semantics, `keepdims`, invalid-axis handling, and documented empty behavior. | Must |
| FR-010 | Implement view-like reshape, transpose, and slicing behavior without hidden copies. | Must |
| FR-011 | Implement an explicit dtype table and tested promotion rules for the supported dtype subset. | Should |
| FR-012 | Phase in indexing, sorting, searching, and selection with documented copy-vs-view behavior. | Should |
| FR-013 | Phase in linear algebra, random generation, and numerical utilities behind clear backend modules. | Should |
| FR-014 | Design a stable C ABI and Python compatibility surface without leaking compiler-specific Fortran internals. | Should |
| FR-015 | Add benchmark and coverage infrastructure so performance and completeness claims are evidence-backed. | Should |

### FR-001: Project Toolchain

The project must provide a build and test surface for Fortran development.

Acceptance criteria:

- `fpm.toml` exists for the Fortran package path.
- A plain `Makefile` fallback exists for machines without `fpm`.
- Source, tests, examples, benchmarks, and Python compatibility scaffolding are
  laid out intentionally.
- Local test commands run with `gfortran`.
- Optional Python differential tests skip cleanly when NumPy is unavailable.

### FR-002: Status And Error Model

Library code must report expected invalid input and allocation failures without
casually terminating the process.

Acceptance criteria:

- A `fenum_status` type or equivalent status surface exists.
- Invalid shape, invalid axis, allocation failure, overflow, unsupported dtype,
  and unsupported behavior are representable.
- Tests and examples may use `error stop`; core library routines should not use
  `error stop` for user input errors.

### FR-003: Shape Metadata

Fenum must represent shape metadata explicitly and safely.

Acceptance criteria:

- Shape values use `integer(int64)`.
- Shape entries are non-negative.
- Scalar arrays and empty arrays have explicit behavior.
- Element-count computation detects overflow.
- Shape tests cover scalar, empty, singleton, and multidimensional cases.

### FR-004: Stride And Contiguity Metadata

Fenum must represent stride and layout metadata explicitly.

Acceptance criteria:

- Strides use signed `integer(int64)` values measured in elements.
- Byte strides, when needed, are named distinctly with `_bytes`.
- C-contiguous and Fortran-contiguous layouts can be computed.
- Contiguity flags are recomputed after shape or stride changes.
- Negative-stride representation is planned before slicing work begins.

### FR-005: Initial `r64` Ndarray Descriptor

Fenum must provide a first concrete ndarray descriptor for `real(real64)`.

Acceptance criteria:

- `ndarray_r64` records rank, shape, strides, offset, ownership, contiguity,
  and backing storage.
- The descriptor distinguishes owned arrays from views or borrowed storage.
- Descriptor-only tests pass before elementwise math is implemented.
- Public NumPy-facing axes are 0-based; internal Fortran dimension indices are
  named distinctly when converted.

### FR-006: Constructors And Basic Data Movement

Fenum must construct and copy supported arrays with clear ownership behavior.

Acceptance criteria:

- Initial constructors include `empty_r64`, `zeros_r64`, `ones_r64`,
  `full_r64`, `arange_r64`, and `linspace_r64`.
- `copy_r64`, `asarray_r64`, and `ascontiguousarray_r64` behavior is explicit.
- Constructor behavior is compared against NumPy for supported cases.
- Hidden copies are not allowed in view-like operations.

### FR-007: Broadcasting

Fenum must implement NumPy-compatible broadcasting for supported operations.

Acceptance criteria:

- Broadcast shape negotiation compares trailing dimensions.
- Dimensions match when equal or when either dimension is `1`.
- Broadcasted dimensions use zero strides instead of materialized copies.
- Incompatible shapes return a clear status.
- Broadcast tests compare against NumPy.

### FR-008: Elementwise Kernels

Fenum must implement initial elementwise operations for `r64`.

Acceptance criteria:

- Binary operations include add, subtract, multiply, and divide.
- Unary operations include at least negate, abs, exp, log, sqrt, sin, and cos.
- Comparison kernels are planned and phased.
- Correct strided fallback paths exist before optimized contiguous fast paths
  are trusted.
- Scalar-array operations do not allocate pretend scalar arrays.

### FR-009: Reductions And Axis Semantics

Fenum must implement reductions with NumPy-compatible axis behavior.

Acceptance criteria:

- Initial reductions include `sum_r64`, `prod_r64`, `min_r64`, `max_r64`, and
  `mean_r64`.
- Boolean reductions include `all_bool` and `any_bool` when boolean dtype
  support exists.
- `keepdims` behavior is supported for phased reductions.
- Invalid axes report the user-facing 0-based axis.
- Empty-reduction behavior is documented and tested.

### FR-010: Views, Reshape, Transpose, And Slicing

Fenum must support view-like ndarray behavior rather than only contiguous
buffers.

Acceptance criteria:

- `reshape_r64`, `ravel_r64`, `flatten_r64`, `transpose_r64`, `swapaxes_r64`,
  `squeeze_r64`, and `expand_dims_r64` are phased explicitly.
- Basic slice descriptors are designed before slice implementation.
- Slice-to-view behavior does not copy unless NumPy would require a copy or the
  Fenum API documents the copy.
- Negative-stride views are represented correctly.
- View ownership and backing lifetime behavior is explicit.

### FR-011: Dtype System And Promotion

Fenum must move beyond `r64` through an explicit dtype system.

Acceptance criteria:

- Dtype IDs and metadata are table-driven.
- Supported dtype rollout begins with `r32`, `r64`, `i32`, `i64`, and boolean.
- Complex dtype support is planned separately.
- Promotion rules for supported dtype pairs are tested against NumPy.
- Unsupported dtypes fail clearly.

### FR-012: Indexing, Sorting, Searching, And Selection

Fenum must phase in practical ndarray non-math operations.

Acceptance criteria:

- Integer indexing policy is explicit.
- Boolean mask strategy is explicit.
- Initial selection includes a `where` subset and `take` subset.
- Concatenation and stacking are phased.
- Sorting/searching subsets are tested with repeated values, empty arrays, and
  axis cases.
- Copy-vs-view behavior is documented for every indexing mode.

### FR-013: Linear Algebra, Random, And Numerical Utilities

Fenum must cover core numerical operations expected by NumPy users.

Acceptance criteria:

- `matmul`, `dot`, and `outer` are implemented or phased.
- BLAS/LAPACK wrappers are isolated behind Fenum modules.
- Matrix/vector norm subset is planned.
- Random generator design is documented.
- Uniform and normal distributions are planned or implemented.
- FFT strategy is documented before implementation.

### FR-014: C ABI And Python Compatibility Surface

Fenum must eventually expose a stable boundary without leaking Fortran
compiler-specific internals.

Acceptance criteria:

- C ABI descriptor and ownership strategy are documented before Python binding
  implementation.
- Python package skeleton is phased after the Fortran core is stable enough.
- Python-level constructors and basic operations compare against NumPy.
- Ownership and destruction are tested from the interop boundary.

### FR-015: Performance And Completeness

Fenum must become faster without sacrificing correctness or readability.

Acceptance criteria:

- Benchmark suite covers contiguous, strided, and broadcasted cases.
- Performance claims are tied to benchmark evidence.
- Fast paths do not replace correctness paths.
- A NumPy coverage matrix exists.
- Unsupported NumPy features are documented.


## First Vertical Slice

The first end-to-end compatibility slice should be:

```text
a = zeros([2, 3])
b = full([3], 2.0)
c = a + b
d = reshape(c, [3, 2])
e = sum(d, axis0=1)
```

This slice exercises:

- Constructors.
- Shape metadata.
- Broadcasting.
- Elementwise math.
- Reshape.
- Axis-based reduction.
- NumPy compatibility testing.


## Compatibility Requirements

- NumPy is the oracle for public behavior.
- Tests should compare Fenum against NumPy for every supported public behavior
  where practical.
- Intentional NumPy departures must include the NumPy behavior, the Fenum
  behavior, the reason, and tests that lock the decision.
- The first compatibility tier may target the Python Array API-style subset,
  but the project identity remains NumPy-compatible ndarray behavior.


## Fortran Requirements

- Use Fortran 2018.
- Use `implicit none`.
- Use explicit kinds.
- Keep modules private by default.
- Use `only:` lists on imports.
- Preserve the naming, module, dtype, axis, and stride conventions in
  `STYLE_GUIDE.md`.
- Avoid vague modules such as `utils`, `helpers`, `common`, or `misc`.
- Keep library error handling status-based.


## Review Requirements

Generated plans, tasks, and implementations should be rejected when:

- The scope drifts beyond NumPy.
- ndarray metadata is vague.
- dtype promotion is hand-waved.
- view/copy behavior is not explicit.
- tests do not compare against NumPy where public behavior is involved.
- Fortran style rules are ignored.
- work packages are too large to review confidently.
- fast paths appear before correct strided fallbacks.


## Open Questions For Planning

- What is the first concrete ownership model for views in Fortran?
- Should the initial descriptor use allocatable storage only, pointer storage,
  or a split owned/buffer handle representation?
- How should fpm and Makefile builds share source lists without drift?
- What is the minimum Python differential harness before Python bindings exist?
- Which dtype promotion subset should be implemented first after `r64`?
