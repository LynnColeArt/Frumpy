# Frumpy Phased Project Plan

Frumpy is a big project on purpose. This plan keeps the ambition visible while
keeping the active scope clean:

> Frumpy is a Fortran 2018 NumPy-compatible array engine.

For now, Frumpy is only about NumPy. Future ML ecosystem work may benefit from
Frumpy, but it should not shape the first implementation. The current job is to
make ndarray semantics correct, readable, tested, and fast.

This is a phase-gated plan, not a date-gated plan. We move forward when the
exit criteria are true.

This plan is also the governing structure for the long-horizon Spec Kitty
mission. Spec Kitty should receive the whole NumPy replacement as one
software-dev mission, then decompose it into phased, dependency-aware work
packages. The mission is large by design; the work packages must still be
small, concrete, testable, and reviewable.


## Planning Anchors

These external contracts shape the plan:

- NumPy ndarray semantics: shape, dtype, indexing, slicing, shared data, and
  views are foundational.
  https://numpy.org/doc/stable/reference/arrays.ndarray.html
- NumPy broadcasting: trailing dimensions are compared, dimensions match when
  equal or one, and broadcasting should avoid real copies.
  https://numpy.org/doc/stable/user/basics.broadcasting.html
- NumPy array objects: the public surface includes creation, manipulation,
  indexing, calculation, reductions, sorting, searching, and linear algebra.
  https://numpy.org/doc/stable/reference/arrays.html
- Python Array API standard: useful as an early portable subset before chasing
  every historical NumPy edge case.
  https://numpy.org/doc/stable/reference/array_api.html
- fpm: the natural Fortran package metadata/build path, even if we also keep a
  plain Makefile for local convenience.
  https://fortran-lang.github.io/fpm/


## Scope Boundaries

Frumpy owns:

- NumPy-shaped ndarray semantics.
- Shape, stride, dtype, memory, view, and copy behavior.
- NumPy-compatible creation and manipulation functions.
- Elementwise arithmetic.
- Reductions and axis behavior.
- Sorting, searching, and indexing behavior when phased in.
- CPU reference kernels.
- BLAS/LAPACK-backed dense linear algebra.
- A stable C ABI and eventual Python package surface.
- NumPy differential tests for every supported public behavior.

Frumpy does not own right now:

- Torch compatibility.
- Autograd.
- Neural-network modules.
- Training loops.
- Diffusers support.
- Safetensors or model loading.
- Tokenizers.
- GPU runtime design.
- A complete SciPy replacement.

Future projects may sit on top of Frumpy. They do not belong inside the current
Frumpy scope.


## Compatibility Tiers

### Tier 1: Array API Core

The first compatibility tier targets the portable Array API-style subset:

- Creation functions.
- Elementwise arithmetic.
- Basic dtype handling.
- Shape manipulation.
- Reductions.
- Linear algebra basics.

This gives Frumpy a smaller, modern contract before historical NumPy behavior
starts creeping in through the windows.

### Tier 2: Core NumPy ndarray Behavior

The second tier targets the behavior that makes NumPy feel like NumPy:

- Views and copies.
- Slicing.
- Negative strides.
- Broadcasting edge cases.
- Axis behavior.
- C-order and Fortran-order semantics.
- Dtype promotion and casting.
- Error behavior.

### Tier 3: Broader NumPy Surface

The third tier expands beyond the ndarray core:

- More creation routines.
- More mathematical functions.
- Sorting and searching.
- Random generation.
- Linear algebra coverage.
- FFT strategy.
- Serialization and text/binary IO strategy.


## Phase 0: Identity, Standards, and Architecture

Goal:

Define what Frumpy is before code makes accidental promises.

Deliverables:

- Project README.
- Style guide.
- Phased project plan.
- Compatibility policy.
- Initial architecture sketch.

Exit criteria:

- The project states why it exists.
- The project states what it will not do yet.
- NumPy-only scope is explicit.
- Array semantics are named precisely enough to guide implementation.
- A contributor can tell where the first code should go.

Status:

- In progress.


## Phase 1: Toolchain and Test Harness

Goal:

Make the project buildable, testable, and boring to run.

Deliverables:

- `fpm.toml`.
- `Makefile` fallback for machines without `fpm`.
- `src/`, `test/`, `examples/`, `bench/`, and `python/` directory layout.
- Compiler warning profile for `gfortran`.
- Minimal Fortran test runner.
- Python differential-test harness that can compare generated outputs against
  NumPy when Python dependencies are available.
- CI plan, even if CI is not wired immediately.

Exit criteria:

- `make test` works locally with `gfortran`.
- `fpm test` works when `fpm` is installed.
- One trivial Fortran test runs.
- One optional Python compatibility smoke test runs or skips cleanly.

Key risks:

- Fortran test ecosystem friction.
- `fpm` availability.
- Python package tooling arriving too early and distracting from the core.


## Phase 2: Core Descriptor and Metadata

Goal:

Build the ndarray descriptor before building operations.

Deliverables:

- `frumpy_statuses` module.
- `frumpy_constants` module.
- `frumpy_dtypes` module with initial dtype IDs.
- `frumpy_shape` module.
- `frumpy_strides` module.
- First concrete array type: `ndarray_r64`.
- Constructors for descriptor-only and owned-storage arrays.
- Contiguity detection for C order and Fortran order.
- Overflow checks for element-count computation.

Exit criteria:

- Shape values are `integer(int64)` and non-negative.
- Strides are signed `integer(int64)` and measured in elements.
- C-contiguous and F-contiguous layouts can be computed and tested.
- Empty arrays and scalar arrays have explicit behavior.
- Descriptor tests pass without any elementwise math existing yet.

Key risks:

- Getting offset semantics wrong at the beginning.
- Confusing NumPy 0-based axes with Fortran 1-based dimensions.
- Letting Fortran memory order leak into public behavior.


## Phase 3: Constructors and Basic Data Movement

Goal:

Create arrays and move data in ways that make later kernels possible.

Deliverables:

- `empty_r64`.
- `zeros_r64`.
- `ones_r64`.
- `full_r64`.
- `arange_r64`.
- `linspace_r64`.
- `copy_r64`.
- `asarray_r64`.
- `ascontiguousarray_r64`.
- Basic scalar get/set helpers for tests.
- First printing/debug representation for developer use.

Exit criteria:

- Constructors match NumPy shape and fill behavior for supported dtype.
- Copies are explicit.
- Basic owned arrays can be inspected in tests.
- Allocation failures propagate through `frumpy_status`.

Key risks:

- Hidden copies becoming normal.
- Debug helpers accidentally becoming public API.


## Phase 4: Broadcasting and Elementwise Kernels

Goal:

Make Frumpy feel like an array library.

Deliverables:

- `broadcast_plan`.
- Shape negotiation for binary operations.
- Zero-stride handling for broadcast dimensions.
- Elementwise add, subtract, multiply, divide for `r64`.
- Unary kernels such as negate, abs, exp, log, sqrt, sin, cos.
- Comparison kernels.
- Scalar-array operation support.
- Contiguous fast paths plus strided fallback paths.

Exit criteria:

- Broadcast results match NumPy for supported shapes.
- Incompatible shapes return the correct status.
- Strided fallback is tested before fast paths are trusted.
- Scalar broadcasting does not allocate pretend scalar arrays.

Key risks:

- Off-by-one stride iteration bugs.
- Treating broadcast as materialization.
- Fast path diverging from fallback behavior.


## Phase 5: Reductions and Axis Semantics

Goal:

Lock down `axis0`, `dim1`, and `keepdims` behavior before the API grows.

Deliverables:

- `sum_r64`.
- `prod_r64`.
- `min_r64`.
- `max_r64`.
- `mean_r64`.
- `all_bool`.
- `any_bool`.
- `argmin_i64` and `argmax_i64` planning, if not full implementation.
- `axis0` validation helpers.
- `keepdims` support.
- Empty-reduction behavior documented for supported reductions.

Exit criteria:

- Axis behavior matches NumPy for supported reductions.
- Invalid axes report user-facing 0-based axis values.
- Reductions over scalar, empty, singleton, and multidimensional arrays are
  covered by tests.

Key risks:

- Silent mismatch between Fortran dimension order and NumPy axis behavior.
- Empty-array semantics being patched piecemeal later.


## Phase 6: Views, Reshape, Transpose, and Slicing

Goal:

Make ndarray behavior real rather than just contiguous buffers with math.

Deliverables:

- `reshape_r64`.
- `ravel_r64`.
- `flatten_r64`.
- `transpose_r64`.
- `swapaxes_r64`.
- `squeeze_r64`.
- `expand_dims_r64`.
- Basic slice descriptors.
- Slice-to-view implementation.
- Negative-stride view support.
- View ownership/base lifetime design.

Exit criteria:

- View operations do not copy unless documented.
- Negative strides are represented correctly.
- Mutating a view mutates shared backing storage when mutation APIs exist.
- Non-contiguous arrays still work with elementwise and reduction operations.

Key risks:

- Lifetime/ownership design becoming unsafe.
- Copy-vs-view behavior drifting from NumPy.
- Negative strides exposing offset bugs.


## Phase 7: Dtype System and Promotion

Goal:

Move beyond `r64` without creating unmaintainable generic soup.

Deliverables:

- Dtype table.
- Supported dtype IDs and metadata.
- Concrete arrays for `r32`, `r64`, `i32`, `i64`, and boolean.
- Initial complex dtype plan.
- Promotion rules for supported dtype pairs.
- Cast/copy kernels.
- Python scalar interaction policy for the Python layer.

Exit criteria:

- Dtype promotion is table-driven and tested.
- Unsupported dtypes fail clearly.
- No duplicate hand-maintained promotion logic appears in random modules.
- Public docs state which NumPy dtypes are supported.

Key risks:

- NumPy promotion rules are subtle and changed significantly around NumPy 2.x.
- Fortran generics can get awkward if we chase too many dtypes too early.


## Phase 8: Indexing, Sorting, Searching, and Selection

Goal:

Cover the non-math operations that make ndarray code practical.

Deliverables:

- Integer indexing policy.
- Boolean mask strategy.
- `where` subset.
- `take` subset.
- `concatenate`.
- `stack`.
- `sort` subset.
- `argsort` subset.
- `nonzero` plan.

Exit criteria:

- Basic indexing and selection behavior matches NumPy for supported dtypes.
- Copy-vs-view behavior is documented for every indexing mode.
- Sorting/searching tests include repeated values, empty arrays, and axis cases.

Key risks:

- Advanced indexing can explode the scope if introduced all at once.
- Boolean masks and integer arrays have copy semantics that must be explicit.


## Phase 9: Linear Algebra, Random, and Numerical Utilities

Goal:

Cover the numerical operations needed by serious NumPy users.

Deliverables:

- `matmul`.
- `dot`.
- `outer`.
- Matrix/vector norm subset.
- BLAS/LAPACK backend module.
- Random generator design.
- Normal and uniform random distributions.
- FFT strategy document.

Exit criteria:

- BLAS/LAPACK wrappers are isolated behind Frumpy modules.
- `matmul` handles vector/matrix rank behavior for supported dtypes.
- Random behavior is reproducible and documented.
- Numerical tests include tolerances and dtype-specific expectations.

Key risks:

- Platform BLAS variability.
- Reproducibility expectations.
- Expanding into SciPy territory too soon.


## Phase 10: C ABI, Python Package, and Differential Testing

Goal:

Expose Frumpy as a real NumPy-shaped library without leaking Fortran internals.

Deliverables:

- Stable C ABI for array descriptors and owned buffers.
- Python extension package skeleton.
- Python-level `frumpy.ndarray` wrapper.
- Python constructors: `array`, `zeros`, `ones`, `arange`.
- Python elementwise and reduction calls.
- NumPy differential tests in CI/local test harness.
- Wheel/build strategy document.

Exit criteria:

- A Python user can create a Frumpy array and run a small operation.
- Differential tests compare Frumpy and NumPy for the supported subset.
- The C ABI does not expose compiler-specific Fortran layout.
- Ownership and destruction are tested from Python.

Key risks:

- Python interop swallowing the core project.
- ABI design coupling too tightly to the first Fortran descriptor.
- Packaging complexity.


## Phase 11: Performance and Completeness

Goal:

Make correct NumPy-compatible code fast without making it unreadable.

Deliverables:

- Benchmark suite.
- Contiguous vs strided benchmark cases.
- BLAS backend comparison.
- Allocation profiling.
- OpenMP strategy.
- SIMD/vectorization notes.
- NumPy coverage matrix.
- Documented unsupported NumPy features.

Exit criteria:

- Performance claims are benchmarked.
- Regressions can be caught.
- Fast paths do not replace correctness paths.
- The supported NumPy surface is discoverable.
- Unsupported NumPy features fail clearly or are documented as absent.

Key risks:

- Premature optimization.
- Coverage chasing before the core is stable.
- Performance improvements that break view or broadcast semantics.


## First Vertical Slice

The first satisfying demo should be small:

```text
a = zeros([2, 3])
b = full([3], 2.0)
c = a + b
d = reshape(c, [3, 2])
e = sum(d, axis0=1)
```

Fortran should execute it. Python differential tests should prove the result
matches NumPy for the supported subset.

This slice exercises:

- Constructors.
- Shape metadata.
- Broadcasting.
- Elementwise math.
- Reshape.
- Axis-based reduction.
- NumPy compatibility testing.


## North-Star NumPy Demo

The bigger demo, later:

```text
Create arrays from Python through Frumpy.
Run NumPy-style broadcasting, slicing, dtype promotion, reductions, and matmul.
Compare the full result set against NumPy.
Show which operations are implemented and which are not.
```

This is the point where Frumpy starts feeling like a credible NumPy replacement
instead of a Fortran array experiment.


## Future Context, Not Current Scope

Frumpy may later become useful to ML runtimes, Torch-compatible systems, or
Diffusers-style projects. That is a reason to care about correctness and
interoperability, not a reason to put those systems in the current scope.

The current scope is NumPy.


## Recurring Review Questions

At every phase boundary, ask:

- Did we preserve NumPy-facing semantics?
- Did we hide any copies?
- Did we make ownership less clear?
- Did we add a fast path without testing the fallback?
- Did we document intentional NumPy differences?
- Did we keep Fortran readable?
- Did we accidentally design for a future ML runtime instead of NumPy?


## Immediate Next Steps

1. Scaffold the Fortran package and local build/test commands.
2. Create the status, constants, shape, and stride modules.
3. Implement `ndarray_r64` descriptor tests before math kernels.
4. Add the first NumPy differential smoke test.
5. Build the first vertical slice one operation at a time.


## Spec Kitty Handoff Model

Mission type:

- `software-dev`

Mission scope:

- The full Frumpy NumPy-compatible array engine.

Mission constraint:

- The active product scope remains NumPy only.

Expected decomposition:

- Preserve the project phases in this plan.
- Convert each phase into dependency-aware WPs.
- Keep each WP independently reviewable.
- Prefer tests and compatibility fixtures before implementation.
- Treat NumPy as the oracle for public behavior.
- Reject accidental Torch, Diffusers, autograd, model-loading, or GPU runtime
  work unless the project scope explicitly changes.

Reviewer posture:

- Review generated specs, plans, tasks, and WPs against this file,
  [README.md](README.md), [STYLE_GUIDE.md](STYLE_GUIDE.md), and
  [AGENTS.md](AGENTS.md).
