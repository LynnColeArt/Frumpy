# Frumpy Coding Standards and Style Guide

Frumpy is a NumPy-compatible numerical array library written in Fortran 2018.

The goal is not to make "Fortran that feels like Python." The goal is to make
the same array semantics NumPy users rely on, implemented with Fortran's
strengths: explicit types, predictable memory, fast loops, and very little
mystery.

Inspired by the GlaMin Fortran style guide:
https://raw.githubusercontent.com/LynnColeArt/glamin/refs/heads/main/STYLE_GUIDE.md


## Core Principles

1. **NumPy compatibility is a contract.** If Frumpy behaves differently from
   NumPy, the difference must be intentional, documented, and tested.
2. **Strong typing always.** No implicit kinds. No precision roulette. No
   hidden integer-width assumptions.
3. **Shape and stride honesty.** Every array descriptor must tell the truth
   about rank, shape, strides, offset, contiguity, and ownership.
4. **Views are not copies.** Slicing, transposing, reshaping, and broadcasting
   should preserve view behavior unless a copy is explicitly required.
5. **Memory order is explicit.** NumPy defaults to C order. Fortran defaults do
   not get to leak through public semantics by accident.
6. **Fast paths are earned, fallbacks are correct.** Contiguous kernels may be
   special, but strided and broadcasted arrays must still work.
7. **Library code does not panic casually.** Use status values or well-defined
   error paths. Reserve `error stop` for tests, examples, and unrecoverable
   executable-level failures.
8. **Tests are compatibility proofs.** A feature is not done until edge cases
   and NumPy differential behavior are covered.


## Module Structure

Every module follows the same shape unless a comment explains the exception.

```fortran
module frumpy_example
  use iso_fortran_env, only: int32, int64, real64
  use frumpy_constants, only: FRUMPY_MAX_RANK
  use frumpy_statuses, only: frumpy_status

  implicit none

  private

  public :: ndarray_r64
  public :: zeros_r64

  integer(int32), parameter :: LOCAL_BLOCK_SIZE = 256_int32

  type :: ndarray_r64
    integer(int32) :: rank = 0_int32
    integer(int64), allocatable :: shape(:)
    integer(int64), allocatable :: strides(:)
    integer(int64) :: offset = 1_int64
    logical :: owns_data = .false.
    logical :: is_c_contiguous = .false.
    logical :: is_f_contiguous = .false.
    real(real64), allocatable :: data(:)
  contains
    procedure :: size => ndarray_r64_size
  end type ndarray_r64

contains

  function zeros_r64(shape, status) result(array)
    integer(int64), intent(in) :: shape(:)
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array

    ! Implementation here.
  end function zeros_r64

end module frumpy_example
```

Required order:

1. `module frumpy_name`
2. `use` statements, with `only:` lists
3. `implicit none`
4. `private`
5. `public :: ...`
6. Module constants
7. Derived types
8. Generic interfaces
9. `contains`
10. Private implementations


## Naming Conventions

Frumpy names should describe array semantics, not vague computation.

Avoid these:

| Weak name | Better Frumpy name |
| --- | --- |
| `process_data` | `apply_strided_binary_kernel_r64` |
| `get_shape` | `copy_shape_vector` |
| `update_array` | `assign_broadcasted_values_r64` |
| `result` | `broadcasted_sum` |
| `tmp` | `contiguous_workspace` |

### Modules

- Use `snake_case`.
- Prefix project modules with `frumpy_`.
- Name the responsibility, not the bucket.

Good:

```fortran
frumpy_ndarray_r64
frumpy_broadcast
frumpy_strides
frumpy_reductions_r64
frumpy_linalg_lapack
```

Bad:

```fortran
frumpy_utils
frumpy_helpers
array_stuff
misc_math
```

### Derived Types

- Use `snake_case`.
- Array descriptor types use dtype suffixes: `ndarray_r64`, `ndarray_i64`.
- Planning and metadata types name the concept: `broadcast_plan`,
  `reduction_plan`, `slice_spec`.
- Status and error types use direct names: `frumpy_status`, `frumpy_error`.

Good:

```fortran
type :: ndarray_r64
type :: array_view_r64
type :: broadcast_plan
type :: strided_loop_plan
```

### Variables

- Use `snake_case`.
- Full words beat abbreviations.
- Booleans should read like a yes/no question.
- Names with units must include units.
- Axis and dimension variables must reveal indexing basis.

Good:

```fortran
integer(int64) :: element_count = 0_int64
integer(int64) :: stride_elements = 0_int64
integer(int64) :: stride_bytes = 0_int64
integer(int32) :: axis0 = 0_int32
integer(int32) :: dim1 = 1_int32
logical :: is_broadcastable = .false.
logical :: owns_data = .false.
```

Bad:

```fortran
integer :: n
integer :: axis
integer :: stride
logical :: ok
```

### Procedures

- Use `snake_case`.
- Concrete dtype implementations end with the dtype suffix.
- Generic public interfaces may use NumPy-like names.
- Predicates start with `is_`, `has_`, or `can_`.

Good:

```fortran
zeros_r64
reshape_r64
sum_axis_r64
is_c_contiguous
can_broadcast_shapes
apply_unary_kernel_r64
```

Public generic interfaces may expose:

```fortran
zeros
ones
arange
reshape
transpose
sum
matmul
```

### Constants

- Use `SCREAMING_SNAKE_CASE`.
- Include units when applicable.
- Prefer project constants over repeated literals.

Good:

```fortran
integer(int32), parameter :: FRUMPY_MAX_RANK = 32_int32
integer(int64), parameter :: BYTE_SIZE_R64 = 8_int64
integer(int32), parameter :: DEFAULT_ALIGNMENT_BYTES = 64_int32
```


## Kind and Dtype Rules

Every numeric declaration must specify kind.

```fortran
integer(int64) :: element_count = 0_int64
real(real64) :: scale = 1.0_real64
complex(real64) :: value = (0.0_real64, 0.0_real64)
```

Never write:

```fortran
integer :: element_count
real :: scale
complex :: value
```

Dtype suffixes:

| Suffix | Meaning |
| --- | --- |
| `_r32` | `real(real32)` |
| `_r64` | `real(real64)` |
| `_i32` | `integer(int32)` |
| `_i64` | `integer(int64)` |
| `_c64` | `complex(real32)` |
| `_c128` | `complex(real64)` |
| `_bool` | logical boolean storage |

Use `integer(int64)` for element counts, shape values, offsets, and strides.
Use `integer(int32)` for rank, axis IDs, dtype IDs, and small enum-like values.


## Array Descriptor Rules

An ndarray descriptor must make these fields explicit:

- `rank`: number of dimensions.
- `shape`: length of each dimension.
- `strides`: signed strides measured in elements.
- `offset`: 1-based offset into the Fortran storage buffer.
- `data`: linear storage buffer or owned backing store.
- `owns_data`: whether finalization may release the buffer.
- `is_c_contiguous`: true when layout is NumPy C-contiguous.
- `is_f_contiguous`: true when layout is Fortran-contiguous.

Shape entries are non-negative. Strides are signed because NumPy views may have
negative strides.

Use names that specify stride units:

```fortran
integer(int64) :: stride_elements = 0_int64
integer(int64) :: python_stride_bytes = 0_int64
```

Do not mix byte strides and element strides under the same name.


## Axes, Dimensions, and Indexing

NumPy-facing APIs use 0-based axes. Internal Fortran helper loops may use
1-based dimensions, but conversion must happen once and be visible in the name.

```fortran
integer(int32) :: axis0 = 0_int32
integer(int32) :: dim1 = axis0 + 1_int32
```

Rules:

- Use `axis0` for a NumPy-compatible axis.
- Use `dim1` for a Fortran dimension index.
- Never use a bare variable named `axis` inside code that crosses the boundary.
- Error messages should report the user-facing `axis0`.


## Memory Order

Public constructors default to NumPy C order unless the name or argument says
otherwise.

Good:

```fortran
array = zeros_r64(shape)
array = zeros_r64(shape, order=C_ORDER)
array = zeros_r64(shape, order=F_ORDER)
```

Rules:

- Do not assume Fortran-contiguous layout just because the implementation is
  Fortran.
- Prefer linear buffers plus explicit strides for ndarray storage.
- Every reshape must preserve view behavior when NumPy would preserve it.
- Every copy must be visible in the procedure name, status, or documentation.
- Contiguity flags must be recomputed after shape or stride changes.


## Broadcasting Rules

Broadcasting follows NumPy:

- Shapes compare from the trailing dimensions.
- Dimensions match when equal or when either side is `1`.
- The result rank is the maximum operand rank.
- Broadcasted dimensions use stride `0`.

Use a `broadcast_plan` before allocating output.

```fortran
type(broadcast_plan) :: plan

plan = create_broadcast_plan(lhs%shape, rhs%shape, status)
if (status%failed) return
```

Do not hide allocations inside shape negotiation. Planning computes metadata;
kernels allocate only when the operation owns a new result.


## Error Handling

Library procedures should not use `error stop` for normal invalid input.

Preferred pattern:

```fortran
type(frumpy_status), intent(out), optional :: status
```

Rules:

- Set status on allocation failure, invalid shape, invalid axis, overflow, and
  unsupported dtype.
- If `status` is absent, use a documented default behavior for public APIs.
- Tests and examples may use `error stop`.
- Internal assertions may use a dedicated invariant helper, but only for states
  that indicate a Frumpy bug rather than user input.

Status names should describe what happened:

```fortran
FRUMPY_STATUS_OK
FRUMPY_STATUS_INVALID_SHAPE
FRUMPY_STATUS_INVALID_AXIS
FRUMPY_STATUS_ALLOC_FAILED
FRUMPY_STATUS_OVERFLOW
FRUMPY_STATUS_UNSUPPORTED_DTYPE
```


## Public API Rules

Public APIs should be small, stable, and NumPy-shaped.

Rules:

- Prefer generic names in the umbrella `frumpy` module.
- Keep dtype-specific procedures available in implementation modules.
- Do not expose internal planning types unless users need them.
- Preserve NumPy argument names where practical: `shape`, `axis`, `dtype`,
  `order`, `keepdims`.
- Any semantic departure from NumPy belongs in compatibility documentation and
  tests.

If a name conflicts with a Fortran intrinsic, the umbrella module may expose a
generic name while implementation code uses a more explicit concrete name.


## Performance Rules

Let Fortran be fast, but do not let cleverness erase correctness.

Preferred order:

1. Correct strided implementation.
2. Contiguous fast path.
3. Dtype-specialized implementation.
4. Benchmarked optimization.

Rules:

- Allocate once, compute many times.
- Keep hot loops simple enough for the compiler to vectorize.
- Prefer contiguous linear loops when `is_c_contiguous` or `is_f_contiguous`
  permits them.
- Keep strided fallbacks tested and maintained.
- Avoid pointer aliasing in kernels unless the aliasing rules are documented.
- Do not copy views just to make a loop easier unless the API promises a copy.
- BLAS and LAPACK wrappers belong in dedicated modules.


## Documentation

Use `!>` comments for module, type, and public procedure documentation.

Comments explain why. Names and code should already explain what.

Good:

```fortran
!> Reshape without copying when the current stride pattern can represent the
!> target shape. Falls back to a copy only when NumPy would require one.
function reshape_r64(array, new_shape, status) result(reshaped)
```

Bad:

```fortran
!> This function reshapes the array.
function reshape_r64(array, new_shape, status) result(reshaped)
```


## Testing Rules

Frumpy tests should prove both Fortran invariants and NumPy compatibility.

Fortran tests cover:

- Allocation and deallocation.
- Shape, stride, offset, and contiguity invariants.
- Broadcasting plans.
- Reductions over every valid axis.
- Empty arrays and singleton dimensions.
- Non-contiguous and negative-stride views.
- Overflow and invalid input status paths.

Python differential tests cover:

- Constructors against NumPy.
- Elementwise arithmetic.
- Broadcasting.
- Reductions.
- Reshape, transpose, and slicing behavior.
- Error cases where NumPy raises.

When a test compares against NumPy, name it that way:

```text
test_numpy_broadcast_add_r64
test_numpy_sum_axis_keepdims_r64
```


## Code Layout

- Use 2 spaces per indentation level.
- Keep lines at or below 100 characters.
- Use lowercase Fortran keywords.
- Put one blank line between procedures.
- Put two blank lines between major sections.
- Use `&` continuation clearly for long calls and generic interfaces.
- Align related declarations when it improves scanning.

Example:

```fortran
type :: strided_loop_plan
  integer(int64) :: element_count = 0_int64
  integer(int64) :: lhs_stride = 0_int64
  integer(int64) :: rhs_stride = 0_int64
  integer(int64) :: out_stride = 0_int64
  logical :: can_use_contiguous_fast_path = .false.
end type strided_loop_plan
```


## Compatibility Documentation

Every intentional NumPy departure must include:

- The NumPy behavior.
- The Frumpy behavior.
- Why Frumpy differs.
- Which tests lock in the decision.

Use this format:

```text
Decision: Frumpy does not support object dtype.
NumPy behavior: object arrays can store arbitrary Python objects.
Frumpy behavior: object dtype is unsupported.
Reason: Frumpy's core is numeric Fortran storage, not Python object ownership.
Tests: test_unsupported_object_dtype_status
```


## Review Checklist

Core Fortran:

- [ ] Every module has `implicit none`.
- [ ] Every module is `private` by default.
- [ ] Every `use` statement has an `only:` list.
- [ ] Every integer and real declaration specifies kind.
- [ ] Every dummy argument declares `intent`.
- [ ] Every allocatable allocation checks or propagates status.
- [ ] Every derived type field is initialized or deliberately allocatable.
- [ ] No vague module names such as `utils`, `helpers`, or `common`.
- [ ] No hidden copies in view-like operations.
- [ ] No bare `axis` variable where 0-based and 1-based indexing can mix.

Array semantics:

- [ ] Shape values are non-negative `integer(int64)`.
- [ ] Strides are signed `integer(int64)` and measured in elements.
- [ ] Byte strides are named with `_bytes`.
- [ ] Contiguity flags are updated after shape or stride changes.
- [ ] Broadcasting uses trailing-dimension NumPy rules.
- [ ] Broadcasted dimensions use zero strides.
- [ ] C-order and F-order behavior is explicit.
- [ ] NumPy departures are documented and tested.

Performance:

- [ ] Correct strided path exists before specialized fast paths.
- [ ] Contiguous fast path does not change semantics.
- [ ] Hot loops avoid unnecessary allocation.
- [ ] Any copy is intentional and discoverable.
- [ ] Benchmarks justify non-obvious optimizations.

Testing:

- [ ] Fortran invariant tests cover descriptor state.
- [ ] Python differential tests compare against NumPy for public behavior.
- [ ] Empty arrays, singleton dimensions, and invalid axes are tested.
- [ ] Negative-stride or reversed views are tested when implemented.
- [ ] Allocation failure and status propagation paths are considered.


## Final Rule

Frumpy should feel boring in the best possible way: precise, fast, predictable,
and compatible enough that a NumPy user only notices when the Fortran engine
quietly does the work well.
