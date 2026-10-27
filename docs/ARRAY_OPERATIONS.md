# Array casts, comparisons, reductions and assignment

## Array astype

`call astype(source, result, casting, status)` accepts any registered descriptor.
The destination's concrete type selects the output dtype, as with mixed arithmetic.
It must be an existing concrete descriptor object (its payload may be absent).
Default casting is UNSAFE, matching NumPy astype. NO/EQUIV/SAFE/SAME_KIND/UNSAFE
use the existing tested dtype policy. Reported failures preserve the previous
result, including without status. Success installs an independent C-order copy.
Distinct source/result descriptors may share backing; do not pass the same actual
variable to both arguments.

Unlike the existing exact scalar cast helpers, array conversion permits rounding
and, when float-to-integer is allowed, truncates toward zero. Integer narrowing
keeps low bits with explicit modular arithmetic. Float narrowing follows IEEE
rounding/overflow. Boolean conversion treats any nonzero value, including NaN, as
true and writes normalized 0/1 bytes. Int64-to-float conversions round directly
to the target kind, without an intermediate narrower integer or double rounding
through float64 when targeting float32.

Intentional boundary: nonfinite float-to-integer values return
UNSUPPORTED_BEHAVIOR; truncated values outside the target integer range return
OVERFLOW. NumPy unsafe conversion can emit an implementation-dependent integer
and warning here. Frumpy refuses that dependence. Dtype-policy SAFE does not
mean value-exact: int64-to-float64 may round, as in NumPy's dtype-level policy.
The strict scalar cast APIs retain their prior contract.

## Comparisons and boolean operations

`equal`, `not_equal`, `less`, `less_equal`, `greater`, `greater_equal` return
independent normalized boolean arrays, accepting all 25 registered dtype pairs
with trailing-dimension broadcasting. Integer pairs compare in int64 without
floating-point rounding. Integer/float pairs follow the registered promotion
semantics. NaNs are unequal and unordered; signed zeros compare equal.

`logical_and_bool`, `logical_or_bool`, `logical_xor_bool`, `logical_not_bool`
accept boolean descriptors only. Noncanonical nonzero bool bytes are true.
Malformed metadata, dtype mismatch and inaccessible storage are rejected before
payload access. Failed function calls return descriptors without storage.

## Integer and boolean reductions

| Inputs | Operation | Result/accumulator |
| --- | --- | --- |
| int32/int64 | sum, prod | int64, modular overflow |
| int32/int64 | min, max | input dtype |
| int32/int64 | mean | float64 |
| bool | all, any | normalized bool |

Concrete functions are `sum_i32`, `prod_i32`, `min_i32`, `max_i32`, `mean_i32`,
corresponding `_i64` functions, and `all_bool`/`any_bool`. They accept optional
axis0 and keepdims. Absent axis reduces all axes; one positive or negative axis
is supported. Scalar axis 0/-1 is accepted except by mean, matching NumPy.
Outputs are independent C-order descriptors. Empty sum/prod/all/any identities
are 0/1/true/false; empty mean is NaN without a NumPy warning channel. Min/max
reject a zero-length reduction even if the output is also empty.

Integer means convert each input to float64, accumulate sequentially in C logical
order, then divide by the reduction count. This order is deterministic across
layouts representing the same logical values; NumPy may traverse layouts or sum
partials differently. Cancellation-heavy means therefore need not match. The
explicit regression transposes `[[2^63-1,1,-2^63],[-1,2,0]]`: Frumpy gives 0 and
NumPy 2.4.6 gives 1/6. This difference is intentional and tested separately from
ordinary comparisons (rtol=atol=2e-13). No global error bound is claimed.

## Mask extraction and assignment

`mask_select_r64(source, mask, status)` requires a boolean mask of exactly the
source shape, including scalar or empty shapes. It returns an independent
float64 vector in C logical selection order. Prefix masks and arbitrary advanced
index arrays are outside this subset.

`call assign_r64(target, values, status)` broadcasts float64 values to an existing
float64 target descriptor, including a basic slice/view. It never changes target
metadata or allocates replacement target storage. It stages every RHS value
before writing, so distinct descriptors with overlapping backing are supported.
Reported validation/allocation failures leave the target unchanged. Passing the
same actual Fortran variable to both dummies is unsupported; use a distinct shared
descriptor for self-backed assignment.

For deliberately writable views with repeated storage positions (e.g. zero
strides), writes occur in C logical order and the last write wins. There is no
read-only descriptor flag in the native contract. Boolean-mask assignment and
non-float64 assignment remain outside this v0.1 subset.

## Evidence

`test_array_casting`, `test_comparisons`, `test_reductions_discrete` and
`test_indexing_r64` verify ownership, source-release lifetime, failure atomicity,
integer edge values, malformed descriptors and overlapping assignments.
Python tests compare all casting policies/pairs, comparisons, logical operations,
integer/boolean axes and empties, and float64 masking/assignment with NumPy.
The unsafe-cast and accumulation-order departures have explicit separate tests.
GNU memory and integer-overflow gates include these operations.
