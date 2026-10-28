# Argmin/argmax baseline — 2026-10-27

The five-dtype implementation is complete across native Fortran, C and Python.
All results match the selected NumPy contracts. This is a functionality baseline;
the prior revision had no argmin/argmax implementation, so there is no meaningful
before/after speedup to report.

## Contract and validation

See [the contract](../../ARG_REDUCTIONS.md): always int64 indices, C-logical
flattening by default, one optional axis, keepdims, first tie and first NaN.
Integer comparisons remain exact. Float32 values widen exactly for comparison;
there is no accumulation or precision/performance tradeoff. Signed/zero strides
and irregular layouts are supported without a full-input copy.

GNU 13/14 and Flang 19 debug/release profiles each pass 39 native programs,
5,386 Python tests, two examples and the standalone C caller. ASan passes native
leak checks and 2,715 C/Python tests. The overflow gate passes; a separate UBSan
build passes 1,096 arg/package tests. fpm, 376 isolated installed-package tests,
and the full 5,386-test OpenBLAS run pass. See the
[validation manifest](../../validation/arg-reductions-2026-10-27.json).

## Measurement method

Source/kernel revision `836a5a4`; GNU 14 release, `-std=f2018 -O3 -fimplicit-none`,
no fast-math. CPU 0 affinity, thread counts one, validation/build jobs stopped.
Native records seven CPU-time batches; C/Python/NumPy record seven warmed wall
and process-CPU batches, calibrated toward 30 ms and capped at 1,000 calls.
Both interface runs use identical inputs; the second reverses case and interface
order. Tables show the range of the two per-run wall-time medians in microseconds,
not confidence intervals. Native columns are single-run seven-sample medians.
Imports, exports, input construction and correctness comparisons are outside
timing; result allocation and release are timed. Raw C includes ctypes overhead.
NumPy is 2.4.6. These reductions do not call BLAS/LAPACK.

Numeric input at one-based storage position i is `(37*i % 257)-128`, exactly
representable in all four numeric dtypes. Bool alternates True/False. Native and
interface vector cases use the same data. Step-two bool input is consequently
all True. Timed inputs contain no NaNs: early NaNs would measure shorter work.
NumPy can terminate bool searches at the first matching extreme; Frumpy currently
scans the full reduction. That is a real algorithmic difference, not equal work.

Only the independent int64 output payload is allocated (8 bytes per index), plus
small descriptor/handle metadata. No flattened/cast input temporary is used.

## Findings

- Float32 contiguous 65,536-element argmin: native 162 µs, C 168–172 µs,
  Python 179–180 µs, NumPy 4.5–5.0 µs. The kernel dominates the large-call gap.
- Float32 step-two/reversed vectors remain about 179–183 µs through Python;
  NumPy takes about 20–21 µs. Constant-step addressing avoids the general offset
  calculation but does not remove per-element typed access and comparisons.
- Float32 128×128 F-order flattening takes 167–179 µs through Python despite
  containing only one quarter as many elements. Logical C-order offset traversal
  adds significant cost. Matrix-axis reductions take about 54–61 µs through Python.
- Tiny float32 argmin takes 9.9–10.3 µs through Python, 2.8 µs through C,
  versus NumPy 0.9 µs. Wrapper/metadata costs dominate here.
- Bool's large gap is particularly sensitive to early-exit opportunities. Do not
  extrapolate the alternating-input ratio to every bool distribution.

A focused optimization pass would be justified if these reductions matter to
real workloads: dispatch dtype/operation outside the scan, use concrete typed
loops for constant-stride inputs, then consider bool early termination and an
incremental offset iterator for irregular flattening. Preserve first ties/NaNs
and exact int64 comparisons. There is no correctness blocker to continuing
functionality instead; avoid broad wrapper optimization before the scan costs.

## Noisy cases retained and rechecked

The first int64 contiguous argmin run was 288 µs C / 304 µs Python, compared
with 158 / 179 µs in reverse order. F-order float32 flattening also had a slower
C measurement (207 versus 157 µs). These original samples remain in the tables
and JSON. The isolated recheck below supports treating the large spread as
run variability, not a proven dtype-specific regression. Bool argmin was also
rechecked because its Python run medians varied.

| Isolated argmin recheck | C µs | Python µs | NumPy µs |
|---|---:|---:|---:|
| bool [65536] C | 160.10 | 180.60 | 0.88 |
| int64 [65536] C | 153.79 | 168.71 | 8.19 |
| float32 [128, 128] F | 158.78 | 168.20 | 15.82 |

## All interface measurements

| Dtype | Operation | Shape | Axis | Layout | C µs | Python µs | NumPy µs |
|---|---|---|---|---|---:|---:|---:|
| bool | argmin | [16] | None | C | 2.75–2.86 | 9.87–11.50 | 0.88–0.97 |
| bool | argmin | [65536] | None | C | 149.49–150.25 | 147.95–183.51 | 0.89–1.01 |
| bool | argmin | [65536] | None | step | 135.88–139.31 | 148.86–154.59 | 16.37–16.59 |
| bool | argmin | [65536] | None | reverse | 139.58–148.71 | 149.18–160.58 | 16.06–16.10 |
| bool | argmin | [128, 128] | None | F | 121.70–121.99 | 130.49–130.70 | 5.31–5.37 |
| bool | argmin | [128, 128] | 0 | C | 37.74–38.46 | 46.80–49.33 | 5.73–5.80 |
| bool | argmin | [128, 128] | 1 | C | 36.91–38.75 | 44.85–47.41 | 1.26–1.50 |
| bool | argmin | [128, 128] | 1 | F | 37.13–37.32 | 45.18–50.43 | 5.27–5.37 |
| bool | argmax | [16] | None | C | 2.75–2.79 | 9.71–9.74 | 0.89–0.92 |
| bool | argmax | [65536] | None | C | 120.41–129.89 | 128.12–133.35 | 0.87–0.90 |
| bool | argmax | [65536] | None | step | 121.54–129.55 | 127.68–140.88 | 15.88–16.27 |
| bool | argmax | [65536] | None | reverse | 124.08–124.92 | 134.55–141.37 | 15.72–15.95 |
| bool | argmax | [128, 128] | None | F | 118.95–123.66 | 127.75–131.49 | 5.24–5.52 |
| bool | argmax | [128, 128] | 0 | C | 33.39–33.48 | 41.60–41.94 | 5.37–5.50 |
| bool | argmax | [128, 128] | 1 | C | 33.15–33.57 | 41.46–41.52 | 1.22–1.26 |
| bool | argmax | [128, 128] | 1 | F | 33.19–34.44 | 42.38–43.42 | 5.36–5.48 |
| int32 | argmin | [16] | None | C | 2.88–2.88 | 10.07–10.52 | 0.91–0.95 |
| int32 | argmin | [65536] | None | C | 153.87–165.03 | 164.43–167.06 | 3.60–4.12 |
| int32 | argmin | [65536] | None | step | 158.53–218.43 | 168.95–172.04 | 20.14–21.84 |
| int32 | argmin | [65536] | None | reverse | 150.47–157.15 | 160.46–162.17 | 19.57–19.59 |
| int32 | argmin | [128, 128] | None | F | 121.03–122.16 | 129.75–130.42 | 15.59–15.85 |
| int32 | argmin | [128, 128] | 0 | C | 41.30–41.80 | 49.86–53.85 | 16.19–16.30 |
| int32 | argmin | [128, 128] | 1 | C | 42.49–44.69 | 51.90–53.55 | 2.31–2.37 |
| int32 | argmin | [128, 128] | 1 | F | 42.92–44.05 | 51.49–51.92 | 16.30–16.70 |
| int32 | argmax | [16] | None | C | 2.80–2.85 | 10.01–11.13 | 0.89–1.18 |
| int32 | argmax | [65536] | None | C | 137.27–139.23 | 150.20–150.82 | 3.84–4.28 |
| int32 | argmax | [65536] | None | step | 137.34–146.80 | 146.36–161.42 | 20.60–21.95 |
| int32 | argmax | [65536] | None | reverse | 138.22–145.08 | 146.66–232.13 | 19.49–20.01 |
| int32 | argmax | [128, 128] | None | F | 121.85–122.24 | 126.87–128.03 | 15.67–16.18 |
| int32 | argmax | [128, 128] | 0 | C | 38.67–39.06 | 46.87–48.55 | 16.22–16.32 |
| int32 | argmax | [128, 128] | 1 | C | 38.18–38.39 | 46.66–47.44 | 2.33–2.37 |
| int32 | argmax | [128, 128] | 1 | F | 39.07–40.47 | 47.57–49.31 | 16.74–17.33 |
| int64 | argmin | [16] | None | C | 3.40–5.22 | 13.76–18.39 | 0.92–1.84 |
| int64 | argmin | [65536] | None | C | 157.79–288.34 | 178.63–303.93 | 7.56–10.66 |
| int64 | argmin | [65536] | None | step | 154.61–246.28 | 180.35–310.31 | 24.50–26.59 |
| int64 | argmin | [65536] | None | reverse | 150.46–169.43 | 163.95–202.14 | 23.74–25.55 |
| int64 | argmin | [128, 128] | None | F | 120.63–152.36 | 126.91–141.87 | 17.88–19.15 |
| int64 | argmin | [128, 128] | 0 | C | 41.35–42.94 | 51.19–51.99 | 18.05–18.25 |
| int64 | argmin | [128, 128] | 1 | C | 43.87–44.82 | 52.87–53.98 | 2.73–2.87 |
| int64 | argmin | [128, 128] | 1 | F | 44.99–78.80 | 57.11–67.31 | 18.26–19.46 |
| int64 | argmax | [16] | None | C | 2.79–3.32 | 10.44–11.11 | 0.92–0.94 |
| int64 | argmax | [65536] | None | C | 137.30–137.77 | 151.90–152.78 | 7.57–8.40 |
| int64 | argmax | [65536] | None | step | 136.77–137.41 | 146.32–147.88 | 24.41–24.50 |
| int64 | argmax | [65536] | None | reverse | 135.72–137.76 | 144.61–146.82 | 24.35–24.56 |
| int64 | argmax | [128, 128] | None | F | 123.21–123.98 | 131.47–139.99 | 18.55–18.89 |
| int64 | argmax | [128, 128] | 0 | C | 41.23–61.41 | 50.60–61.32 | 19.06–20.84 |
| int64 | argmax | [128, 128] | 1 | C | 38.96–73.96 | 47.67–92.07 | 2.73–5.15 |
| int64 | argmax | [128, 128] | 1 | F | 38.52–40.00 | 47.45–93.36 | 18.32–18.53 |
| float32 | argmin | [16] | None | C | 2.76–2.81 | 9.92–10.28 | 0.89–0.94 |
| float32 | argmin | [65536] | None | C | 167.69–172.15 | 178.81–179.89 | 4.49–4.99 |
| float32 | argmin | [65536] | None | step | 168.41–169.25 | 178.95–180.91 | 20.47–21.35 |
| float32 | argmin | [65536] | None | reverse | 167.12–170.57 | 181.93–182.65 | 20.36–20.47 |
| float32 | argmin | [128, 128] | None | F | 157.21–207.42 | 166.51–179.14 | 15.95–16.69 |
| float32 | argmin | [128, 128] | 0 | C | 44.52–45.70 | 54.34–55.63 | 16.52–16.68 |
| float32 | argmin | [128, 128] | 1 | C | 43.65–45.97 | 55.36–57.56 | 2.43–2.48 |
| float32 | argmin | [128, 128] | 1 | F | 45.60–45.82 | 54.15–60.85 | 16.54–16.96 |
| float32 | argmax | [16] | None | C | 2.76–2.84 | 9.78–9.86 | 0.89–0.91 |
| float32 | argmax | [65536] | None | C | 168.36–170.46 | 180.48–182.62 | 4.38–4.58 |
| float32 | argmax | [65536] | None | step | 167.01–170.67 | 176.39–182.95 | 20.46–21.25 |
| float32 | argmax | [65536] | None | reverse | 168.03–172.55 | 179.44–180.70 | 20.22–20.80 |
| float32 | argmax | [128, 128] | None | F | 128.33–131.37 | 137.97–141.56 | 15.81–16.03 |
| float32 | argmax | [128, 128] | 0 | C | 45.30–51.58 | 53.62–54.29 | 16.62–17.61 |
| float32 | argmax | [128, 128] | 1 | C | 45.92–46.05 | 54.59–55.22 | 2.42–2.77 |
| float32 | argmax | [128, 128] | 1 | F | 44.20–44.26 | 52.94–53.41 | 16.27–16.54 |
| float64 | argmin | [16] | None | C | 2.77–2.81 | 9.73–10.08 | 0.91–0.92 |
| float64 | argmin | [65536] | None | C | 165.14–175.26 | 173.80–174.33 | 9.14–9.15 |
| float64 | argmin | [65536] | None | step | 169.85–173.18 | 181.26–193.02 | 26.80–26.86 |
| float64 | argmin | [65536] | None | reverse | 167.03–174.47 | 177.09–191.43 | 25.88–26.91 |
| float64 | argmin | [128, 128] | None | F | 155.66–157.26 | 164.78–173.60 | 18.97–18.99 |
| float64 | argmin | [128, 128] | 0 | C | 44.45–46.33 | 54.32–58.12 | 18.63–19.58 |
| float64 | argmin | [128, 128] | 1 | C | 44.15–45.06 | 52.52–53.45 | 3.14–3.28 |
| float64 | argmin | [128, 128] | 1 | F | 44.69–44.80 | 53.31–55.28 | 18.57–18.63 |
| float64 | argmax | [16] | None | C | 2.70–2.80 | 10.07–10.46 | 0.87–0.88 |
| float64 | argmax | [65536] | None | C | 164.48–170.24 | 174.17–177.75 | 8.27–9.01 |
| float64 | argmax | [65536] | None | step | 165.76–168.27 | 175.11–176.53 | 25.00–25.70 |
| float64 | argmax | [65536] | None | reverse | 164.18–165.64 | 173.80–174.28 | 23.71–24.88 |
| float64 | argmax | [128, 128] | None | F | 135.37–137.34 | 138.83–139.93 | 18.59–22.65 |
| float64 | argmax | [128, 128] | 0 | C | 45.55–47.14 | 54.12–56.10 | 18.60–18.94 |
| float64 | argmax | [128, 128] | 1 | C | 43.87–44.49 | 53.75–54.74 | 3.03–3.08 |
| float64 | argmax | [128, 128] | 1 | F | 44.84–45.04 | 53.79–55.22 | 18.11–18.78 |

## Native vector measurements

| Dtype | Operation | Elements | Layout | Native µs |
|---|---|---:|---|---:|
| bool | argmin | 16 | C | 1.78 |
| int32 | argmin | 16 | C | 1.48 |
| int64 | argmin | 16 | C | 1.82 |
| float32 | argmin | 16 | C | 1.80 |
| float64 | argmin | 16 | C | 1.70 |
| bool | argmin | 16 | step | 1.05 |
| int32 | argmin | 16 | step | 1.01 |
| int64 | argmin | 16 | step | 1.06 |
| float32 | argmin | 16 | step | 0.98 |
| float64 | argmin | 16 | step | 1.00 |
| bool | argmin | 16 | reverse | 0.99 |
| int32 | argmin | 16 | reverse | 0.99 |
| int64 | argmin | 16 | reverse | 0.99 |
| float32 | argmin | 16 | reverse | 0.99 |
| float64 | argmin | 16 | reverse | 0.98 |
| bool | argmin | 65536 | C | 132.78 |
| int32 | argmin | 65536 | C | 146.35 |
| int64 | argmin | 65536 | C | 145.89 |
| float32 | argmin | 65536 | C | 161.93 |
| float64 | argmin | 65536 | C | 160.21 |
| bool | argmin | 65536 | step | 133.24 |
| int32 | argmin | 65536 | step | 147.33 |
| int64 | argmin | 65536 | step | 148.79 |
| float32 | argmin | 65536 | step | 162.75 |
| float64 | argmin | 65536 | step | 162.43 |
| bool | argmin | 65536 | reverse | 133.50 |
| int32 | argmin | 65536 | reverse | 147.33 |
| int64 | argmin | 65536 | reverse | 148.02 |
| float32 | argmin | 65536 | reverse | 160.92 |
| float64 | argmin | 65536 | reverse | 166.13 |
| bool | argmax | 16 | C | 0.99 |
| int32 | argmax | 16 | C | 0.98 |
| int64 | argmax | 16 | C | 1.00 |
| float32 | argmax | 16 | C | 0.99 |
| float64 | argmax | 16 | C | 0.99 |
| bool | argmax | 16 | step | 1.00 |
| int32 | argmax | 16 | step | 0.99 |
| int64 | argmax | 16 | step | 0.98 |
| float32 | argmax | 16 | step | 0.99 |
| float64 | argmax | 16 | step | 1.01 |
| bool | argmax | 16 | reverse | 0.98 |
| int32 | argmax | 16 | reverse | 1.03 |
| int64 | argmax | 16 | reverse | 1.01 |
| float32 | argmax | 16 | reverse | 0.99 |
| float64 | argmax | 16 | reverse | 0.98 |
| bool | argmax | 65536 | C | 118.20 |
| int32 | argmax | 65536 | C | 133.82 |
| int64 | argmax | 65536 | C | 133.25 |
| float32 | argmax | 65536 | C | 160.50 |
| float64 | argmax | 65536 | C | 162.67 |
| bool | argmax | 65536 | step | 118.57 |
| int32 | argmax | 65536 | step | 135.38 |
| int64 | argmax | 65536 | step | 131.95 |
| float32 | argmax | 65536 | step | 160.86 |
| float64 | argmax | 65536 | step | 165.88 |
| bool | argmax | 65536 | reverse | 192.78 |
| int32 | argmax | 65536 | reverse | 163.51 |
| int64 | argmax | 65536 | reverse | 200.07 |
| float32 | argmax | 65536 | reverse | 167.93 |
| float64 | argmax | 65536 | reverse | 168.23 |

## Reproduce and evidence

Build/validate a release directory, then compile
`benchmarks/benchmark_arg_reductions.f90` against that directory's core objects
and module files. Run its executable with `taskset -c 0`. With `PYTHONPATH=python`
and `FRUMPY_LIBRARY` pointing to the release shared library:

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 .venv/bin/python benchmarks/compare_arg_reductions.py --output interfaces.json
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 .venv/bin/python benchmarks/compare_arg_reductions.py --reverse --output interfaces-reverse.json
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 .venv/bin/python benchmarks/compare_arg_reductions.py --focus --output recheck.json
```

Raw samples: [native](native.txt), [interfaces](interfaces.json),
[reverse-order interfaces](interfaces-reverse.json), [recheck](recheck.json).
[Machine and binary provenance](provenance.json) records hashes. The optional
`--focus` benchmark filter was added after the kernel commit; it changes only
case selection and is hashed separately. No kernel changes followed validation.
