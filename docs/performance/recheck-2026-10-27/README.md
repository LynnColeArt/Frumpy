# Regression recheck and tiny-call dispatch — 2026-10-27

The stepped-matmul and solve slowdowns from the [previous report](../queue-2026-10-27/README.md)
did not reproduce consistently in focused repeated comparisons. No native
matrix or solver code was changed in this pass. The shipped change skips
redundant Python `asarray(..., order="K")` calls when both binary operands are
already Frumpy arrays. Handle checks, native promotion, eager result metadata,
scalar coercion and finalizer ownership remain in place.

## Matrix regression recheck

Six alternating process pairs compare the pre-queue numerical library with the
final queue library, holding the Python wrapper constant. Both use the same
one-thread LP64 OpenBLAS. Each case verifies results against NumPy before timing.
Nine samples of 15 allocating calls use process CPU time on one pinned CPU.
Ranges below span the six per-process medians, not confidence intervals.

| Case | Before µs | After µs |
| --- | ---: | ---: |
| matmul 512² stepped | 10972.46–11549.92 | 10817.20–11702.65 |
| solve 128² C | 282.97–418.75 | 297.15–398.07 |
| matmul 16² C | 12.00–27.82 | 13.03–22.91 |

Absolute timings moved from the earlier session, reinforcing the need for
adjacent comparisons. This evidence does not prove that the earlier slowdown
was imaginary or that every machine is regression-free; it does not establish
a repeatable code regression to fix. The tiny reference-BLAS matmul slowdown
from the previous report remains a separate observation: the matrix recheck
here uses OpenBLAS.

A diagnostic interposer times complete DGEMM/DGESV calls. Three further pairs
show the following ranges of process medians. Instrumented and uninstrumented
sessions must not be directly subtracted from one another.

| Case / phase | Before µs | After µs |
| --- | ---: | ---: |
| matmul 512² / backend | 5403.82–5578.29 | 5426.07–5650.30 |
| matmul 512² / remainder | 4177.03–4418.56 | 4196.70–4407.17 |
| solve 128² / backend | 182.07–261.76 | 185.42–216.86 |
| solve 128² / remainder | 76.57–95.85 | 78.26–87.90 |

Both phases overlap. The remainder includes input packing, output copying,
finite checks, descriptor work and Python overhead; this probe does not identify
which of those dominates. Roughly 4.2–4.4 ms outside DGEMM is still a substantial
optimization opportunity for this stepped workload, but it is not a newly
established regression. For solve with 128 RHS columns, the empty-RHS correctness
fix still passes 128 to DGESV and does not select the dummy-column case.

## Tiny-call overhead

The [profile](tiny-profile.txt) points to FFI calls and result construction.
For two existing Frumpy arrays, general coercion also repeats handle/order work
that is unnecessary. A three-line dispatch fast path removes those redundant
calls while retaining the checked handles passed to native execution.

Two wrappers run in the same process against the same native library. Each of
21 samples alternates baseline/candidate order and times 3,000 calls after 100
warmups. All result construction and close work stays inside timing. The
checked-FFI and retained-handle wrapping cases are unchanged controls.

| Run / case | Before median µs | After median µs | Median paired speedup |
| --- | ---: | ---: | ---: |
| 1 / public | 17.225 | 17.242 | 1.061× |
| 1 / checked | 6.109 | 6.292 | 0.980× |
| 1 / wrap_retained | 11.131 | 11.709 | 0.997× |
| 2 / public | 15.745 | 15.185 | 1.103× |
| 2 / checked | 5.284 | 4.862 | 1.032× |
| 2 / wrap_retained | 9.420 | 10.272 | 0.890× |

The final median paired ratios are 1.061× and 1.103×. Whole-session medians
range from essentially unchanged in run 1 to about 4% lower in run 2; those
are different summaries of noisy distributions. Earlier exploratory paired
runs also favored the fast path, but this evidence does not justify a fixed
percentage guarantee. Controls fluctuate despite unchanged code. Retain this
simple removal of redundant work, without presenting it as another large gain.

This is a bounded wrapper improvement, not a reduction in native allocation
cost or a universal speedup across operations. The warmed allocation probe still
counts 29 native requests / 689 bytes for C-ABI addition and 31 / 705 through
Python. A separate experiment consolidated result metadata into one ctypes
structure; it showed no clear additional gain and was discarded. The retained
`paired-struct.json` records that exploratory comparison, not shipped behavior.

## Validation and stopping point

[Validation evidence](../../validation/recheck-2026-10-27.json) records 3,081
Python tests passing against each of the six existing GNU 13/14 and Flang 19
native configurations, plus one-thread OpenBLAS. ABI/package ASan and UBSan each
pass 410 tests. The native libraries are unchanged and retain their prior native
and lifetime validation; this pass does not claim a fresh native rebuild.
Three added cases cover closed operands and view/broadcast metadata through the
array-pair path. Existing scalar/dtype and ownership tests continue to pass.

The pass is complete. The matrix timing questions are classified as
not reproduced, with evidence preserved, rather than declared fixed. If another
performance slice is warranted, isolate the stepped path's packing and output
copying within the measured remainder, then profile the 29 native allocation
requests in tiny arithmetic before introducing buffer reuse or metadata APIs.
The reference-BLAS tiny-matmul observation also remains worth tracking. No
backend defaults, public ABI, threading policy or numerical semantics changed.

## Reproduction

`benchmarks/recheck_linalg.py LABEL` uses `PYTHONPATH` and `FRUMPY_LIBRARY` for
its selected wrapper/library. Set `LD_LIBRARY_PATH` to the chosen LP64 backend.
Run baseline/final then final/baseline repeatedly with other jobs stopped.
To collect phases, build `benchmarks/probe_linalg.c` as described in its header,
set `LD_PRELOAD` and `FRUMPY_PROBE` to that shared object, and set
`FRUMPY_PROBE_BACKEND` to the LP64 OpenBLAS library providing both symbols.
The interposer is a single-threaded diagnostic, not part of Frumpy's runtime.

`benchmarks/compare_tiny_dispatch.py BASELINE/frumpy CANDIDATE/frumpy` loads both
wrappers under separate module names against `FRUMPY_LIBRARY`. Raw samples,
library/wrapper hashes and attribution details accompany this report. The
manifest identifies the earlier matrix libraries independently of the new
wrapper commit. Exploratory timings are retained separately from the final
paired tiny-call measurements.
