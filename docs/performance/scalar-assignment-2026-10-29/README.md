# Scalar assignment: captured fills

PR #5 was merged at `2cb5f2c`. This pass optimizes its generic same-dtype scalar
assignment; the measured implementation is `44d8967`. It does not change Python
indexing or C signatures, legacy native `assign_r64`, nonscalar staging, or dtype
policy. Binary hashes and full source revisions are in `environment.json`.

## Implementation and memory

A validated single-element RHS is captured once in its concrete dtype before
writing. Ordinary assignment avoids the broadcast-plan and staging allocations.
C/F-contiguous targets use physical linear traversal; uniform positive/negative
steps use direct typed loops; irregular layouts retain logical traversal. A
uniform zero-stride target needs one write regardless of logical size.

Masked scalar assignment retains its selected-position snapshot, including when
the bool mask aliases the target. It removes only the repeated scalar-value
buffer. Nonscalar assignment still stages all RHS values before writes.

For N target elements and K selected elements, basic scalar working storage falls
from N values to one scalar. Masked scalar storage falls from K values plus K
int64 positions to one scalar plus K positions. A 65,536-element float64 fill
therefore removes the 512 KiB value buffer; a half-selected masked fill removes
256 KiB of values while retaining 256 KiB of positions. Descriptor/plan overhead
is additional in the old path. Allocation injection verifies that the ordinary
scalar path makes no allocation and the masked scalar path allocates only positions.

All metadata and shape/dtype checks precede writes. Signed-zero/NaN bits and bool
normalization are preserved. Reported errors leave targets unchanged. Huge valid
zero-stride scalar fills can now succeed without overflowing a hypothetical staging
buffer; nonscalar staging-byte overflow remains an error.

## Matched measurements

GNU 14, `-std=f2018 -O3 -fimplicit-none`, Linux x86-64, same pinned CPU and matching
before/after builds. The initial exploratory baseline was replaced with the data
here after our build/validation jobs completed. Other host activity is not under
our control. NumPy versions, affinity and library hashes are recorded in JSON.

All five dtypes, sizes 16 and 65,536, C/stride-two/reversed/F/irregular layouts,
and ordinary/masked fills are measured through native Fortran, direct C via ctypes,
and public Python. Masks select half the entries; RHS values are preimported.
Python ordinary assignment includes creating/releasing the basic-slice view.
Direct C uses existing target handles. NumPy receives matching views and scalar
inputs. Timing includes working allocations and cleanup, not importing inputs.

Native samples time 1,000 calls for small arrays and 10 for large arrays, after
one warm-up batch. C/Python samples use 100/10 calls respectively. Each has seven
samples per pass. Native executables run before/after, then after/before; Python
repeats with reversed case/call order. `summary.json` combines the 14 samples per
case using their median. Raw samples remain alongside it.

For 65,536-element ordinary scalar assignment, medians across the 20 dtype/layout
cases with C, F, uniform positive or negative strides are:

| Surface | Before µs | After µs | Per-case speedup range |
| --- | ---: | ---: | ---: |
| Native | 824.6 | 15.5 | 28.8–73.7× |
| C through ctypes | 943.0 | 21.9 | 27.2–79.4× |
| Python | 990.0 | 42.7 | 14.0–36.3× |

Irregular ordinary fills improve 2.1–2.3× native and 2.3–2.4× through C/Python.
They still calculate logical offsets; they do not become contiguous kernels.

Masked scalar results are less dramatic: large-array combined medians are
957→839 µs native and 1,322→1,121 µs Python across the regular layouts. Mask scans
and destination snapshots remain dominant. The broad native run initially showed
an int32 stride-two case at 0.85×. A focused 100-call, 14-sample probe in
before/after/after/before order measured medians of 843/750/734/923 µs, or paired
speedups of 1.12–1.26×. The apparent regression did not reproduce; both datasets
are retained in `masked-step-recheck.json` and the original native files.

At 16 elements, ordinary native medians fall from 1.24 to 0.32 µs and direct C
from 2.90 to 1.02 µs. Python still takes roughly 20–30 µs: full-slice construction
and dispatch remain. The raw Python medians vary substantially between passes;
no precise tiny-Python speedup is claimed from these runs. Large regular-array
gains are much greater than the observed variation.

## Reproduction

Build two separate cores from the recorded source revisions with identical flags.
Compile `benchmarks/benchmark_scalar_assignment.f90` against each core's module
directory and objects, then run both on the CPU listed in `environment.json`.
The focused native probe is `benchmarks/probe_masked_scalar.f90`.

For C/Python measurements, run each binary in a fresh process:

```sh
PYTHONPATH=python FRUMPY_LIBRARY=/absolute/path/libfrumpy.so \
  .venv/bin/python benchmarks/compare_scalar_assignment.py \
  --source SOURCE_REVISION --output results.json
```

Repeat with `--reverse`. These are local workload measurements, not universal
speed guarantees. Further optimization of mask traversal and tiny Python overhead
is deliberately deferred.
