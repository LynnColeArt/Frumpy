# Argmin and argmax

Native `argmin(source, axis0, keepdims, status)` and `argmax` accept bool,
int32, int64, float32 and float64 descriptors and return an owned, C-order
`ndarray_i64`. Python exposes `frumpy.argmin/argmax(source, axis=None,
keepdims=False)` and matching ndarray methods. The C ABI uses
`frumpy_reduce(FRUMPY_ARGMIN/FRUMPY_ARGMAX, ...)` (operation IDs 8 and 9).
These are additive ABI v1 operations.

An omitted axis reduces the C-logical flattened input, regardless of its
physical layout. One explicit axis returns positions along that axis. Negative
axes normalize once; scalar inputs accept axes 0 and -1. `keepdims` retains
reduced dimensions with extent one. Scalar inputs produce scalar zero, including
with `keepdims=True`. Results always have dtype int64; NumPy uses platform intp.

The first occurrence wins ties, including opposite signed zeros. For floating
inputs, the first NaN wins both operations. Integer values are compared exactly,
without conversion to floating point; bool orders False before True. There is
no summation or accumulation rounding policy for these comparisons.

A zero-length reduced axis is an error even if another axis makes the output
empty (native/C `INVALID_SHAPE`, Python `ValueError`). An empty output batch is
valid when the reduced axis is nonempty: `(0,3)` reduced along axis 1 is valid,
whereas axis 0 is not. Invalid axes return `INVALID_AXIS`. Failed native results
have no storage; failed C calls clear their output handle.

Signed, zero and irregular strides are supported. Inputs are validated before
access. Results own independent storage and survive releasing the input. No
flattened or cast input temporary is allocated. Constant-step reduction paths
use linear addressing; other layouts use logical C-order offset traversal.

This slice supports one integer axis or no axis, plus `keepdims`. It does not
provide `out`, tuple axes, complex inputs, masks or NaN-skipping variants.

Validation includes NumPy differential comparisons through all three interfaces,
exact int64 extremes, first ties/NaNs, signed zeros, infinities, subnormals,
empty reductions, actual sliced views, ownership and malformed native metadata.
