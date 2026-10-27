# Floating-result product promotion — 2026-10-27

Implementation commit: `02aa4df`. NumPy oracle: 2.4.6. The floating-result slice
is implemented across native Fortran, C ABI v1 and Python. There was no previous
mixed-product implementation to speed up: the baseline here is explicitly cast,
reusable inputs at the same computation dtype.

For repeated int32/float32 inputs, Python's 65,536-element dot takes 685–687 µs
with implicit casts versus 58–59 µs after precasting (reference backend).
OpenBLAS 128×128 matmul takes 322–332 µs versus 103–110 µs. Conversion is a
smaller fraction of outer's quadratic output work. Reusable casts are the first
practical improvement; contiguous `astype` is a focused future optimization.

## Contract and validation

- bool + float32 stays float32; int32/int64 + float32 promotes to float64;
  any registered dtype + float64 produces float64. Both operand orders work.
- Inputs are converted before computation. Only changed inputs allocate casts;
  matching inputs keep their strides. The promoted dtype selects the existing
  dot/outer/matmul numerical kernel. No output-only cast or widened real32 dot.
- Native `call dot/outer/matmul(lhs,rhs,result,status)` requires the promoted
  destination type and preserves the old result on failure. C failures publish
  a zero handle. Results survive input and temporary release.
- Integral-only products and mixed solve remain unsupported. Norms are unchanged.
- All 16 floating-result ordered pairs are covered, including scalars, C/F layouts,
  negative strides, batches, empty inputs, cancellation, int64 rounding and recovery.
  See [the API contract](../../LINEAR_ALGEBRA.md#floating-result-promotion).

The final suite has **4,263 Python tests**, including **408 promotion tests**,
plus **38 native programs**, two examples and the standalone C caller.
GNU 13, GNU 14 and Flang 19 passed debug/release checks: 4,262 tests per profile
plus the final package smoke separately in each. OpenBLAS passed all 4,263 tests.
ASan and integer-overflow checks passed; the combined C/package/numerical suite
passed 1,592 tests under both ASan and UBSan. The isolated source install passed
365 package tests; fpm passed. [Validation manifest](../../validation/product-promotion-2026-10-27.json)
records log hashes and qualifications. No hosted-CI result is claimed.

## Measurement method

GNU 14 release (`-std=f2018 -O3 -fimplicit-none`), one backend thread, CPU affinity 0.
Each Python/C workload has seven timed samples after warmup/calibration. Entries
below are the range of the two run medians in **microseconds per call**. Run two
reverses backend, dtype-pair, case and workload order. Native measurements use
seven CPU-time samples of 20 allocating calls; native ordering is fixed. Native and C/Python run in different processes with
different allocation histories; their absolute times should not be interpreted
as a controlled measurement of language-boundary overhead.
No builds or tests ran concurrently with these timings.

Reference BLAS/LAPACK and extracted LP64 OpenBLAS 0.3.26 were tested using the
same Frumpy library. NumPy uses its own wheel backend, recorded in each JSON.
Library hashes, source commit, resolved linkage, affinity, NumPy configuration,
individual samples, CPU times and calibration counts are retained in the raw files.
Native timings cover int32/float32; C/Python cover bool/float32, int32/float32 and
float32/float64. These measurements do not claim coverage of every size or dtype.

Input import, setup, correctness checks and reusable precasts are outside timing.
Calls include result allocation/release. Isolated casts also allocate/release;
Python includes wrapper cost, C is called via ctypes. Native checks status and
one result element per call. Cast-only sums are diagnostic, not an identity for
mixed-minus-precast timing: cache state, layout, allocation and noise differ.
For stepped inputs, changed operands become contiguous as part of conversion;
precast baselines preserve matching operands' original strides in the same way.

## Conversion payload

These are analytical live payload sizes, excluding array metadata, result storage,
allocator overhead and any existing matmul packing workspaces; they are not RSS measurements.

| Pair | Extra payload per converted element |
| --- | --- |
| bool + float32 | 4 bytes for the bool input |
| int32 + float32 | 8 bytes for each input |
| float32 + float64 | 8 bytes for the float32 input |

For equal-size int32/float32 inputs: the 65,536-element dot casts allocate **1 MiB**;
256-element outer casts use **4 KiB**, while its output uses **512 KiB**;
128×128 matmul casts use **256 KiB**, with a **128 KiB** output.
Conversions recur on every implicit call, including vacuous products before kernel
validation. Reusing explicit casts trades retained storage for avoiding repeat work.

## C ABI: two conversions (int32/float32 → float64)

| Backend | Operation / size | Layout | Mixed µs | Reused precasts µs | Cast-only µs |
| --- | --- | --- | ---: | ---: | ---: |
| reference | dot 16 | C | 4.31–4.44 | 2.83–2.94 | 4.37–4.39 |
| reference | dot 16 | step | 4.26–4.37 | 2.86–2.89 | 4.35–7.27 |
| reference | dot 65536 | C | 677.52–693.62 | 48.18–49.89 | 606.12–672.30 |
| reference | dot 65536 | step | 628.14–784.19 | 46.91–49.06 | 606.84–626.22 |
| reference | outer 256 | C | 274.89–457.67 | 269.32–452.41 | 6.60–9.33 |
| reference | outer 256 | step | 248.13–272.83 | 243.68–288.83 | 6.78–6.96 |
| reference | matmul 16 | C | 10.31–11.76 | 5.34–8.57 | 7.63–7.99 |
| reference | matmul 16 | step | 10.22–12.71 | 5.35–6.15 | 7.62–10.51 |
| reference | matmul 128 | C | 1260.64–1494.63 | 1099.96–1123.72 | 227.96–229.06 |
| reference | matmul 128 | step | 1289.12–1521.35 | 1063.04–1299.71 | 224.58–240.15 |
| openblas | dot 16 | C | 5.39–5.60 | 3.13–4.92 | 4.78–5.59 |
| openblas | dot 16 | step | 4.78–8.28 | 4.58–5.30 | 4.80–9.03 |
| openblas | dot 65536 | C | 730.19–738.94 | 48.68–49.30 | 726.73–739.17 |
| openblas | dot 65536 | step | 750.64–1157.25 | 48.95–50.45 | 618.58–924.76 |
| openblas | outer 256 | C | 270.46–279.80 | 274.69–283.09 | 6.65–7.96 |
| openblas | outer 256 | step | 261.24–303.86 | 278.37–301.39 | 6.75–7.49 |
| openblas | matmul 16 | C | 8.75–9.14 | 3.86–4.28 | 7.99–10.64 |
| openblas | matmul 16 | step | 10.75–12.10 | 3.95–5.46 | 8.18–8.97 |
| openblas | matmul 128 | C | 307.71–345.21 | 92.17–112.02 | 222.94–235.29 |
| openblas | matmul 128 | step | 314.53–338.41 | 92.90–103.35 | 219.87–255.48 |

## Python: one or two conversions, contiguous inputs

| Backend | Pair | Operation / size | Mixed µs | Reused precasts µs | Cast-only µs |
| --- | --- | --- | ---: | ---: | ---: |
| reference | bool/float32 | dot 16 | 11.09–11.14 | 10.07–11.71 | 10.20–11.24 |
| reference | bool/float32 | dot 65536 | 407.04–459.42 | 58.61–67.14 | 344.90–392.07 |
| reference | bool/float32 | outer 256 | 251.75–283.92 | 243.30–253.57 | 10.92–11.35 |
| reference | bool/float32 | matmul 16 | 14.76–17.18 | 11.97–12.31 | 11.26–12.56 |
| reference | bool/float32 | matmul 128 | 756.64–844.22 | 697.13–817.83 | 122.30–143.34 |
| reference | int32/float32 | dot 16 | 11.78–12.97 | 9.77–10.28 | 19.07–22.12 |
| reference | int32/float32 | dot 65536 | 685.08–686.71 | 58.02–59.10 | 705.42–720.29 |
| reference | int32/float32 | outer 256 | 258.35–292.41 | 283.55–370.35 | 24.45–45.17 |
| reference | int32/float32 | matmul 16 | 17.97–19.30 | 12.75–13.44 | 22.48–26.83 |
| reference | int32/float32 | matmul 128 | 1307.99–1594.37 | 1058.52–1232.81 | 249.29–271.33 |
| reference | float32/float64 | dot 16 | 10.51–13.63 | 10.34–10.42 | 9.96–11.19 |
| reference | float32/float64 | dot 65536 | 322.03–472.11 | 56.13–61.15 | 276.74–328.78 |
| reference | float32/float64 | outer 256 | 264.42–320.24 | 263.14–299.37 | 11.04–12.55 |
| reference | float32/float64 | matmul 16 | 15.39–15.68 | 12.75–14.91 | 12.05–16.48 |
| reference | float32/float64 | matmul 128 | 1201.97–1665.24 | 1048.21–1468.27 | 120.77–147.19 |
| openblas | bool/float32 | dot 16 | 10.60–13.45 | 9.84–16.31 | 9.40–11.07 |
| openblas | bool/float32 | dot 65536 | 407.71–550.20 | 59.01–76.49 | 345.69–395.45 |
| openblas | bool/float32 | outer 256 | 248.26–262.97 | 247.55–309.97 | 11.36–14.82 |
| openblas | bool/float32 | matmul 16 | 13.53–24.16 | 15.37–17.48 | 11.03–12.44 |
| openblas | bool/float32 | matmul 128 | 195.97–288.72 | 74.46–84.37 | 143.58–205.79 |
| openblas | int32/float32 | dot 16 | 15.61–18.10 | 12.43–16.20 | 26.19–28.28 |
| openblas | int32/float32 | dot 65536 | 742.92–760.01 | 59.30–60.15 | 633.83–687.85 |
| openblas | int32/float32 | outer 256 | 308.07–318.24 | 254.05–293.30 | 25.28–29.26 |
| openblas | int32/float32 | matmul 16 | 16.54–22.68 | 11.31–18.91 | 23.27–35.84 |
| openblas | int32/float32 | matmul 128 | 322.00–332.26 | 103.36–110.37 | 245.64–250.36 |
| openblas | float32/float64 | dot 16 | 10.74–12.39 | 12.44–17.39 | 9.44–13.23 |
| openblas | float32/float64 | dot 65536 | 333.02–389.34 | 59.29–62.12 | 292.24–534.95 |
| openblas | float32/float64 | outer 256 | 260.77–267.52 | 277.37–282.84 | 10.66–13.88 |
| openblas | float32/float64 | matmul 16 | 14.35–21.67 | 11.45–11.71 | 11.39–11.72 |
| openblas | float32/float64 | matmul 128 | 248.39–289.78 | 112.13–147.21 | 128.43–139.26 |

## Native Fortran: int32/float32 → float64

| Backend | Operation / size | Layout | Mixed µs | Reused precasts µs | Cast-only µs |
| --- | --- | --- | ---: | ---: | ---: |
| reference | outer 256 | C | 230.50–231.70 | 221.00–224.90 | 3.50–3.55 |
| reference | outer 256 | step | 226.30–230.00 | 225.75–349.25 | 3.50–3.55 |
| reference | dot 65536 | C | 980.35–1516.40 | 44.85–46.40 | 962.00–1478.20 |
| reference | dot 65536 | step | 1042.60–1594.80 | 45.70–46.55 | 932.80–1572.95 |
| reference | matmul 128 | C | 1404.15–1721.95 | 1023.10–1229.35 | 226.55–227.00 |
| reference | matmul 128 | step | 1266.00–1518.85 | 1155.40–1335.20 | 247.25–259.85 |
| openblas | outer 256 | C | 236.40–243.25 | 223.40–244.15 | 3.50–6.75 |
| openblas | outer 256 | step | 229.55–270.85 | 224.40–242.85 | 3.45–3.70 |
| openblas | dot 65536 | C | 958.15–1126.45 | 44.60–45.15 | 912.45–1057.95 |
| openblas | dot 65536 | step | 964.00–1129.75 | 44.65–44.80 | 942.65–1043.10 |
| openblas | matmul 128 | C | 313.65–407.90 | 88.60–89.25 | 210.55–224.20 |
| openblas | matmul 128 | step | 312.50–399.60 | 89.05–91.60 | 214.55–215.05 |

## Interpretation

Conversion is material for long vector dot: two full casts can cost much more
than the already-float64 reduction. Conversion also becomes a larger fraction
of matmul when OpenBLAS makes the computation faster. Outer writes a quadratic
output from linear-size inputs, so its casting fraction is much smaller here.
Tiny-call results include allocation, dispatch and wrapper overhead.

Some measurements reverse the expected mixed/precast ordering, especially outer
and tiny calls. The run ranges and raw samples are retained; these reversals are
not evidence that adding conversions accelerates the operation. Do not treat the
tables as universal speedups or exact conversion surcharges.

Use reusable precasts first for repeated operations on stable inputs. If profiling
shows frequent one-shot mixed products, contiguous `astype` is a focused next
optimization candidate: current casts visit each element through general stride
addressing. That work is separate from this completed functionality slice.
Dot/outer kernel gaps measured in the preceding report remain; promotion does not
change those kernels or their accumulation/IEEE contracts.

## Reproduction and evidence

Build with GNU 14 release and versioned BLAS/LAPACK linkage, then set
`FRUMPY_LIBRARY`, `PYTHONPATH=python`, the chosen backend `LD_LIBRARY_PATH`, and
`OPENBLAS_NUM_THREADS=OMP_NUM_THREADS=1`. Run
`python benchmarks/compare_product_promotion.py --output result.json`, repeat
with `--reverse`, and switch backends. Compile
`benchmarks/benchmark_product_promotion.f90` against the same core object files
and run with `taskset -c 0`.

- [native-openblas-1.txt](native-openblas-1.txt)
- [native-openblas-2.txt](native-openblas-2.txt)
- [native-reference-1.txt](native-reference-1.txt)
- [native-reference-2.txt](native-reference-2.txt)
- [openblas-1.json](openblas-1.json)
- [openblas-2.json](openblas-2.json)
- [reference-1.json](reference-1.json)
- [reference-2.json](reference-2.json)
