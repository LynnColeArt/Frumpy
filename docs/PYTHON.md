# Python package

Frumpy v0.1 provides a bounded CPU ndarray API implemented by the native Fortran
engine. NumPy 2.x supplies input coercion, buffer interchange and dtype metadata;
Frumpy operations execute native kernels. Unsupported NumPy ufunc/function
protocol calls raise rather than falling back to NumPy computation.

## Source installation

Supported release target: Linux x86_64, Python 3.10+, a Fortran 2018 compiler,
Make, C compiler, and LP64 BLAS/LAPACK development libraries. On Debian/Ubuntu the
native dependencies are `gfortran`, `make`, `gcc`, `libblas-dev`, `liblapack-dev`.
Use an isolated environment:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install .
```

The build invokes Make and bundles `libfrumpy.so` into the installed package.
It still depends on the matching compiler runtime and BLAS/LAPACK shared
libraries. This is a local platform build, not a portable binary wheel promise.
`FC`, `FFLAGS`, and `LINALG_LIBS` override build settings. Default flags retain
runtime checks and IEEE semantics. Never use `-ffast-math` for the supported
numerical contract. `FRUMPY_LIBRARY=/absolute/path/libfrumpy.so` can select a
separately built ABI-v1 library for development/testing.

## Arrays and ownership

```python
import frumpy as fp

a = fp.asarray([[1., 2.], [3., 4.]])
v = a[::-1, :]
del a                       # v retains its backing
result = (v + 2.).sum(axis=1)
print(result.numpy())       # explicit owned NumPy copy
```

Supported dtypes are bool, int32, int64, float32 and float64, native endian only.
External input imports always copy. `asarray` of a Frumpy array reuses it when
its dtype/order already fits; `array` and `copy` explicitly copy. The default
asarray order is K; external imports preserve exclusively F-contiguous order,
otherwise C. `ascontiguousarray` deliberately always copies and preserves scalar
rank. `.numpy()`, `.tolist()` and `np.asarray(array)` export copies. NumPy
`copy=False` conversion is rejected. Zero-copy interchange is deferred.

Views retain backing independently. `.close()` releases this Python object's
handle; garbage collection also releases it. Closing a parent does not invalidate
its views. A context manager is available for deterministic release. Calls are
serialized around the native registry. Public dtype/shape/strides/ndim/size
metadata is read-only; Python strides are in bytes. Flags expose C/F contiguity
and ownership as immutable metadata, not a writable-buffer interface.

Basic indexing supports integers, slices (including clipping/negative steps),
one ellipsis and new axes. Integer-only scalar indexing returns a NumPy scalar;
other indexing returns a Frumpy array. Float64 full-shape bool masks extract an
owned flat array. Arbitrary advanced indexing and mask assignment are unsupported.
Float64 basic-slice assignment stages its float64 RHS before writing, including
aliased RHS views. Other destination/source dtypes are explicitly unsupported.

Reshape supports one inferred -1 dimension at the Python boundary but requires
C-contiguous source storage. Ravel shares C-contiguous storage and copies other
layouts; flatten always copies. Transpose reverses axes; swapaxes supplies other
permutations incrementally. Squeeze and reductions support at most one explicit
axis. Python negative axes are normalized.

## Dtypes and operations

Array pairs use native [promotion](MIXED_ARITHMETIC.md). Python bool/int/float
scalars are weak operands: their target dtype is resolved with NumPy 2.x
`result_type(array.dtype, scalar)` before import. Python integers outside that
dtype's range raise. NumPy scalars are strong operands. Explicit array casts run
through native `astype`; see [conversion departures](ARRAY_OPERATIONS.md).

Constructors, arithmetic, comparisons, boolean logical operations, views and
reductions follow the [coverage table](DTYPE_SUPPORT.md). Float64 arange/linspace,
selection, stable sorting, ordered search, dot/outer/matmul, batched solve and
Euclidean/Frobenius norms are exposed. Non-float64 selection/numerical input is
rejected rather than silently converted. `flatnonzero` accepts bool only.
Reduction results remain Frumpy arrays, including rank-zero results; use `.item()`
for a Python scalar. Reductions have no out/where/initial or tuple-axis options.

`fp.random.default_rng(seed=0)` supplies explicit seeded streams. `.random(size)`
and `.standard_normal(size)` return float64 arrays; omitted size returns a Python
float. `.state` reads/writes the seven-word tuple; see [RANDOM.md](RANDOM.md).
The default seed is deterministic, not operating-system entropy.

Native status maps to ValueError (shape/arguments/singularity), IndexError (axis),
MemoryError, OverflowError, TypeError (dtype), NotImplementedError (unsupported
behavior/casting policy), or ReferenceError (closed/invalid handle). Existing
arrays remain valid after reported failures. Native reductions may return NaN
without issuing NumPy's warning; accumulation/tolerance departures remain those
of the Fortran API.


Scalar reduction axes are validated in Python before conversion to the ABI's
int32 axis type, so oversized Python integers cannot wrap to a valid axis.
Only -1 and 0 reach native scalar-axis handling; operation-specific restrictions
(such as float64 explicit scalar axes) remain unchanged.
