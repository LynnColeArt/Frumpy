# Mixed-dtype arithmetic

The `frumpy` module exposes four arithmetic subroutines:

```fortran
call add(lhs, rhs, result, status)
call subtract(lhs, rhs, result, status)
call multiply(lhs, rhs, result, status)
call divide(lhs, rhs, result, status)
```

Inputs can independently be `ndarray_bool`, `ndarray_i32`, `ndarray_i64`,
`ndarray_r32`, or `ndarray_r64`. Same-dtype pairs work too. `status` is optional.
The existing dtype-specific functions, such as `add_i64` and `divide_r32`, remain
available with their existing signatures.

## Choosing the result type

Declare `result` with the operation's output descriptor type. An initially empty
descriptor is sufficient; if the variable is allocatable, allocate the descriptor
itself before calling. A result with existing data is also accepted.

```fortran
use iso_fortran_env, only: int32, int64, real32
use frumpy, only: ndarray_i32, ndarray_r32, ndarray_r64, &
  owned_descriptor_i32, owned_descriptor_r32, add, frumpy_status

type(ndarray_i32) :: integers
type(ndarray_r32) :: singles
type(ndarray_r64) :: result
type(frumpy_status) :: status

integers = owned_descriptor_i32([3_int64])
integers%data = [1_int32, 2_int32, 3_int32]
singles = owned_descriptor_r32([integer(int64) ::])
singles%data = 0.5_real32
call add(integers, singles, result, status)
! result contains float64 values [1.5, 2.5, 3.5].
```

`binary_result_dtype(lhs_dtype_id, rhs_dtype_id, operation, status)` returns the
required dtype ID. `operation` is one of the lowercase strings `add`, `subtract`,
`multiply`, or `divide`. The query uses the existing
[promotion table](DTYPE_PROMOTION.md), with two operation-specific rules:

- True division of boolean/integer-only operands produces float64.
- Boolean-minus-boolean is unsupported, matching NumPy's TypeError.

Boolean addition is logical OR; boolean multiplication is logical AND. Boolean
payload bytes are interpreted by truth value (zero is false, nonzero is true),
and boolean outputs are normalized to 0 or 1.

For other pairs, the common dtype applies. For example, bool with float32 stays
float32, int32 with int64 becomes int64, and either integer width with float32
becomes float64. The query returns `FRUMPY_DTYPE_UNSUPPORTED` on failure; unknown
dtype IDs report `FRUMPY_STATUS_UNSUPPORTED_DTYPE`, while unknown operation names
and boolean subtraction report `FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR`.

## Values and storage

Each element is converted to the resolved computation dtype before arithmetic.
Integer results use the existing explicit modular wrapping; real results use
real32 or real64 arithmetic. Conversion to float64 can round large int64 values,
as NumPy does. This arithmetic conversion does not invoke the stricter exact
scalar casting API. IEEE NaNs, infinities, division by zero and signed zeros follow
the tested compiler settings; there is no NumPy warning or `seterr` channel.
Fast-math and floating-point traps are outside this numerical contract.

The existing broadcast planner handles scalars, empty arrays, trailing-dimension
broadcasting, C/F-order inputs, transposes, reversed/stepped views and zero strides.
Inputs are read directly through their original storage and strides. The kernel
allocates one C-order output payload and temporary iteration/descriptor metadata;
it does not materialize promoted copies of either input or copy the completed
payload again when installing the result.

On success, `result` owns independent managed storage. Replacing an existing
result leaves aliases of its previous storage intact. Input releases do not
invalidate the result. Pass `result` as a different descriptor variable from
`lhs` and `rhs`; passing the same variable as an input and output is not supported.
Distinct descriptor variables may share backing storage: installation happens
only after all reads finish. General Fortran descriptor-container copying remains
subject to the [storage lifetime restrictions](STORAGE_LIFETIME.md).

## Recoverable failures

All reported failures preserve the previous result, including when status is
omitted. Explicit allocation failures propagate through status-bearing paths;
compiler-generated allocation recovery remains limited as documented in the
storage lifetime contract.

| Failure | Status |
| --- | --- |
| Unsupported input/output type, forged input dtype metadata, or incorrect result descriptor type | `FRUMPY_STATUS_UNSUPPORTED_DTYPE` |
| Missing input storage or boolean subtraction | `FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR` |
| Invalid shape/rank/strides/offset, inaccessible storage, or incompatible broadcasting | `FRUMPY_STATUS_INVALID_SHAPE` |
| Explicit allocation failure | `FRUMPY_STATUS_ALLOCATION_FAILED` |

The actual Fortran descriptor type determines dtype; an operand's `dtype_id`
metadata must agree with it. Raw Fortran scalars and raw arrays are not accepted
as operands: use rank-zero or shaped descriptors. Python weak-scalar promotion,
user-selected casting modes, `where` masks, mixed reductions, and in-place
arithmetic are outside this API.

## Validation

The 1,200 `test_numpy_mixed_*` cases compare all 25 ordered dtype pairs and four
operations against NumPy 2.4.6. They exercise 11 value/layout cases per pair plus
incompatible shapes, including 512 seeded bit patterns per input dtype, integer
boundaries, infinities/NaNs, signed zero and empty arrays. The bridge emits the
actual result dtype and exact integer values. Results are compared exactly,
with separate sign-bit checks for non-NaN floating results; NaN payload bits are
not specified. Exact agreement on this corpus is not a guarantee for all compiler
flags, platforms or floating-point environments.

`test/test_arithmetic.f90` covers typed output rejection, malformed operands,
result replacement and preservation, lifetime, boolean normalization, optional
status, and dtype queries. The normal compiler matrix and GNU memory gates
include it. `make integer-overflow-test` now runs both integer/mixed invariant
programs and all 1,328 integer/mixed comparisons under signed-overflow traps and
undefined-behavior sanitization.
