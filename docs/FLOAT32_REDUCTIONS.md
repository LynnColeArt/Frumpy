# Float32 reductions

`sum_r32`, `prod_r32`, `mean_r32`, `min_r32`, and `max_r32` accept an
`ndarray_r32` and return an independent, managed, C-order `ndarray_r32`.
Outputs and accumulators remain float32. The concrete interface is:

```fortran
result = sum_r32(source, axis0=axis, keepdims=.true., status=status)
```

All five routines have the same optional `axis0`, `keepdims`, and `status`
arguments. Omitting `axis0` reduces all axes. The all-axis result is a rank-zero
descriptor unless `keepdims` retains the original dimensions as ones. A
single-axis reduction removes that dimension or changes its extent to one.

## Supported behavior

- Positive and negative integer axes, normalized against the source rank.
- C/F-order inputs, transposes, reversed/stepped views, zero strides, singleton
  dimensions, empty arrays, and scalar descriptors. Inputs are read through
  their actual signed element strides; no input values are materialized.
- Independent results which survive releasing the source or its views.
- Float32 NaN propagation for extrema and normal IEEE arithmetic for sums,
  products, means, infinities and overflow. As elsewhere in Frumpy, no NumPy
  runtime-warning channel is provided; compiler floating-point traps are not
  part of the tested configuration.

For scalar inputs, NumPy accepts explicit axes `0` and `-1` for sum, product,
minimum and maximum. Scalar mean accepts omitted axes only. Frumpy checks this
operation-specific behavior against the pinned NumPy 2.4.6 oracle.

| Reduction over an empty axis | Result |
| --- | --- |
| Sum | Float32 zero |
| Product | Float32 one |
| Mean | Float32 NaN where output elements exist |
| Minimum / maximum | `FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR` because no identity was supplied |

An empty output is different from an empty reduction axis. Reducing axis 1 of
shape `(0, 3)` gives an empty result, including for min/max. Reducing axis 0 of
that shape fails for min/max. For shape `(0, 0)`, min/max fail on either axis,
even though the output would be empty. These cases are tested directly against
NumPy's exceptions.

## Numerical contract

Float32 sums and means use a deterministic pairwise tree with sequential
leaves of at most eight values. Products traverse each slice sequentially.
Traversal is logical C order for all-axis reductions and increasing logical
axis index for single-axis reductions. No float64 accumulator is silently used.

Pairwise summation avoids some severe losses of small contributions: for
`[1e8, 1 repeated 256 times, -1e8]`, the tested float32 sum is 240, matching the
pinned NumPy result; naive sequential float32 summation gives zero. The exact
real-number sum is 256, so this does not claim exact arithmetic.

Reduction order is an explicit compatibility boundary. Frumpy does not
reproduce NumPy's CPU/layout-dependent reduction trees. For four repetitions of
`[1e8, 1, -1e8, 1]`, Frumpy's float32 sum is 2 and the pinned NumPy sum is 0.
`test_float32_reduction_cancellation` locks in both the stability case and this
intentional difference. Near severe cancellation or overflow, differences can
be significant; a general bitwise or relative-error parity guarantee would be
incorrect. Ordinary finite comparison cases use tolerances, while extrema use
exact values with NaN equality. Equal extrema choose the later logical value;
NaN payloads and signed-zero ties in other implementations are not bitwise API
promises.

These choices follow NumPy's default float32 dtype while retaining a small,
explicit implementation. See the official documentation for
[sum precision and reduction order](https://numpy.org/doc/stable/reference/generated/numpy.sum.html),
[mean dtype and precision](https://numpy.org/doc/stable/reference/generated/numpy.mean.html), and
[min NaNs and empty reductions](https://numpy.org/doc/stable/reference/generated/numpy.min.html).

## Status and scope

| Condition | Status |
| --- | --- |
| Missing source storage | `FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR` |
| Missing/malformed metadata or inaccessible storage bounds | `FRUMPY_STATUS_INVALID_SHAPE` |
| Invalid axis, including extreme int32 values | `FRUMPY_STATUS_INVALID_AXIS` |
| Output element count overflow | `FRUMPY_STATUS_OVERFLOW` |
| Explicit allocation failure | `FRUMPY_STATUS_ALLOCATION_FAILED` |

Validation failures return no result buffer. Storage checks occur before
walking strides, preventing malformed descriptors from overflowing index
arithmetic. Allocation status remains subject to the compiler-generated
allocation limits in [STORAGE_LIFETIME.md](STORAGE_LIFETIME.md).

Axis tuples, `dtype`, `initial`, `where`, `out`, NaN-skipping variants,
mixed-dtype reductions and float32 convenience constructors are not in this
slice. This does not expand or change the existing float64 reduction contract.

## Validation

`test/test_reductions_r32.f90` checks ownership, result lifetime, negative axes,
keepdims, malformed metadata, unreachable storage, and output-size overflow.
The 202 new Python reduction cases cover all five operations against NumPy,
including valid positive/negative axes, both keepdims values, empty/scalar
inputs, NaNs/infinities, signed zeros and the numerical-policy fixtures.
Several parameterized cases test multiple axes, so the number of driver calls
is larger than the pytest case count.

Run `make validate`, `make memory-test`, and the compiler matrix described in
[COMPILER_PORTABILITY.md](COMPILER_PORTABILITY.md). The recorded speed baseline
remains unchanged; this pass adds functionality and numerical regression
coverage.
