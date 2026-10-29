# Focused float32 norm optimization — 2026-10-27

Baseline: `1e6bc5a` (scaled sequential real64 accumulator). Candidate: `5757b61`
(pairwise real64 widened squares with constant-stride traversal). Float32 results,
IEEE behavior, shape/axis rules, independent ownership and the no-widened-buffer
goal are preserved. Float64 norms retain their original scaled implementation.

Reference-linked Python results, ranges of two run medians:

| Workload | Before µs | After µs | Paired speedup |
| --- | ---: | ---: | ---: |
| Contiguous vector, 65,536 | 490–504 | 50–56 | 9.0–9.8× |
| Contiguous vector, 1,048,576 | 7,274–7,442 | 578–582 | 12.5–12.9× |
| Contiguous Frobenius, 128×128 | 154–161 | 22–23 | 7.0× |

The corresponding 65,536-element C calls fall from 472–491 µs to 38 µs.
NumPy remains faster: roughly 18–24 µs for that vector and 6 µs for the matrix,
with a different float32 accumulation/overflow policy. General irregular matrix
traversal improves less than constant-stride reductions. This bounded pass is
complete; it does not claim uniform speedups for every size, distribution or host.

## Revised accumulation and range argument

Float32 values widen **before** multiplication. A nonzero finite float32 square
is at least 2^-298 and below 2^256. Fewer than 2^63 terms sum below 2^319, safely
inside float64's range. A float32 significand has at most 24 bits, so its square
fits exactly in float64's 53-bit significand. The sum and square root still round.
This removes the need for per-element scaling/division specifically for float32;
it does not justify removing scaling from float64 norms.

Leaves contain at most 64 sequential real64 additions from positive zero. Larger
ranges split at floor(count/2), recursively combine their two sums, then take one
real64 square root and round once to float32. Empty/all-zero norms return positive
zero. IEEE square/add propagation preserves infinity and NaN dominance without
early exits. True float32 result overflow remains infinity. Pairwise accumulation
is neither compensated summation nor a proof of correctly rounded outputs.

Validated reduction strides determine constant-step traversal, including reversed
and zero steps; cached contiguity flags are ignored. Irregular reductions use
general C-logical offsets with the same pairwise tree. No input/product buffer or
new heap workspace is added; recursion uses logarithmic stack depth. See the
[public contract](../../LINEAR_ALGEBRA.md#float32-norm-policy).

## Accuracy and validation

The **176 new cases** pass on both baseline and candidate: reduction-tree boundary
sizes (0/1/63/64/65/127/128/129), long reductions, wide float32 exponent ranges,
small contributions, NaN/infinity, C/reverse/step/zero strides, F-order matrices
and nonadjacent reduction axes. Their high-accuracy reference uses `math.fsum` of
exact float64 squares, followed by sqrt and float32 rounding; tolerance is two
float32 epsilons with zero absolute tolerance. Native invariants additionally
cover negative/offset/singleton strides and misleading cached flags.

The ten existing accuracy diagnostics are identical before and after, including:

| Input/case | Before and after | NumPy float32 |
| --- | ---: | ---: |
| `[1e30, -1e30]` | 1.4142135130433894e30 | infinity |
| `[1e-30, -1e-30]` | 1.4142135555081815e-30 | zero |
| Two minimum positive subnormals | 1.401298464324817e-45 | zero |
| `[4096, 65,536 ones]` | 4103.9921875 | 4103.990234375 |
| True result overflow | infinity | infinity |
| Infinity plus NaN input | NaN | NaN |

This diagnostic agreement is not a general bitwise-equivalence promise: replacing
the scaled sequential algorithm changes rounding order. Robustness tests and
error tolerances, rather than exact agreement with NumPy's reduction tree, define
the acceptance criteria. No fast-math or trapping-mode support is introduced.

All six GNU13/GNU14/Flang19 debug/release profiles pass **4,656 Python tests**,
**38 native programs**, two examples and the C caller. One-thread OpenBLAS passes
all 4,656 tests. Native ASan/overflow gates pass; the combined boundary/package/
numerical suite passes **1,985 tests under each ASan and UBSan**. fpm passes;
the isolated source install passes 366 package tests. The
[validation manifest](../../validation/norm-optimization-2026-10-27.json) records
log hashes and scope. Native/C leak checks are enabled; Python ASan leak detection
is off. Hosted CI and other-platform performance are not claimed.

## Matched benchmark method

GNU14 release, `-std=f2018 -O3 -fimplicit-none`, one backend thread, CPU affinity 0.
Both binaries were rerun in this pass; there are no historical timing substitutes.
No builds or tests overlap measurements. Run two reverses backend, before/after,
dtype, case and C/Python/NumPy workload order. Python/C numbers are ranges of two
seven-sample medians in **µs/call**, after warmup/calibration. Speedup is baseline /
candidate per corresponding run; below one indicates slower. Native results use
seven CPU-time samples with fixed within-process case order.

Imports/setup, reference computation and correctness checks are untimed. Result
allocation/release is timed. C is called through ctypes. Native includes status
and one-element checks. Native and boundary runs have different process/allocation
histories, so their absolute differences do not isolate wrapper overhead.

The main suite uses constant 0.5 inputs and includes unchanged float64 controls.
A reference-linked varied suite uses deterministic random values, wide exponents
with negative strides, F-order matrices and nonadjacent axes. Wide cases keep
Frumpy results finite while NumPy's direct float32 squaring overflows; those NumPy
timings do not represent equivalent finite-result computation. Native varied runs
use a deterministic signed dyadic pattern; the same harness is compiled against
both libraries. Input and result payload sizes are unchanged.

Frumpy norms dispatch no BLAS. Reference/OpenBLAS linkage runs are environment
controls, not backend acceleration measurements. NumPy uses its separate wheel
backend. Raw JSON retains source revisions, binary hashes, linkage, configuration,
individual wall/CPU samples, calibration counts and finite-result flags.

## C ABI and Python: main float32 suite

| Environment | Operation / shape | Layout | C before µs | C after µs | Python before µs | Python after µs | Python speedup × |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| reference | vector 16 | C | 3.66–4.12 | 3.64–3.71 | 13.66–13.91 | 12.82–13.27 | 1.03–1.08 |
| reference | vector 16 | step | 3.60–4.14 | 3.54–3.61 | 12.53–13.23 | 12.84–13.47 | 0.93–1.03 |
| reference | vector 65536 | C | 471.74–490.84 | 37.94–38.35 | 490.15–503.90 | 49.83–55.98 | 9.00–9.84 |
| reference | vector 65536 | step | 461.67–491.25 | 38.88–39.12 | 473.66–501.69 | 51.43–53.51 | 9.21–9.38 |
| reference | vector 1048576 | C | 7345.01–7414.45 | 555.10–560.68 | 7274.14–7442.20 | 578.26–581.83 | 12.50–12.87 |
| reference | vector 1048576 | step | 7361.59–7439.57 | 556.71–595.07 | 7338.45–7468.04 | 576.16–616.62 | 11.90–12.96 |
| reference | matrix 128×128 | C | 140.73–142.66 | 12.10–12.54 | 153.89–161.22 | 21.90–23.00 | 7.01–7.03 |
| reference | matrix 128×128 | step | 144.61–145.58 | 12.31–12.53 | 155.28–158.23 | 22.97–24.22 | 6.53–6.76 |
| reference | vector_axis 16×64×64 | C | 484.21–492.26 | 46.53–47.50 | 496.09–572.07 | 57.93–59.11 | 8.39–9.87 |
| reference | vector_axis 16×64×64 | step | 483.67–501.34 | 51.69–52.09 | 500.43–502.44 | 65.96–66.16 | 7.59–7.59 |
| reference | matrix_batch 16×64×64 | C | 568.95–580.12 | 38.11–38.41 | 583.47–584.44 | 51.24–52.12 | 11.19–11.41 |
| reference | matrix_batch 16×64×64 | step | 557.30–569.13 | 40.52–42.93 | 577.64–583.76 | 53.62–54.64 | 10.57–10.89 |
| openblas | vector 16 | C | 3.61–3.67 | 3.42–3.69 | 11.87–12.23 | 11.92–12.51 | 0.98–1.00 |
| openblas | vector 16 | step | 3.58–3.64 | 3.47–3.49 | 11.81–12.05 | 11.94–12.36 | 0.96–1.01 |
| openblas | vector 65536 | C | 460.31–464.23 | 37.96–38.64 | 477.25–481.76 | 47.88–48.74 | 9.88–9.97 |
| openblas | vector 65536 | step | 459.11–459.43 | 38.54–45.72 | 472.61–476.57 | 47.99–50.30 | 9.40–9.93 |
| openblas | vector 1048576 | C | 7329.26–7383.35 | 554.64–597.75 | 7300.69–7477.50 | 569.11–633.20 | 11.81–12.83 |
| openblas | vector 1048576 | step | 7292.22–7324.70 | 581.27–584.40 | 7334.21–7369.23 | 582.06–583.01 | 12.58–12.66 |
| openblas | matrix 128×128 | C | 147.80–151.98 | 12.03–12.38 | 156.22–158.18 | 22.89–23.04 | 6.83–6.87 |
| openblas | matrix 128×128 | step | 139.94–141.60 | 12.40–13.07 | 153.04–153.52 | 23.15–24.98 | 6.15–6.61 |
| openblas | vector_axis 16×64×64 | C | 481.56–491.77 | 46.23–48.02 | 502.50–509.08 | 58.18–59.85 | 8.40–8.75 |
| openblas | vector_axis 16×64×64 | step | 484.63–497.21 | 50.62–51.52 | 502.74–521.41 | 62.74–62.91 | 8.01–8.29 |
| openblas | matrix_batch 16×64×64 | C | 579.43–623.09 | 37.94–38.14 | 582.79–650.98 | 49.08–49.50 | 11.87–13.15 |
| openblas | matrix_batch 16×64×64 | step | 555.11–894.59 | 40.45–41.10 | 571.16–926.35 | 51.44–52.63 | 10.85–18.01 |

## Varied inputs and irregular axes (float32, reference-linked)

Reverse layouts use wide exponent ranges; C/F layouts use ordinary random values.
`matrix_axes` reduces axes (0,2) of shape (7,9,11), a genuinely irregular reduction.
A one-dimensional F-order vector is also C-contiguous.

| Operation / shape | Layout | C before µs | C after µs | Python before µs | Python after µs | Python speedup × |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| vector 65536 | C | 462.55–487.23 | 39.12–39.24 | 475.61–507.64 | 47.83–60.60 | 7.85–10.61 |
| vector 65536 | reverse | 467.17–498.27 | 38.83–41.49 | 476.63–583.54 | 50.17–50.36 | 9.46–11.63 |
| vector 65536 | F | 460.77–462.18 | 38.75–42.01 | 475.29–495.73 | 48.58–49.65 | 9.57–10.21 |
| matrix 128×128 | C | 142.78–151.15 | 12.00–12.10 | 159.36–171.15 | 21.53–22.00 | 7.24–7.95 |
| matrix 128×128 | reverse | 145.37–146.86 | 119.91–120.96 | 156.59–166.43 | 132.86–134.62 | 1.16–1.25 |
| matrix 128×128 | F | 147.75–158.68 | 120.61–122.51 | 159.00–170.70 | 131.61–133.08 | 1.21–1.28 |
| matrix_axes 7×9×11 | C | 10.00–10.27 | 8.74–8.90 | 20.56–21.03 | 18.51–18.61 | 1.11–1.13 |
| matrix_axes 7×9×11 | reverse | 10.04–10.19 | 8.78–9.22 | 19.96–20.34 | 18.26–18.88 | 1.06–1.11 |
| matrix_axes 7×9×11 | F | 9.89–10.29 | 8.73–9.67 | 19.31–20.79 | 18.72–19.90 | 1.03–1.04 |

## Native Fortran float32

| Environment / inputs | Operation / size | Layout | Before µs | After µs | Speedup × |
| --- | --- | --- | ---: | ---: | ---: |
| reference | vector 16 | C | 0.90–0.90 | 0.75–0.77 | 1.17–1.19 |
| reference | vector 16 | step | 0.90–1.00 | 0.75–0.75 | 1.19–1.32 |
| reference | vector 65536 | C | 457.00–457.40 | 34.85–35.10 | 13.03–13.11 |
| reference | vector 65536 | step | 457.10–465.70 | 35.25–35.45 | 12.89–13.21 |
| reference | vector 1048576 | C | 7325.60–7334.35 | 546.25–562.90 | 13.01–13.43 |
| reference | vector 1048576 | step | 7265.25–8216.35 | 555.60–557.85 | 13.08–14.73 |
| reference | matrix 128 | C | 139.50–141.50 | 9.15–9.15 | 15.25–15.46 |
| reference | matrix 128 | step | 138.75–143.00 | 9.10–9.15 | 15.25–15.63 |
| openblas | vector 16 | C | 0.88–0.89 | 0.75–0.77 | 1.15–1.16 |
| openblas | vector 16 | step | 0.89–0.92 | 0.76–0.81 | 1.09–1.21 |
| openblas | vector 65536 | C | 459.40–462.80 | 34.40–34.55 | 13.35–13.40 |
| openblas | vector 65536 | step | 459.55–465.65 | 34.70–37.30 | 12.48–13.24 |
| openblas | vector 1048576 | C | 7379.60–7610.85 | 551.55–559.70 | 13.38–13.60 |
| openblas | vector 1048576 | step | 7520.75–7522.35 | 553.90–555.10 | 13.55–13.58 |
| openblas | matrix 128 | C | 137.20–137.90 | 9.20–9.50 | 14.44–14.99 |
| openblas | matrix 128 | step | 136.85–137.60 | 9.15–9.55 | 14.41–14.96 |
| varied | vector 16 | C | 0.88–0.90 | 0.78–0.78 | 1.14–1.16 |
| varied | vector 16 | step | 0.87–0.90 | 0.76–0.77 | 1.14–1.19 |
| varied | vector 65536 | C | 456.20–466.15 | 34.40–34.80 | 13.26–13.40 |
| varied | vector 65536 | step | 455.70–460.00 | 34.85–35.60 | 12.80–13.20 |
| varied | vector 1048576 | C | 7323.35–7413.20 | 549.55–554.95 | 13.20–13.49 |
| varied | vector 1048576 | step | 7359.10–8990.45 | 556.50–603.75 | 12.19–16.16 |
| varied | matrix 128 | C | 139.00–144.45 | 9.15–9.80 | 14.18–15.79 |
| varied | matrix 128 | step | 139.80–141.15 | 9.15–9.20 | 15.20–15.43 |

## Float64 controls (Python, contiguous)

Float64 code is unchanged. These controls help expose timing variation rather
than attributing every difference to the optimization.

| Environment | Operation / shape | Before µs | After µs |
| --- | --- | ---: | ---: |
| reference | vector 16 | 12.23–12.60 | 12.55–12.68 |
| reference | vector 65536 | 465.98–504.62 | 485.87–502.48 |
| reference | vector 1048576 | 7298.65–7301.84 | 7324.97–7456.35 |
| reference | matrix 128×128 | 150.53–155.14 | 150.48–151.99 |
| reference | vector_axis 16×64×64 | 504.87–542.41 | 490.35–499.13 |
| reference | matrix_batch 16×64×64 | 568.80–903.61 | 571.12–587.64 |
| openblas | vector 16 | 18.41–22.61 | 11.91–13.06 |
| openblas | vector 65536 | 480.84–726.52 | 468.26–505.70 |
| openblas | vector 1048576 | 7225.25–7369.22 | 7192.75–7203.47 |
| openblas | matrix 128×128 | 150.73–153.28 | 153.62–159.62 |
| openblas | vector_axis 16×64×64 | 498.44–501.86 | 503.90–507.43 |
| openblas | matrix_batch 16×64×64 | 576.37–584.20 | 567.98–579.31 |

## Smaller gains and timing limits

No float32 main-suite C/Python case was more than 10% slower in both passes.
That is a statement about this sample, not a universal no-regression guarantee.
Tiny Python calls remain around 13 µs and move within timing noise. Irregular
128×128 F-order/reversed matrices improve only about 1.2× through Python;
nonadjacent-axis cases improve about 1.03–1.13×. Their general address calculations
remain, so the large constant-stride gains should not be extrapolated to them.
Float64 controls show host/workload variation despite unchanged numerical code.

## Remaining limits and reproduction

Tiny-call overhead remains, and general multidimensional addressing limits
irregular reductions. NumPy is still faster in the tested ordinary cases, but
the gap is substantially narrower without accepting float32 square overflow.
No threading, BLAS dispatch, float64 optimization, full-size scratch buffer or
new dtype/API was introduced. Broader optimization should be justified by
representative workloads rather than these bounded samples alone.

[run-benchmarks.sh](run-benchmarks.sh) records exact local build locations and
run order. Build baseline/candidate separately with matching release flags and
compile `benchmarks/benchmark_norms_precision.f90` against each object directory.
Run `benchmarks/compare_float32_norms.py` with `--source-commit`, `--output`, and
optionally `--varied`; use `--reverse` on pass two. Native runs use CPU affinity 0
and optionally the `varied` argument. Export the selected `FRUMPY_LIBRARY`,
backend `LD_LIBRARY_PATH`, `PYTHONPATH=python`, and single-thread variables.

- [accuracy-after.json](accuracy-after.json)
- [accuracy-before.json](accuracy-before.json)
- [after-openblas-1.json](after-openblas-1.json)
- [after-openblas-2.json](after-openblas-2.json)
- [after-reference-1.json](after-reference-1.json)
- [after-reference-2.json](after-reference-2.json)
- [before-openblas-1.json](before-openblas-1.json)
- [before-openblas-2.json](before-openblas-2.json)
- [before-reference-1.json](before-reference-1.json)
- [before-reference-2.json](before-reference-2.json)
- [native-after-openblas-1.txt](native-after-openblas-1.txt)
- [native-after-openblas-2.txt](native-after-openblas-2.txt)
- [native-after-reference-1.txt](native-after-reference-1.txt)
- [native-after-reference-2.txt](native-after-reference-2.txt)
- [native-before-openblas-1.txt](native-before-openblas-1.txt)
- [native-before-openblas-2.txt](native-before-openblas-2.txt)
- [native-before-reference-1.txt](native-before-reference-1.txt)
- [native-before-reference-2.txt](native-before-reference-2.txt)
- [native-varied-after-1.txt](native-varied-after-1.txt)
- [native-varied-after-2.txt](native-varied-after-2.txt)
- [native-varied-before-1.txt](native-varied-before-1.txt)
- [native-varied-before-2.txt](native-varied-before-2.txt)
- [varied-after-1.json](varied-after-1.json)
- [varied-after-2.json](varied-after-2.json)
- [varied-before-1.json](varied-before-1.json)
- [varied-before-2.json](varied-before-2.json)
