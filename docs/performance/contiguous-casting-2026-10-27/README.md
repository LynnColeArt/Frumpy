# Contiguous casting optimization — 2026-10-27

Baseline: `0dc8740` (core identical to `02aa4df`). Candidate: `4d2cabb`.
This pass optimizes casts **to float32/float64** used by mixed dot, outer and
matmul. The conversion policy, accumulation order, temporary payload and result
ownership are unchanged. Integer/bool destination casts retain the checked path.

Representative contiguous int32/float32 results (two-run median ranges):

| Interface / workload | Before µs | After µs | Paired speedup |
| --- | ---: | ---: | ---: |
| Native dot 65,536, reference | 957–1,611 | 511–557 | 1.72–3.15× |
| C ABI dot 65,536, reference | 644–772 | 151–155 | 4.27–4.96× |
| Python dot 65,536, reference | 656–710 | 168–170 | 3.87–4.22× |
| Native matmul 128², OpenBLAS | 302–312 | 123–125 | 2.45–2.51× |
| C ABI matmul 128², OpenBLAS | 335–391 | 137–138 | 2.44–2.84× |
| Python matmul 128², OpenBLAS | 332–343 | 153–178 | 1.92–2.18× |

For the long int32/float32 dot, isolated C casts fall from 664–786 µs to
113–116 µs. Its precast-dot control remains about 48–50 µs. Outer shows much
smaller and noisier changes because conversion is a small part of its work.
Native and boundary timings are separate experiments; see the method below.

## Implementation and validation

The old loop computed a general C-logical offset and selected the source dtype
for every element. The optimized path recomputes C contiguity from validated
shape/strides, selects the source dtype once, and runs a direct typed loop.
It supports nonzero offsets and arbitrary singleton strides. F-order,
stepped, negative-stride and zero-stride inputs retain the general path, except
where singleton/empty shapes also meet C-contiguity rules. Cached descriptor
contiguity flags are never used to authorize the fast path.

No new allocation, intermediate precision, BLAS call, fast-math setting or
promotion rule is introduced. Int64 converts directly to the requested float
kind; bool normalizes nonzero bytes. Casting mode and storage validation still
precede conversion; failed calls preserve the prior destination.

All six GNU13/GNU14/Flang19 debug/release profiles passed **4,359 Python tests**,
**38 native programs**, two examples and the standalone C caller. The new 96
NumPy cast cases also pass on the baseline. Native invariants check offsets,
singleton strides, misleading cached flags, bounds failure and lifetime.
The one-thread OpenBLAS run passes all 4,359 tests. ASan/overflow gates pass;
1,688 combined boundary/package/numerical/casting tests pass under each of ASan
and UBSan. An isolated source install passes 365 package tests; fpm passes.
See the [validation manifest](../../validation/contiguous-casting-2026-10-27.json)
for log hashes and sanitizer limitations. No hosted CI result is claimed.

## Matched timing method

Both binaries were rerun during this pass; these are not comparisons against
historical timings. GNU14 `-std=f2018 -O3 -fimplicit-none`, one backend thread,
CPU affinity 0. No build/test jobs overlapped timings. Reference BLAS/LAPACK and
LP64 OpenBLAS 0.3.26 were tested. NumPy's wheel backend is separate and recorded.

Run one orders reference then OpenBLAS, before then after. Run two reverses
backend, before/after, dtype-pair, case and workload order. Each Python/C metric
uses seven samples after warmup/calibration; tables show the range of the two
run medians in **µs/call**. Speedup is before/after within each corresponding run,
shown as a range: below 1 means slower. Raw files retain wall/CPU samples,
calibration counts, library hash, source revision, linkage and environment.

Inputs/imports, reusable precasts and correctness checks are untimed. Timed calls
include output allocation/release. Isolated cast timings include conversion
allocation/release but not product work. Native measurements use seven CPU-time
samples of 20 allocating calls, with status and one-element result checks;
native case ordering is fixed. Native and C/Python use separate processes and
allocation histories, so their absolute times do not isolate boundary overhead.

C/Python test bool/float32, int32/float32 and float32/float64 pairs; native covers
int32/float32. Both contiguous and stepped inputs are measured. Precast controls
use the promoted dtype and therefore exercise unchanged numerical kernels.

## C ABI: mixed int32/float32 products

| Backend | Operation / size | Layout | Before µs | After µs | Speedup × |
| --- | --- | --- | ---: | ---: | ---: |
| reference | dot 16 | C | 4.75–5.46 | 4.38–5.08 | 0.93–1.25 |
| reference | dot 16 | step | 4.72–5.64 | 4.62–7.53 | 0.75–1.02 |
| reference | dot 65536 | C | 643.69–771.75 | 150.91–155.45 | 4.27–4.96 |
| reference | dot 65536 | step | 764.39–855.24 | 730.10–787.23 | 1.05–1.09 |
| reference | outer 256 | C | 267.51–331.05 | 247.45–295.69 | 1.08–1.12 |
| reference | outer 256 | step | 255.98–332.61 | 276.68–302.35 | 0.85–1.20 |
| reference | matmul 16 | C | 12.44–13.76 | 7.68–11.27 | 1.10–1.79 |
| reference | matmul 16 | step | 10.57–12.44 | 10.65–12.81 | 0.97–0.99 |
| reference | matmul 128 | C | 1432.18–1474.90 | 1199.91–1210.79 | 1.18–1.23 |
| reference | matmul 128 | step | 2291.88–2463.99 | 1347.04–1383.00 | 1.70–1.78 |
| openblas | dot 16 | C | 4.48–4.72 | 4.27–4.91 | 0.96–1.05 |
| openblas | dot 16 | step | 4.92–5.04 | 4.83–8.51 | 0.58–1.04 |
| openblas | dot 65536 | C | 750.81–1276.89 | 163.55–182.55 | 4.11–7.81 |
| openblas | dot 65536 | step | 702.51–748.38 | 741.25–799.35 | 0.94–0.95 |
| openblas | outer 256 | C | 276.80–290.87 | 267.32–293.77 | 0.94–1.09 |
| openblas | outer 256 | step | 278.85–294.00 | 274.15–365.39 | 0.76–1.07 |
| openblas | matmul 16 | C | 10.27–10.55 | 6.84–11.07 | 0.95–1.50 |
| openblas | matmul 16 | step | 9.16–9.36 | 10.17–14.89 | 0.63–0.90 |
| openblas | matmul 128 | C | 334.82–390.60 | 137.44–137.58 | 2.44–2.84 |
| openblas | matmul 128 | step | 346.91–389.52 | 335.39–396.48 | 0.87–1.16 |

## Python: contiguous mixed products

| Backend | Pair | Operation / size | Before µs | After µs | Speedup × |
| --- | --- | --- | ---: | ---: | ---: |
| reference | bool/float32 | dot 16 | 11.03–15.01 | 11.23–14.82 | 0.74–1.34 |
| reference | bool/float32 | dot 65536 | 400.89–417.34 | 97.77–108.26 | 3.70–4.27 |
| reference | bool/float32 | outer 256 | 272.34–278.28 | 241.37–286.28 | 0.97–1.13 |
| reference | bool/float32 | matmul 16 | 17.02–18.80 | 13.55–19.38 | 0.88–1.39 |
| reference | bool/float32 | matmul 128 | 861.09–900.80 | 695.03–708.24 | 1.24–1.27 |
| reference | int32/float32 | dot 16 | 12.47–13.94 | 13.67–21.23 | 0.59–1.02 |
| reference | int32/float32 | dot 65536 | 656.49–709.89 | 168.27–169.76 | 3.87–4.22 |
| reference | int32/float32 | outer 256 | 268.75–301.57 | 273.08–278.29 | 0.97–1.10 |
| reference | int32/float32 | matmul 16 | 23.88–26.01 | 16.23–17.51 | 1.36–1.60 |
| reference | int32/float32 | matmul 128 | 1376.33–1442.29 | 1128.86–1308.47 | 1.05–1.28 |
| reference | float32/float64 | dot 16 | 11.47–13.10 | 11.18–12.31 | 0.93–1.17 |
| reference | float32/float64 | dot 65536 | 365.65–508.41 | 148.37–150.39 | 2.46–3.38 |
| reference | float32/float64 | outer 256 | 288.32–340.07 | 269.02–466.57 | 0.73–1.07 |
| reference | float32/float64 | matmul 16 | 18.95–22.78 | 14.68–32.36 | 0.70–1.29 |
| reference | float32/float64 | matmul 128 | 1298.53–2642.08 | 1070.78–2178.45 | 1.21–1.21 |
| openblas | bool/float32 | dot 16 | 11.50–12.77 | 11.03–11.77 | 1.04–1.08 |
| openblas | bool/float32 | dot 65536 | 378.82–474.88 | 101.65–120.77 | 3.14–4.67 |
| openblas | bool/float32 | outer 256 | 253.40–271.33 | 275.99–292.01 | 0.87–0.98 |
| openblas | bool/float32 | matmul 16 | 14.35–25.94 | 18.57–25.37 | 0.77–1.02 |
| openblas | bool/float32 | matmul 128 | 189.57–200.99 | 80.15–85.36 | 2.35–2.37 |
| openblas | int32/float32 | dot 16 | 12.24–13.17 | 12.98–14.85 | 0.82–1.01 |
| openblas | int32/float32 | dot 65536 | 699.39–733.65 | 175.94–192.80 | 3.81–3.98 |
| openblas | int32/float32 | outer 256 | 294.41–353.36 | 281.06–290.25 | 1.01–1.26 |
| openblas | int32/float32 | matmul 16 | 18.17–20.62 | 16.42–25.69 | 0.71–1.26 |
| openblas | int32/float32 | matmul 128 | 332.01–343.29 | 152.63–178.49 | 1.92–2.18 |
| openblas | float32/float64 | dot 16 | 11.10–15.17 | 13.50–14.12 | 0.79–1.12 |
| openblas | float32/float64 | dot 65536 | 333.68–378.17 | 154.22–154.50 | 2.16–2.45 |
| openblas | float32/float64 | outer 256 | 290.83–292.22 | 329.88–332.05 | 0.88–0.88 |
| openblas | float32/float64 | matmul 16 | 15.52–16.82 | 15.04–23.49 | 0.72–1.03 |
| openblas | float32/float64 | matmul 128 | 233.22–246.03 | 137.41–143.28 | 1.63–1.79 |

## Isolated C conversion and precast controls (int32/float32)

| Backend | Operation / size | Layout | Cast before µs | Cast after µs | Precast product before µs | Precast product after µs |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| reference | dot 16 | C | 5.51–9.06 | 4.42–6.65 | 3.36–5.36 | 2.86–2.90 |
| reference | dot 16 | step | 4.57–9.11 | 4.43–4.75 | 3.09–4.26 | 2.83–2.95 |
| reference | dot 65536 | C | 664.26–786.39 | 112.92–116.35 | 47.51–48.56 | 47.72–49.90 |
| reference | dot 65536 | step | 627.95–662.42 | 677.08–850.39 | 48.44–49.56 | 47.77–49.46 |
| reference | outer 256 | C | 7.90–8.29 | 4.81–4.93 | 250.99–313.53 | 253.14–259.69 |
| reference | outer 256 | step | 6.65–12.46 | 6.89–7.04 | 252.03–328.16 | 254.93–270.96 |
| reference | matmul 16 | C | 12.82–13.85 | 4.96–5.00 | 5.97–7.67 | 5.48–6.86 |
| reference | matmul 16 | step | 7.66–8.37 | 7.89–8.01 | 5.86–6.34 | 5.43–9.67 |
| reference | matmul 128 | C | 232.01–250.58 | 30.14–32.91 | 1193.43–1223.21 | 1054.46–1217.01 |
| reference | matmul 128 | step | 283.77–363.93 | 239.48–252.24 | 2157.43–3206.75 | 1124.71–1207.80 |
| openblas | dot 16 | C | 4.69–4.82 | 5.48–6.50 | 2.94–3.03 | 4.79–5.24 |
| openblas | dot 16 | step | 4.58–4.75 | 4.77–7.87 | 2.96–3.04 | 2.80–3.47 |
| openblas | dot 65536 | C | 647.49–685.41 | 117.09–119.78 | 49.80–55.43 | 52.32–56.14 |
| openblas | dot 65536 | step | 643.47–711.16 | 714.74–800.96 | 48.04–49.77 | 49.35–50.76 |
| openblas | outer 256 | C | 6.81–6.96 | 4.96–5.66 | 277.52–291.74 | 264.90–286.07 |
| openblas | outer 256 | step | 8.58–11.57 | 7.30–7.86 | 269.86–294.24 | 271.60–386.25 |
| openblas | matmul 16 | C | 8.11–8.72 | 5.26–5.30 | 4.15–5.79 | 4.07–4.23 |
| openblas | matmul 16 | step | 8.35–8.95 | 14.30–15.19 | 4.03–4.10 | 4.46–7.87 |
| openblas | matmul 128 | C | 230.13–239.74 | 32.69–41.26 | 100.15–107.89 | 103.93–111.99 |
| openblas | matmul 128 | step | 246.31–338.61 | 257.36–321.68 | 102.21–104.12 | 100.53–112.72 |

## Native Fortran: int32/float32

| Backend | Operation / size | Layout | Before µs | After µs | Speedup × |
| --- | --- | --- | ---: | ---: | ---: |
| reference | outer 256 | C | 230.25–422.90 | 228.65–249.25 | 0.92–1.85 |
| reference | outer 256 | step | 225.80–407.30 | 230.30–411.10 | 0.55–1.77 |
| reference | dot 65536 | C | 957.25–1611.20 | 510.70–556.65 | 1.72–3.15 |
| reference | dot 65536 | step | 988.25–1561.50 | 970.10–1100.50 | 0.90–1.61 |
| reference | matmul 128 | C | 1255.25–1355.85 | 1090.35–1195.40 | 1.05–1.24 |
| reference | matmul 128 | step | 1253.50–1304.85 | 1357.80–1700.40 | 0.77–0.92 |
| openblas | outer 256 | C | 280.20–393.30 | 241.30–308.35 | 0.91–1.63 |
| openblas | outer 256 | step | 298.60–401.40 | 227.30–300.35 | 0.99–1.77 |
| openblas | dot 65536 | C | 1176.70–1433.25 | 513.30–569.50 | 2.07–2.79 |
| openblas | dot 65536 | step | 1017.50–1421.50 | 1056.00–1254.10 | 0.81–1.35 |
| openblas | matmul 128 | C | 301.65–312.05 | 123.10–124.50 | 2.45–2.51 |
| openblas | matmul 128 | step | 317.80–317.90 | 304.60–417.45 | 0.76–1.04 |

## Slower cases and focused rechecks

The main runs include slower observations, particularly tiny and stepped calls.
Seven OpenBLAS interface/case combinations were more than 10% slower in both
initial passes. These were explicitly rechecked in before/after/after/before
order, with only the six distinct affected workloads enabled. Most original
slowdowns did not reproduce; raw `recheck-*.json` files retain all results.

The stepped bool/float32 dot remained slower through C in that focused batch:
375–381 µs before versus 423–461 µs after. Its cast-only and precast controls
were not slower. A second recheck ran each metric alone in a fresh process,
with 21 samples and before/after/after/before ordering:

| Stepped bool/float32 dot metric | Before µs | After µs |
| --- | ---: | ---: |
| C mixed dot | 384–484 | 383–390 |
| Python mixed dot | 388–388 | 410–428 |
| C cast only | 335–378 | 344–345 |

The C slowdown is not consistent across benchmark arrangements. The isolated
Python result remains **6–10% slower**; retain this as a measured limitation,
not proof that all fallback performance is unchanged. The optimized contiguous
loop is not used by that stepped cast. Allocation history, code placement and
host timing variability are possible influences, not established explanations.
No blanket no-regression or universal speedup claim is made.

Native reference stepped 128×128 matmul also had slower main-run medians.
A fresh before/after/after/before recheck gave 1,278–1,325 µs before and
1,253–1,361 µs after, overlapping and not consistently reproducing that slowdown.
The full samples remain in `native-recheck-*.txt`. Likewise, apparent large
improvements in unchanged stepped controls should not be credited to the new
contiguous loop.

`benchmarks/recheck_stepped_casting.py` reproduces the isolated check; the
included recheck scripts record order, filters and environment. These follow-ups
use the same native libraries as the main runs; no numerical code changed.

## Scope and remaining costs

Temporary payload is unchanged: equal-size int32/float32 inputs still allocate
1 MiB of casts for the 65,536-element dot, 4 KiB for 256-element outer, and 256 KiB
for 128×128 matmul, in addition to outputs and existing backend workspaces.
The casts are faster; they are not fused with computation or cached. Reusing
explicit casts still avoids their allocation and traversal entirely.

The general stride path and numerical kernels remain unchanged. Stepped inputs,
outer's quadratic output loop, and tiny-call overhead therefore should not be
expected to improve substantially. Timing movement on these controls should be
weighed against the raw run-to-run variation, not attributed automatically to
the contiguous cast loop. Results are specific to this host, sizes and backends.

## Reproduction

[run-benchmarks.sh](run-benchmarks.sh) records execution order and local paths.
Build baseline and candidate in separate directories with the same compiler and
flags, retaining both libraries and native benchmark binaries. Use
`benchmarks/compare_product_promotion.py --source-commit <revision> --output <file>`
with the relevant `FRUMPY_LIBRARY`, backend `LD_LIBRARY_PATH`, `PYTHONPATH=python`
and single-thread variables. Run the native benchmark with `taskset -c 0`.
Use `--reverse` for run two. The two native programs are built from identical
`benchmarks/benchmark_product_promotion.f90` source against the respective objects.

- [after-openblas-1.json](after-openblas-1.json)
- [after-openblas-2.json](after-openblas-2.json)
- [after-reference-1.json](after-reference-1.json)
- [after-reference-2.json](after-reference-2.json)
- [before-openblas-1.json](before-openblas-1.json)
- [before-openblas-2.json](before-openblas-2.json)
- [before-reference-1.json](before-reference-1.json)
- [before-reference-2.json](before-reference-2.json)
- [isolated-c-1-before.json](isolated-c-1-before.json)
- [isolated-c-2-after.json](isolated-c-2-after.json)
- [isolated-c-3-after.json](isolated-c-3-after.json)
- [isolated-c-4-before.json](isolated-c-4-before.json)
- [isolated-cast-1-before.json](isolated-cast-1-before.json)
- [isolated-cast-2-after.json](isolated-cast-2-after.json)
- [isolated-cast-3-after.json](isolated-cast-3-after.json)
- [isolated-cast-4-before.json](isolated-cast-4-before.json)
- [isolated-python-1-before.json](isolated-python-1-before.json)
- [isolated-python-2-after.json](isolated-python-2-after.json)
- [isolated-python-3-after.json](isolated-python-3-after.json)
- [isolated-python-4-before.json](isolated-python-4-before.json)
- [native-after-openblas-1.txt](native-after-openblas-1.txt)
- [native-after-openblas-2.txt](native-after-openblas-2.txt)
- [native-after-reference-1.txt](native-after-reference-1.txt)
- [native-after-reference-2.txt](native-after-reference-2.txt)
- [native-before-openblas-1.txt](native-before-openblas-1.txt)
- [native-before-openblas-2.txt](native-before-openblas-2.txt)
- [native-before-reference-1.txt](native-before-reference-1.txt)
- [native-before-reference-2.txt](native-before-reference-2.txt)
- [native-recheck-1-before.txt](native-recheck-1-before.txt)
- [native-recheck-2-after.txt](native-recheck-2-after.txt)
- [native-recheck-3-after.txt](native-recheck-3-after.txt)
- [native-recheck-4-before.txt](native-recheck-4-before.txt)
- [recheck-1-before.json](recheck-1-before.json)
- [recheck-2-after.json](recheck-2-after.json)
- [recheck-3-after.json](recheck-3-after.json)
- [recheck-4-before.json](recheck-4-before.json)
