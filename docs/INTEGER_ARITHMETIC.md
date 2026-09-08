# Integer arithmetic

Int32 and int64 support a bounded binary arithmetic surface through `frumpy`:

| Inputs | Operations | Result |
| --- | --- | --- |
| Two `ndarray_i32` | `add_i32`, `subtract_i32`, `multiply_i32` | `ndarray_i32` |
| Two `ndarray_i64` | `add_i64`, `subtract_i64`, `multiply_i64` | `ndarray_i64` |
| Two `ndarray_i32` | `divide_i32` | `ndarray_r64` |
| Two `ndarray_i64` | `divide_i64` | `ndarray_r64` |

All eight functions accept `(lhs, rhs, status)`, with optional output status.
Inputs can be created with `owned_descriptor_i32` or `owned_descriptor_i64`,
filled through `data`, and viewed with the corresponding `view_descriptor_*`.
For example:

```fortran
type(ndarray_i64) :: lhs, rhs, product
type(ndarray_r64) :: quotient
type(frumpy_status) :: status

lhs = owned_descriptor_i64([3_int64])
lhs%data = [2_int64, 4_int64, 8_int64]
rhs = owned_descriptor_i64([integer(int64) ::])
rhs%data = 3_int64
product = multiply_i64(lhs, rhs, status)
quotient = divide_i64(lhs, rhs, status)
```

## Shape and storage

The existing metadata broadcast planner handles trailing-dimension broadcasting.
Scalar and empty arrays, C/F-order layouts, transposes, reversed and stepped
views, and zero strides are supported. Each result owns independent, managed
C-order storage and survives release of its inputs. Kernels read the original
input storage through its strides; they do not materialize input copies.

## Overflow and true division

Add, subtract, and multiply follow NumPy 2.4.6 fixed-width array arithmetic:
results wrap modulo 2**32 or 2**64 and are interpreted as signed integers.
For example, int32 maximum plus one produces int32 minimum, and int64 minimum
times negative one remains int64 minimum. Wrapping leaves Frumpy status OK.

Ordinary signed Fortran overflow is not used. Int32 operations widen to int64
before reconstructing the signed low 32 bits. Int64 addition/subtraction use
bounded half-word sums; multiplication accumulates base-2**16 digits. These
intermediates remain representable without a 128-bit integer dependency or
compiler wraparound flags. The signed bit interpretation assumes the
two's-complement platforms covered by the compiler matrix.

`divide_*` means NumPy true division. Each operand is converted to real64 before
division; int64 values beyond float64's exact integer range may round at that
conversion, matching the tested NumPy behavior. This conversion is part of the
arithmetic operation and does not use Frumpy's stricter scalar casting API.
It does not perform truncating integer division, floor division, or a remainder
operation.

With the tested IEEE settings, zero divided by zero gives NaN; nonzero values
divided by zero give signed infinity; and zero divided by a negative value gives
negative zero. These events leave Frumpy status OK. NumPy's warnings and `seterr`
configuration do not have a Frumpy equivalent. Floating-point traps and fast-math
are outside this tested numerical contract.

The dtype-pair promotion table describes common dtypes, not every operation's
output dtype: integer true division produces float64 even though
`promote_dtypes(i32, i32)` returns i32. Mixed-dtype execution is available through the separate
[mixed arithmetic](MIXED_ARITHMETIC.md) subroutine API. This slice also does not add integer unary functions, reductions,
convenience constructors, or high-level view helpers.

## Failures

Missing input storage returns `FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR`. Malformed
metadata, inaccessible offsets/strides, and incompatible broadcast shapes return
`FRUMPY_STATUS_INVALID_SHAPE`. Explicit allocation failures have
`FRUMPY_STATUS_ALLOCATION_FAILED` paths, subject to the compiler allocation limits
in [storage lifetime](STORAGE_LIFETIME.md). Failed calls return a descriptor
without storage, including when status is omitted. Metadata overflow is rejected;
modular arithmetic applies only to integer payload values.

## Evidence

`test_numpy_integer_binary` and `test_numpy_integer_incompatible_shapes` add 128
compiled comparisons against NumPy. They cover both dtypes and all four operations,
14 operand/layout cases, and incompatible shapes. Boundary-value cross products
and 4,096 seeded full-range operand pairs per dtype exercise overflow, carries,
large-integer precision, division by zero, and signed zero. Integer test inputs
and outputs use decimal integer serialization, preserving int64 values beyond
2**53 exactly. Arithmetic results are compared exactly, with separate signed-zero
checks for division; NaN payload bits are not specified.

`test/test_elementwise_integer.f90` checks payload widths, owned C-order output,
input preservation, result lifetime, optional status, missing storage, and invalid
metadata. It is included in the normal and GNU memory gates. The GNU-only
`make integer-overflow-test` gate runs integer and mixed invariant programs and
all 1,328 integer/mixed comparisons with `-ftrapv -fsanitize=undefined -fno-sanitize-recover=undefined`.
Select a compiler with `FC=gfortran-13` or `FC=gfortran-14`; the gate isolates its
build products under `build/integer-overflow`.
