# Five-dtype stable sort/argsort — 2026-10-28

Stable sort and argsort now support bool, int32, int64, float32 and float64
through native Fortran, C and Python. Sort preserves the value dtype, argsort
returns int64 indices, and both allocate independent outputs. Exact int64
ordering, stable NaN/signed-zero ties, float32 NaN payloads and all existing
layout policies are preserved. See [the contract](../../STABLE_SORT_DTYPES.md).
Python scalar argsort now exposes the existing native/C `[0]` behavior.

The repository now includes the [MIT license](../../../LICENSE), copyright
2026 Lynn Cole. MIT was already declared in package metadata; the missing full
license text is now included and verified in the source archive and installed
wheel contents.

## Validation

Final source `2ff58eb`, feature commit `5bf5433`, license commit `4710896`.
GNU 13/14 and Flang 19 debug/release each pass 40 native programs, 6,045 Python
tests, two examples and the C caller. This includes 580 new sorting cases plus
five installed-package cases. ASan passes native leak checks and 3,374 C/Python
tests; the integer-overflow gate and 961 separate UBSan sort/package tests pass.
fpm, the complete OpenBLAS run, and 381 isolated source-package installation
tests pass. MIT metadata/license inclusion was checked after installation.
The [validation manifest](../../validation/sort-dtypes-2026-10-28.json) records
log paths, hashes and results.

Tests cover insertion/merge boundaries, repeated keys, exact integer extremes,
float32/64 signed zeros and distinct NaN payloads, C/F and signed/zero strides,
scalar/empty behavior, invalid axes, source preservation, output lifetime,
noncanonical native bool bytes, malformed bounds and result/workspace overflow.

## Implementation and memory tradeoff

The existing float64 value-buffer merge kernel is retained. Its release object
hash matches the baseline exactly. The four new dtypes share an index merge
sort: 32-element stable insertion runs, ordered-run skipping and lazy merge
workspace. Comparisons read the original source; sort gathers original typed
values afterward. Integer keys never pass through floating point. Float32 keys
widen exactly for comparison, but original result bits are copied unchanged.

For N total elements and axis length L, new-dtype argsort uses its 8N-byte result
plus 8L bytes for slice indices and up to 8L more for merge workspace. Sort adds
an 8N-byte full index temporary to its dtype-sized output and those slice buffers.
Small metadata overhead is additional. Float64 keeps its existing value/index
workspace. These are algorithmic payload sizes, not measured allocator totals.

The shared index approach provides bounded, tested functionality without four
copies of the old sorting module. It has an explicit cost: indirect comparisons
and the final gather make float32 sorting slower than the established float64
kernel on these inputs. Smaller dtype storage does not imply faster sorting.
No full-input value cast or packing buffer is introduced.

## Measurement method

GNU 14 release, `-std=f2018 -O3 -fimplicit-none`, no fast-math. CPU 0 affinity,
thread counts one, no concurrent Frumpy build/test jobs. Seven warmed samples
per case. C/Python/NumPy wall and CPU timings use calibrated batches capped at
1,000 calls; native CPU-time batches use 20 calls, or 1,000 for 32 elements.
Setup/import/export and oracle construction are untimed; allocating results and
release are timed. C includes ctypes dispatch. NumPy 2.4.6 uses `kind='stable'`.
Equivalent stable semantics do not imply the same sorting algorithm.

Two interface rounds reverse both case/interface order and baseline/final build
order. Ranges below are the two per-run wall medians, not confidence intervals.
Native columns are medians of seven CPU-time batches and should not be used to
subtract exact wrapper overhead from separately timed interface runs.

Numeric random-pattern data are `(37*i % 257)-128`; duplicate-heavy data are
`i % 5-2`. Bool alternates False/True. Sorted/reversed inputs derive from sorted
copies of those same patterns. Stepped data use a doubled backing extent and
step two; matrix cases are 64×128 F order or last-axis reversed duplicate data.
Native and interface drivers use the same values/layouts and sort the last axis.
Timed floating data are finite; NaN payload/stability behavior is validated in tests.

The baseline library is `cba383e` (unchanged through pre-slice `e650d77`) and
supports only float64 sorting. Thus only float64 has a before/after control;
other rows are new functionality baselines. Initial measurements under `initial/`
retain the first implementation's extra float64 argsort validation. The final
dispatch delegates directly to the existing validating float64 kernel.

## 8,192-element random-pattern vectors

All times are microseconds. Native and interface measurements are separate runs.

| Dtype | Operation | Native | C | Python | NumPy |
|---|---|---:|---:|---:|---:|
| bool | sort | 535.60 | 516.68–535.07 | 538.21–542.30 | 24.20–24.48 |
| bool | argsort | 442.55 | 436.48–729.84 | 450.42–778.54 | 28.17–35.09 |
| int32 | sort | 719.70 | 749.18–769.26 | 756.22–789.39 | 90.49–92.64 |
| int32 | argsort | 658.60 | 651.71–695.37 | 668.81–693.33 | 105.72–109.76 |
| int64 | sort | 740.30 | 756.40–762.42 | 770.81–774.15 | 95.59–96.86 |
| int64 | argsort | 654.45 | 678.59–680.83 | 697.49–710.38 | 109.94–111.54 |
| float32 | sort | 759.60 | 790.66–825.56 | 813.30–871.16 | 119.64–134.29 |
| float32 | argsort | 663.40 | 682.97–685.00 | 700.67–720.96 | 144.25–145.62 |
| float64 | sort | 286.85 | 203.10–217.93 | 214.63–221.75 | 123.84–124.79 |
| float64 | argsort | 304.55 | 215.30–223.41 | 223.41–244.13 | 145.67–158.65 |

## Review findings

- Float32 random-pattern sort at 8,192 elements takes 813–871 µs through
  Python, versus 215–222 µs for the established float64 kernel and 120–134 µs
  for NumPy float32. This slice adds functionality; it is not a speed upgrade.
- Ordered-run skipping works: sorted float32 input takes 181–186 µs through
  Python. F-order 64×128 row sorts take 571–588 µs. The indirect-key comparison
  and full-index gather costs remain worthwhile future profiling targets.
- The bool argsort full-run outlier (779 µs Python) was not reproduced in the
  isolated rechecks below (447–475 µs). Both original and recheck samples remain.
- Tiny float64 argsort retains a dispatch cost despite removing duplicate
  validation: paired isolated Python rechecks are about 5–11% slower, adding
  0.5–1.1 µs. C/ctypes adds 0.3–0.8 µs (12–31%). The core sorting object is
  unchanged, but the new generic dispatch/result-transfer path is additional
  work. This limitation is explicit; no broad performance-equivalence claim
  is made. Further optimization is deferred for review.

## Isolated rechecks

Microseconds; two runs with reversed case/build order. Baseline has no bool sort.

| Case | C baseline | C final | Python baseline | Python final |
|---|---:|---:|---:|---:|
| bool argsort (8192,) | unsupported | 426.98–508.63 | unsupported | 446.93–474.92 |
| float64 argsort (32,) | 2.51–2.53 | 2.82–3.32 | 10.32–10.54 | 10.84–11.68 |

## All interface cases

| Dtype | Operation | Shape | Layout | Distribution | C µs | Python µs | NumPy µs |
|---|---|---|---|---|---:|---:|---:|
| bool | sort | (32,) | C | random | 4.28–4.45 | 11.95–14.12 | 0.88–1.00 |
| bool | sort | (8192,) | C | random | 516.68–535.07 | 538.21–542.30 | 24.20–24.48 |
| bool | sort | (8192,) | C | sorted | 155.38–158.29 | 171.42–171.87 | 2.79–2.94 |
| bool | sort | (8192,) | C | reverse | 183.01–187.97 | 197.23–197.81 | 14.66–15.97 |
| bool | sort | (8192,) | C | duplicates | 525.38–548.95 | 528.77–560.56 | 24.18–25.94 |
| bool | sort | (8192,) | step | random | 154.54–155.46 | 165.64–165.77 | 4.46–4.51 |
| bool | sort | (64, 128) | F | random | 378.90–380.70 | 392.88–396.49 | 35.05–37.68 |
| bool | sort | (64, 128) | reverse | duplicates | 396.36–408.62 | 413.86–426.08 | 33.17–33.24 |
| bool | argsort | (32,) | C | random | 3.31–6.10 | 11.36–20.05 | 1.29–2.25 |
| bool | argsort | (8192,) | C | random | 436.48–729.84 | 450.42–778.54 | 28.17–35.09 |
| bool | argsort | (8192,) | C | sorted | 63.87–101.95 | 73.99–124.19 | 5.54–10.43 |
| bool | argsort | (8192,) | C | reverse | 91.21–149.47 | 167.03–170.65 | 14.61–28.75 |
| bool | argsort | (8192,) | C | duplicates | 451.15–759.47 | 454.46–798.35 | 29.30–34.06 |
| bool | argsort | (8192,) | step | random | 66.10–102.31 | 74.92–76.87 | 7.36–7.51 |
| bool | argsort | (64, 128) | F | random | 228.96–235.38 | 239.21–243.82 | 37.57–37.77 |
| bool | argsort | (64, 128) | reverse | duplicates | 242.05–250.82 | 254.14–256.49 | 37.84–38.61 |
| int32 | sort | (32,) | C | random | 4.73–4.74 | 12.67–13.06 | 0.80–0.87 |
| int32 | sort | (8192,) | C | random | 749.18–769.26 | 756.22–789.39 | 90.49–92.64 |
| int32 | sort | (8192,) | C | sorted | 158.91–163.42 | 170.37–172.03 | 3.17–3.30 |
| int32 | sort | (8192,) | C | reverse | 559.70–569.49 | 574.81–598.77 | 71.95–77.78 |
| int32 | sort | (8192,) | C | duplicates | 742.74–748.46 | 713.30–735.17 | 72.97–75.55 |
| int32 | sort | (8192,) | step | random | 770.62–781.98 | 806.48–826.78 | 101.42–102.81 |
| int32 | sort | (64, 128) | F | random | 544.45–551.61 | 558.19–564.48 | 71.02–75.91 |
| int32 | sort | (64, 128) | reverse | duplicates | 518.09–545.10 | 552.46–581.28 | 55.86–56.42 |
| int32 | argsort | (32,) | C | random | 3.76–6.65 | 11.79–21.87 | 1.14–2.05 |
| int32 | argsort | (8192,) | C | random | 651.71–695.37 | 668.81–693.33 | 105.72–109.76 |
| int32 | argsort | (8192,) | C | sorted | 63.58–66.38 | 74.12–74.74 | 5.13–5.53 |
| int32 | argsort | (8192,) | C | reverse | 458.86–461.60 | 472.67–472.71 | 93.07–107.70 |
| int32 | argsort | (8192,) | C | duplicates | 611.62–637.12 | 614.34–628.81 | 85.94–86.84 |
| int32 | argsort | (8192,) | step | random | 681.50–682.74 | 693.10–694.00 | 118.20–118.96 |
| int32 | argsort | (64, 128) | F | random | 386.34–389.05 | 405.77–411.83 | 87.72–89.57 |
| int32 | argsort | (64, 128) | reverse | duplicates | 382.92–392.18 | 391.88–394.10 | 70.45–72.07 |
| int64 | sort | (32,) | C | random | 4.69–5.17 | 12.46–12.69 | 0.79–0.82 |
| int64 | sort | (8192,) | C | random | 756.40–762.42 | 770.81–774.15 | 95.59–96.86 |
| int64 | sort | (8192,) | C | sorted | 170.20–171.08 | 181.89–182.36 | 3.69–3.83 |
| int64 | sort | (8192,) | C | reverse | 568.43–590.52 | 591.91–606.30 | 77.33–114.34 |
| int64 | sort | (8192,) | C | duplicates | 732.30–1189.73 | 764.40–790.35 | 87.10–90.88 |
| int64 | sort | (8192,) | step | random | 813.16–838.67 | 807.53–820.77 | 105.11–117.76 |
| int64 | sort | (64, 128) | F | random | 539.56–549.45 | 559.39–563.17 | 87.27–102.01 |
| int64 | sort | (64, 128) | reverse | duplicates | 527.57–538.71 | 549.15–551.03 | 60.31–62.62 |
| int64 | argsort | (32,) | C | random | 3.68–3.70 | 11.74–11.98 | 1.09–2.12 |
| int64 | argsort | (8192,) | C | random | 678.59–680.83 | 697.49–710.38 | 109.94–111.54 |
| int64 | argsort | (8192,) | C | sorted | 63.64–64.14 | 73.48–74.66 | 5.45–5.60 |
| int64 | argsort | (8192,) | C | reverse | 458.49–467.66 | 466.17–480.47 | 92.14–115.73 |
| int64 | argsort | (8192,) | C | duplicates | 603.23–625.82 | 618.11–673.63 | 87.93–93.76 |
| int64 | argsort | (8192,) | step | random | 678.20–711.46 | 699.64–705.66 | 120.43–120.84 |
| int64 | argsort | (64, 128) | F | random | 394.42–399.09 | 409.03–419.87 | 91.11–92.38 |
| int64 | argsort | (64, 128) | reverse | duplicates | 376.92–382.87 | 392.14–393.74 | 69.62–71.09 |
| float32 | sort | (32,) | C | random | 4.83–4.92 | 12.79–13.43 | 0.81–0.84 |
| float32 | sort | (8192,) | C | random | 790.66–825.56 | 813.30–871.16 | 119.64–134.29 |
| float32 | sort | (8192,) | C | sorted | 166.96–169.82 | 180.62–186.18 | 5.00–5.66 |
| float32 | sort | (8192,) | C | reverse | 575.11–988.56 | 588.62–594.28 | 83.23–90.37 |
| float32 | sort | (8192,) | C | duplicates | 730.25–742.28 | 744.59–750.52 | 93.44–93.58 |
| float32 | sort | (8192,) | step | random | 806.89–817.18 | 837.88–883.54 | 132.71–141.64 |
| float32 | sort | (64, 128) | F | random | 561.70–578.76 | 570.74–587.88 | 91.88–94.03 |
| float32 | sort | (64, 128) | reverse | duplicates | 553.92–555.52 | 565.42–577.79 | 72.96–73.28 |
| float32 | argsort | (32,) | C | random | 3.70–3.90 | 11.48–11.90 | 1.09–1.10 |
| float32 | argsort | (8192,) | C | random | 682.97–685.00 | 700.67–720.96 | 144.25–145.62 |
| float32 | argsort | (8192,) | C | sorted | 65.04–66.54 | 77.03–80.68 | 8.69–8.76 |
| float32 | argsort | (8192,) | C | reverse | 483.46–488.20 | 496.15–502.07 | 110.56–165.04 |
| float32 | argsort | (8192,) | C | duplicates | 633.23–670.57 | 670.16–672.19 | 110.05–111.85 |
| float32 | argsort | (8192,) | step | random | 712.90–723.76 | 743.28–746.70 | 158.02–163.82 |
| float32 | argsort | (64, 128) | F | random | 416.49–443.74 | 426.29–436.98 | 109.47–112.48 |
| float32 | argsort | (64, 128) | reverse | duplicates | 401.44–430.69 | 434.31–460.31 | 88.21–92.27 |
| float64 | sort | (32,) | C | random | 2.71–3.35 | 10.49–10.50 | 0.80–0.82 |
| float64 | sort | (8192,) | C | random | 203.10–217.93 | 214.63–221.75 | 123.84–124.79 |
| float64 | sort | (8192,) | C | sorted | 41.75–42.13 | 50.95–51.40 | 7.35–7.56 |
| float64 | sort | (8192,) | C | reverse | 187.33–221.56 | 198.77–202.02 | 86.22–129.67 |
| float64 | sort | (8192,) | C | duplicates | 193.17–198.90 | 210.91–224.72 | 97.87–99.63 |
| float64 | sort | (8192,) | step | random | 211.85–220.41 | 218.10–223.24 | 132.04–141.05 |
| float64 | sort | (64, 128) | F | random | 143.33–144.98 | 155.38–156.82 | 103.66–103.85 |
| float64 | sort | (64, 128) | reverse | duplicates | 135.49–138.18 | 146.95–149.43 | 73.75–74.48 |
| float64 | argsort | (32,) | C | random | 2.95–3.01 | 10.65–11.42 | 1.26–1.35 |
| float64 | argsort | (8192,) | C | random | 215.30–223.41 | 223.41–244.13 | 145.67–158.65 |
| float64 | argsort | (8192,) | C | sorted | 43.39–48.14 | 54.88–57.55 | 9.70–9.75 |
| float64 | argsort | (8192,) | C | reverse | 195.32–198.07 | 202.77–203.41 | 103.30–123.93 |
| float64 | argsort | (8192,) | C | duplicates | 190.66–199.23 | 205.27–206.30 | 112.15–112.71 |
| float64 | argsort | (8192,) | step | random | 216.01–216.61 | 228.36–246.04 | 164.19–167.44 |
| float64 | argsort | (64, 128) | F | random | 149.48–151.08 | 157.98–159.40 | 111.20–111.52 |
| float64 | argsort | (64, 128) | reverse | duplicates | 136.99–138.97 | 147.84–148.23 | 86.03–87.61 |

## Float64 compatibility/performance control

The sorting kernel object is byte-identical to baseline; generic dispatch and
validation paths can still affect small-call latency. All measurements below
are retained, including slower medians. Do not interpret overlapping ranges as
proof of exact performance equivalence.

| Operation | Shape | Layout | Distribution | C before | C after | Python before | Python after |
|---|---|---|---|---:|---:|---:|---:|
| sort | (32,) | C | random | 3.41–4.90 | 2.71–3.35 | 11.49–22.00 | 10.49–10.50 |
| sort | (8192,) | C | random | 238.50–371.83 | 203.10–217.93 | 244.97–400.43 | 214.63–221.75 |
| sort | (8192,) | C | sorted | 44.02–44.16 | 41.75–42.13 | 51.63–59.98 | 50.95–51.40 |
| sort | (8192,) | C | reverse | 180.64–189.91 | 187.33–221.56 | 190.18–203.07 | 198.77–202.02 |
| sort | (8192,) | C | duplicates | 190.16–197.42 | 193.17–198.90 | 200.83–206.16 | 210.91–224.72 |
| sort | (8192,) | step | random | 209.04–212.97 | 211.85–220.41 | 219.98–239.51 | 218.10–223.24 |
| sort | (64, 128) | F | random | 144.19–144.22 | 143.33–144.98 | 155.83–158.88 | 155.38–156.82 |
| sort | (64, 128) | reverse | duplicates | 136.21–136.50 | 135.49–138.18 | 146.28–148.45 | 146.95–149.43 |
| argsort | (32,) | C | random | 2.61–2.80 | 2.95–3.01 | 10.29–10.36 | 10.65–11.42 |
| argsort | (8192,) | C | random | 201.68–217.73 | 215.30–223.41 | 217.42–223.10 | 223.41–244.13 |
| argsort | (8192,) | C | sorted | 42.71–44.03 | 43.39–48.14 | 51.81–53.44 | 54.88–57.55 |
| argsort | (8192,) | C | reverse | 187.43–201.64 | 195.32–198.07 | 196.96–198.42 | 202.77–203.41 |
| argsort | (8192,) | C | duplicates | 193.03–209.63 | 190.66–199.23 | 207.28–212.39 | 205.27–206.30 |
| argsort | (8192,) | step | random | 214.99–220.94 | 216.01–216.61 | 226.18–278.38 | 228.36–246.04 |
| argsort | (64, 128) | F | random | 153.98–158.54 | 149.48–151.08 | 162.52–164.38 | 157.98–159.40 |
| argsort | (64, 128) | reverse | duplicates | 138.58–139.36 | 136.99–138.97 | 150.43–154.16 | 147.84–148.23 |

## Native cases

Case IDs: 1 = 32 random-pattern C elements; 2 = 8,192 random C;
3 = sorted C; 4 = reversed C; 5 = duplicate-heavy C; 6 = step-two random;
7 = random F-order 64×128, axis -1; 8 = duplicate-heavy 64×128 with reversed
last-axis view. Cases 2–8 contain 8,192 logical elements.

| Dtype | Operation | Case | Native µs |
|---|---|---:|---:|
| bool | sort | 1 | 2.66 |
| int32 | sort | 1 | 3.02 |
| int64 | sort | 1 | 3.14 |
| float32 | sort | 1 | 3.07 |
| float64 | sort | 1 | 1.10 |
| bool | sort | 2 | 535.60 |
| int32 | sort | 2 | 719.70 |
| int64 | sort | 2 | 740.30 |
| float32 | sort | 2 | 759.60 |
| float64 | sort | 2 | 286.85 |
| bool | sort | 3 | 149.85 |
| int32 | sort | 3 | 150.90 |
| int64 | sort | 3 | 163.40 |
| float32 | sort | 3 | 150.95 |
| float64 | sort | 3 | 76.10 |
| bool | sort | 4 | 212.25 |
| int32 | sort | 4 | 542.10 |
| int64 | sort | 4 | 561.10 |
| float32 | sort | 4 | 563.15 |
| float64 | sort | 4 | 266.05 |
| bool | sort | 5 | 539.25 |
| int32 | sort | 5 | 725.90 |
| int64 | sort | 5 | 832.10 |
| float32 | sort | 5 | 712.90 |
| float64 | sort | 5 | 267.30 |
| bool | sort | 6 | 153.60 |
| int32 | sort | 6 | 754.25 |
| int64 | sort | 6 | 783.10 |
| float32 | sort | 6 | 804.60 |
| float64 | sort | 6 | 289.65 |
| bool | sort | 7 | 359.60 |
| int32 | sort | 7 | 500.85 |
| int64 | sort | 7 | 496.55 |
| float32 | sort | 7 | 519.15 |
| float64 | sort | 7 | 139.25 |
| bool | sort | 8 | 374.25 |
| int32 | sort | 8 | 488.35 |
| int64 | sort | 8 | 491.30 |
| float32 | sort | 8 | 511.00 |
| float64 | sort | 8 | 133.00 |
| bool | argsort | 1 | 1.69 |
| int32 | argsort | 1 | 2.01 |
| int64 | argsort | 1 | 2.07 |
| float32 | argsort | 1 | 2.12 |
| float64 | argsort | 1 | 1.28 |
| bool | argsort | 2 | 442.55 |
| int32 | argsort | 2 | 658.60 |
| int64 | argsort | 2 | 654.45 |
| float32 | argsort | 2 | 663.40 |
| float64 | argsort | 2 | 304.55 |
| bool | argsort | 3 | 61.75 |
| int32 | argsort | 3 | 60.70 |
| int64 | argsort | 3 | 59.00 |
| float32 | argsort | 3 | 58.80 |
| float64 | argsort | 3 | 75.65 |
| bool | argsort | 4 | 119.70 |
| int32 | argsort | 4 | 465.00 |
| int64 | argsort | 4 | 462.30 |
| float32 | argsort | 4 | 467.15 |
| float64 | argsort | 4 | 270.10 |
| bool | argsort | 5 | 439.55 |
| int32 | argsort | 5 | 612.35 |
| int64 | argsort | 5 | 599.15 |
| float32 | argsort | 5 | 616.15 |
| float64 | argsort | 5 | 277.85 |
| bool | argsort | 6 | 60.65 |
| int32 | argsort | 6 | 670.75 |
| int64 | argsort | 6 | 663.25 |
| float32 | argsort | 6 | 721.35 |
| float64 | argsort | 6 | 299.55 |
| bool | argsort | 7 | 217.75 |
| int32 | argsort | 7 | 355.50 |
| int64 | argsort | 7 | 349.00 |
| float32 | argsort | 7 | 381.75 |
| float64 | argsort | 7 | 145.65 |
| bool | argsort | 8 | 223.55 |
| int32 | argsort | 8 | 340.10 |
| int64 | argsort | 8 | 346.55 |
| float32 | argsort | 8 | 365.20 |
| float64 | argsort | 8 | 136.55 |

## Reproduce and evidence

Build/validate a GNU 14 release directory, compile
`benchmarks/benchmark_sort_dtypes.f90` against its core objects/module directory,
and run the resulting executable with `taskset -c 0`. Set `FRUMPY_LIBRARY` to
that build's shared library, `PYTHONPATH=python`, and both thread environment
variables `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1`:

```sh
.venv/bin/python benchmarks/compare_sort_dtypes.py --source-commit 2ff58eb --output after.json
.venv/bin/python benchmarks/compare_sort_dtypes.py --source-commit 2ff58eb --reverse --output after-reverse.json
```

For the preserved pre-slice library, add `--only-float64` and use source commit
`cba383e`. [Native samples](native.txt), [first interface round](after-1.json),
[reverse round](after-2.json), [baseline round one](baseline-1.json) and
[baseline round two](baseline-2.json) retain raw samples. [Provenance](provenance.json)
records binary/source hashes and host details. The optional `--review-cases`
filter was added after the kernel commit and is included in the benchmark-source
hash; it only selects the isolated recheck cases. This is functionality coverage,
not a universal speed improvement or a promise of NumPy parity.
