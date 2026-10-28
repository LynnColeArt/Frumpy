# Focused argmin/argmax optimization — 2026-10-28

All five dtype contracts are preserved. The implementation now dispatches to
concrete typed scans, stops bool searches at their first absolute extreme, and
advances irregular C-logical coordinates/offsets incrementally. It never stops
a floating scan at infinity: a later NaN must still win. Float32 comparisons
remain exact without widening. No input packing or cast buffer is introduced.

The change is validated and the matched baseline/optimized builds are retained.
This report records slower/noisy cases as well as gains. Results apply to this
host and these distributions, not a general promise of NumPy parity.

## Validation

GNU 13/14 and Flang 19 debug/release: 39 native programs, 5,460 Python tests,
two examples and the C caller each pass. The 74 added scan/layout contract tests
also pass against the baseline. Native additions check noncanonical bool bytes.
ASan passes native leak checks and 2,789 C/Python cases; the overflow gate and a
separate 1,170-test UBSan run pass. fpm, 376 isolated installed-package tests and
the full OpenBLAS test run pass. See the
[validation manifest](../../validation/arg-optimization-2026-10-28.json).

Tests preserve first ties, first NaNs (including after infinity), signed zeros,
exact int64 comparisons, negative/zero/mixed strides, empty reductions, axes,
owned result lifetime and malformed descriptors. The incremental iterator
resets a completed dimension before carrying and is never advanced after the
final element, avoiding an overflowing one-past-end offset.

## Measurement method

Baseline kernel `836a5a4` (unchanged through pre-pass `b37482e`), optimized
kernel `cba383e`. GNU 14 `-std=f2018 -O3 -fimplicit-none`, no fast-math; pinned
CPU 0, single-thread environment, no concurrent validation/build jobs.
The same benchmark sources and input values run against both compiled cores.
C timings include ctypes dispatch; native timings use CPU time. Python/C/NumPy
record both wall and CPU samples. Input setup/import/export is untimed, while
result allocation/release is timed. These kernels do not call BLAS.

There are seven samples per case. Interface measurements are performed in
baseline/optimized then optimized/baseline order, with case/interface order
reversed in the second round. Reported ranges are the two wall-time medians,
not confidence intervals. Numeric inputs use the prior exactly representable
modular pattern; standard bool inputs alternate. Dedicated bool runs put the
first matching extreme at the first, middle or last position, or omit it.
All timed floating data are finite; early NaN behavior is tested separately.

Native vector and F-order cases use 16 or 65,536 elements (F-order shapes 4×4
or 256×256). Standard Python/C F-order cases use 128×128; dedicated bool F-order
cases use 256×256. Compare like-sized rows, rather than treating native and
interface matrix columns as identical workloads. Native reverse-order reruns
check the small-call variability separately.

No full-input temporary is allocated. Output remains 8 bytes per int64 index;
irregular scan coordinates use a bounded 32-element stack array.

## Representative interface results

All values below are microseconds. C and Python include allocating a result.

| Case | C before | C after | Python before | Python after | NumPy after |
|---|---:|---:|---:|---:|---:|
| float32 argmin (65536,) axis=None C | 178.21–200.55 | 50.39–51.02 | 190.90–215.27 | 60.57–65.08 | 4.77–4.82 |
| float32 argmin (65536,) axis=None step | 166.90–208.39 | 50.95–54.93 | 176.71–226.73 | 60.17–60.74 | 21.18–22.50 |
| float32 argmin (65536,) axis=None reverse | 166.44–215.76 | 53.86–55.42 | 174.74–214.12 | 59.60–62.94 | 20.76–21.13 |
| float32 argmin (128, 128) axis=None F | 157.81–185.32 | 36.17–37.00 | 165.68–233.60 | 45.98–52.04 | 16.66–17.11 |
| float32 argmin (128, 128) axis=1 C | 43.80–58.52 | 19.67–20.14 | 51.57–68.46 | 28.47–32.29 | 2.42–2.49 |
| float32 argmin (16,) axis=None C | 2.74–3.59 | 2.78–3.36 | 9.86–13.52 | 11.34–11.54 | 0.91–1.26 |

## Bool early-exit and full-scan results

First-match cases remove nearly all scan work. Middle/last/absent cases show
how costs grow with the position of the answer; absent matches still return
index zero. The alternating benchmark alone would overstate general bool gains.
NumPy's strided timings include its own implementation/layout costs and should
not be read as equal work to Frumpy's direct traversal.

| Operation | Layout | First match | C before | C after | Python before | Python after | NumPy after |
|---|---|---|---:|---:|---:|---:|---:|
| argmin | C | first | 148.51–156.81 | 2.77–3.25 | 149.52–167.96 | 11.63–12.28 | 0.93–1.63 |
| argmin | C | middle | 135.00–151.69 | 28.31–29.46 | 145.35–174.01 | 36.83–42.89 | 1.80–1.83 |
| argmin | C | last | 135.43–160.98 | 53.06–55.33 | 146.70–167.59 | 61.53–67.49 | 1.68–2.06 |
| argmin | C | absent | 140.06–158.56 | 56.26–59.21 | 148.95–170.91 | 65.10–70.81 | 1.50–2.39 |
| argmin | step | first | 140.95–167.21 | 2.90–4.39 | 145.34–170.46 | 10.05–15.48 | 16.53–19.89 |
| argmin | step | middle | 143.62–149.71 | 27.53–31.96 | 161.78–166.31 | 37.23–47.71 | 16.58–21.07 |
| argmin | step | last | 141.26–159.74 | 51.00–65.76 | 151.05–181.85 | 59.22–78.24 | 16.69–21.10 |
| argmin | step | absent | 136.90–165.29 | 52.94–59.52 | 147.75–180.79 | 61.69–77.32 | 16.75–19.60 |
| argmin | reverse | first | 135.52–170.72 | 2.76–4.60 | 144.29–196.26 | 10.29–15.76 | 16.28–19.01 |
| argmin | reverse | middle | 134.92–149.89 | 27.83–28.77 | 145.16–183.52 | 36.05–40.94 | 16.41–17.22 |
| argmin | reverse | last | 135.10–150.35 | 52.47–53.23 | 141.74–166.54 | 60.81–60.83 | 16.74–16.89 |
| argmin | reverse | absent | 135.70–170.83 | 53.04–53.67 | 148.23–185.55 | 61.21–63.65 | 17.13–19.18 |
| argmin | F | first | 461.42–530.61 | 2.80–3.07 | 475.52–561.89 | 10.29–14.59 | 33.54–34.09 |
| argmin | F | middle | 471.43–575.27 | 46.35–72.25 | 480.57–601.23 | 56.43–60.63 | 33.00–34.33 |
| argmin | F | last | 557.51–686.28 | 96.90–124.69 | 540.25–681.98 | 108.13–119.00 | 33.39–36.47 |
| argmin | F | absent | 548.81–562.97 | 91.53–103.36 | 530.74–552.58 | 104.85–112.41 | 33.18–35.09 |
| argmax | C | first | 127.76–149.80 | 2.81–3.09 | 138.12–156.45 | 10.59–13.90 | 0.89–1.01 |
| argmax | C | middle | 136.02–143.67 | 31.49–38.31 | 138.94–169.45 | 37.05–40.79 | 1.72–2.07 |
| argmax | C | last | 139.15–141.00 | 50.41–52.53 | 144.63–157.38 | 71.54–94.89 | 1.49–1.55 |
| argmax | C | absent | 155.98–232.31 | 53.30–54.27 | 155.90–176.75 | 61.00–62.25 | 1.44–1.58 |
| argmax | step | first | 125.63–164.70 | 2.87–2.96 | 177.12–189.02 | 10.41–10.78 | 16.64–18.05 |
| argmax | step | middle | 128.82–168.37 | 27.71–28.21 | 147.17–172.74 | 35.28–36.52 | 16.76–16.94 |
| argmax | step | last | 174.94–228.20 | 50.78–52.58 | 143.42–168.52 | 60.23–66.44 | 16.78–17.07 |
| argmax | step | absent | 127.91–134.74 | 51.81–53.88 | 137.20–143.09 | 60.99–63.73 | 16.75–16.77 |
| argmax | reverse | first | 135.60–147.10 | 2.77–2.90 | 139.37–148.46 | 9.97–10.47 | 16.09–17.62 |
| argmax | reverse | middle | 129.36–141.92 | 27.51–27.55 | 154.62–186.97 | 35.90–35.92 | 16.58–16.79 |
| argmax | reverse | last | 128.92–147.59 | 50.62–50.69 | 129.93–165.34 | 59.86–60.22 | 16.70–16.75 |
| argmax | reverse | absent | 130.35–145.62 | 54.24–54.36 | 137.26–177.98 | 61.45–65.04 | 16.59–17.02 |
| argmax | F | first | 514.20–533.64 | 2.78–3.16 | 530.15–612.22 | 10.08–10.65 | 32.01–33.24 |
| argmax | F | middle | 497.97–506.25 | 46.41–47.50 | 510.45–557.40 | 55.88–55.92 | 32.29–32.45 |
| argmax | F | last | 499.15–562.52 | 91.68–93.59 | 492.03–555.17 | 101.66–114.82 | 33.54–33.69 |
| argmax | F | absent | 484.64–571.25 | 95.99–96.70 | 497.87–605.02 | 104.28–104.32 | 32.89–35.12 |

## Full standard interface results

Speedup is baseline/optimized, using the lowest baseline and highest optimized
median for the low end, and vice versa for the high end. This deliberately
exposes run variability; values below one mean a slower measurement.

| Dtype | Operation | Shape | Axis | Layout | C before | C after | Python before | Python after | Python speedup |
|---|---|---|---|---|---:|---:|---:|---:|---:|
| bool | argmin | (16,) | None | C | 3.70–4.12 | 2.79–2.79 | 10.42–11.86 | 10.03–10.57 | 0.99–1.18× |
| bool | argmin | (65536,) | None | C | 138.22–153.69 | 2.76–2.89 | 154.29–167.18 | 10.43–11.56 | 13.35–16.03× |
| bool | argmin | (65536,) | None | step | 134.52–158.41 | 51.27–52.24 | 146.47–187.71 | 59.81–64.24 | 2.28–3.14× |
| bool | argmin | (65536,) | None | reverse | 138.62–183.93 | 2.78–2.79 | 145.57–187.59 | 9.92–10.62 | 13.70–18.90× |
| bool | argmin | (128, 128) | None | F | 123.26–151.84 | 2.76–2.83 | 132.25–165.86 | 10.13–10.62 | 12.45–16.38× |
| bool | argmin | (128, 128) | 0 | C | 37.95–46.15 | 10.99–11.64 | 46.44–56.05 | 18.97–20.45 | 2.27–2.95× |
| bool | argmin | (128, 128) | 1 | C | 37.01–49.90 | 5.14–5.46 | 45.16–55.79 | 13.09–14.69 | 3.07–4.26× |
| bool | argmin | (128, 128) | 1 | F | 43.73–45.54 | 5.22–5.50 | 45.38–54.75 | 13.07–14.67 | 3.09–4.19× |
| bool | argmax | (16,) | None | C | 2.76–3.40 | 2.77–2.85 | 11.46–12.85 | 10.02–10.32 | 1.11–1.28× |
| bool | argmax | (65536,) | None | C | 125.65–153.93 | 2.78–3.07 | 134.81–164.07 | 10.07–12.30 | 10.96–16.29× |
| bool | argmax | (65536,) | None | step | 132.09–152.52 | 2.74–3.02 | 135.34–146.72 | 10.06–10.54 | 12.84–14.59× |
| bool | argmax | (65536,) | None | reverse | 132.45–136.99 | 2.81–3.02 | 144.00–148.90 | 10.05–11.26 | 12.79–14.81× |
| bool | argmax | (128, 128) | None | F | 121.85–133.37 | 2.78–3.19 | 131.86–138.58 | 10.83–11.03 | 11.95–12.79× |
| bool | argmax | (128, 128) | 0 | C | 34.03–39.39 | 11.14–13.82 | 42.32–45.77 | 19.76–20.43 | 2.07–2.32× |
| bool | argmax | (128, 128) | 1 | C | 38.89–63.71 | 5.37–5.79 | 43.12–54.16 | 13.49–19.40 | 2.22–4.01× |
| bool | argmax | (128, 128) | 1 | F | 36.59–63.51 | 5.10–6.59 | 50.72–83.77 | 12.97–14.82 | 3.42–6.46× |
| int32 | argmin | (16,) | None | C | 2.93–3.74 | 2.78–2.93 | 10.47–10.83 | 10.09–10.58 | 0.99–1.07× |
| int32 | argmin | (65536,) | None | C | 176.44–188.91 | 50.06–50.22 | 170.04–191.56 | 58.02–63.39 | 2.68–3.30× |
| int32 | argmin | (65536,) | None | step | 151.65–231.24 | 49.02–55.27 | 172.93–191.87 | 59.30–64.22 | 2.69–3.24× |
| int32 | argmin | (65536,) | None | reverse | 150.96–227.78 | 47.88–49.21 | 161.84–245.24 | 57.77–66.27 | 2.44–4.25× |
| int32 | argmin | (128, 128) | None | F | 120.87–178.31 | 29.21–30.34 | 130.12–190.29 | 38.08–38.26 | 3.40–5.00× |
| int32 | argmin | (128, 128) | 0 | C | 45.28–57.10 | 20.87–20.97 | 54.59–70.61 | 30.61–31.78 | 1.72–2.31× |
| int32 | argmin | (128, 128) | 1 | C | 45.81–52.10 | 18.99–19.01 | 55.46–66.54 | 29.19–30.23 | 1.83–2.28× |
| int32 | argmin | (128, 128) | 1 | F | 43.95–58.07 | 19.71–20.17 | 51.68–72.75 | 29.72–32.38 | 1.60–2.45× |
| int32 | argmax | (16,) | None | C | 2.74–2.94 | 2.75–2.85 | 9.63–10.37 | 9.91–10.10 | 0.95–1.05× |
| int32 | argmax | (65536,) | None | C | 136.98–157.89 | 47.73–53.36 | 146.25–179.48 | 56.65–64.25 | 2.28–3.17× |
| int32 | argmax | (65536,) | None | step | 145.94–193.00 | 50.51–51.13 | 158.51–177.75 | 60.79–63.75 | 2.49–2.92× |
| int32 | argmax | (65536,) | None | reverse | 139.36–185.41 | 49.79–61.25 | 150.43–214.50 | 59.66–73.12 | 2.06–3.60× |
| int32 | argmax | (128, 128) | None | F | 120.97–155.50 | 28.93–30.31 | 129.04–195.19 | 40.87–43.83 | 2.94–4.78× |
| int32 | argmax | (128, 128) | 0 | C | 39.42–48.94 | 20.43–21.03 | 48.86–58.79 | 29.07–29.82 | 1.64–2.02× |
| int32 | argmax | (128, 128) | 1 | C | 40.64–55.54 | 19.92–24.87 | 48.64–76.97 | 28.58–35.89 | 1.36–2.69× |
| int32 | argmax | (128, 128) | 1 | F | 39.65–62.31 | 21.65–25.87 | 48.79–77.27 | 30.02–41.65 | 1.17–2.57× |
| int64 | argmin | (16,) | None | C | 2.74–3.87 | 3.07–5.09 | 9.92–12.17 | 11.03–17.76 | 0.56–1.10× |
| int64 | argmin | (65536,) | None | C | 164.31–196.98 | 73.09–151.05 | 175.55–247.06 | 89.78–156.81 | 1.12–2.75× |
| int64 | argmin | (65536,) | None | step | 163.65–203.89 | 67.38–81.91 | 179.06–258.46 | 78.03–108.27 | 1.65–3.31× |
| int64 | argmin | (65536,) | None | reverse | 156.56–188.44 | 67.96–69.34 | 165.10–235.23 | 75.18–81.96 | 2.01–3.13× |
| int64 | argmin | (128, 128) | None | F | 126.87–184.72 | 29.75–32.19 | 133.98–210.90 | 39.86–43.06 | 3.11–5.29× |
| int64 | argmin | (128, 128) | 0 | C | 41.36–59.55 | 31.76–33.08 | 52.60–94.34 | 31.63–38.57 | 1.36–2.98× |
| int64 | argmin | (128, 128) | 1 | C | 42.00–57.71 | 23.90–27.12 | 50.40–69.98 | 33.68–37.67 | 1.34–2.08× |
| int64 | argmin | (128, 128) | 1 | F | 42.31–51.05 | 24.43–25.44 | 50.81–70.32 | 33.54–37.20 | 1.37–2.10× |
| int64 | argmax | (16,) | None | C | 2.72–4.63 | 2.79–2.89 | 9.75–13.38 | 10.39–10.52 | 0.93–1.29× |
| int64 | argmax | (65536,) | None | C | 135.34–179.85 | 65.48–65.70 | 145.44–193.33 | 75.67–81.86 | 1.78–2.55× |
| int64 | argmax | (65536,) | None | step | 136.07–194.26 | 64.09–67.79 | 146.65–198.70 | 74.38–76.61 | 1.91–2.67× |
| int64 | argmax | (65536,) | None | reverse | 143.46–162.28 | 65.11–76.83 | 145.91–193.25 | 80.09–84.82 | 1.72–2.41× |
| int64 | argmax | (128, 128) | None | F | 122.17–153.02 | 29.83–30.97 | 141.07–165.07 | 38.38–43.63 | 3.23–4.30× |
| int64 | argmax | (128, 128) | 0 | C | 39.18–58.01 | 23.58–24.16 | 49.12–70.11 | 34.80–36.31 | 1.35–2.01× |
| int64 | argmax | (128, 128) | 1 | C | 38.47–48.36 | 23.61–35.91 | 47.31–52.50 | 31.32–32.56 | 1.45–1.68× |
| int64 | argmax | (128, 128) | 1 | F | 40.97–56.53 | 24.65–26.84 | 52.17–63.57 | 33.75–38.00 | 1.37–1.88× |
| float32 | argmin | (16,) | None | C | 2.74–3.59 | 2.78–3.36 | 9.86–13.52 | 11.34–11.54 | 0.85–1.19× |
| float32 | argmin | (65536,) | None | C | 178.21–200.55 | 50.39–51.02 | 190.90–215.27 | 60.57–65.08 | 2.93–3.55× |
| float32 | argmin | (65536,) | None | step | 166.90–208.39 | 50.95–54.93 | 176.71–226.73 | 60.17–60.74 | 2.91–3.77× |
| float32 | argmin | (65536,) | None | reverse | 166.44–215.76 | 53.86–55.42 | 174.74–214.12 | 59.60–62.94 | 2.78–3.59× |
| float32 | argmin | (128, 128) | None | F | 157.81–185.32 | 36.17–37.00 | 165.68–233.60 | 45.98–52.04 | 3.18–5.08× |
| float32 | argmin | (128, 128) | 0 | C | 44.28–58.61 | 21.10–21.82 | 53.09–68.56 | 30.53–32.55 | 1.63–2.25× |
| float32 | argmin | (128, 128) | 1 | C | 43.80–58.52 | 19.67–20.14 | 51.57–68.46 | 28.47–32.29 | 1.60–2.40× |
| float32 | argmin | (128, 128) | 1 | F | 44.20–52.31 | 21.63–22.69 | 52.73–63.75 | 31.57–31.60 | 1.67–2.02× |
| float32 | argmax | (16,) | None | C | 2.80–4.04 | 2.82–3.28 | 9.37–15.43 | 10.30–10.49 | 0.89–1.50× |
| float32 | argmax | (65536,) | None | C | 172.86–220.79 | 66.53–72.81 | 171.46–224.83 | 76.92–78.74 | 2.18–2.92× |
| float32 | argmax | (65536,) | None | step | 175.03–221.36 | 64.55–69.54 | 189.29–264.76 | 75.88–77.59 | 2.44–3.49× |
| float32 | argmax | (65536,) | None | reverse | 170.13–201.60 | 64.74–65.14 | 191.50–217.97 | 80.30–83.34 | 2.30–2.71× |
| float32 | argmax | (128, 128) | None | F | 130.22–163.48 | 39.27–46.57 | 145.12–172.90 | 47.19–50.82 | 2.86–3.66× |
| float32 | argmax | (128, 128) | 0 | C | 44.85–61.26 | 24.13–31.08 | 53.01–80.48 | 33.90–44.44 | 1.19–2.37× |
| float32 | argmax | (128, 128) | 1 | C | 44.45–61.61 | 24.32–24.68 | 55.03–77.05 | 35.37–37.02 | 1.49–2.18× |
| float32 | argmax | (128, 128) | 1 | F | 45.98–66.99 | 25.80–27.16 | 54.12–75.08 | 36.41–41.35 | 1.31–2.06× |
| float64 | argmin | (16,) | None | C | 2.86–3.15 | 2.75–2.82 | 10.12–14.02 | 11.04–11.24 | 0.90–1.27× |
| float64 | argmin | (65536,) | None | C | 165.13–218.29 | 68.75–72.20 | 181.36–210.03 | 80.46–84.06 | 2.16–2.61× |
| float64 | argmin | (65536,) | None | step | 171.21–193.95 | 64.87–72.94 | 179.24–207.15 | 80.45–84.69 | 2.12–2.57× |
| float64 | argmin | (65536,) | None | reverse | 193.58–213.89 | 68.24–79.48 | 203.90–215.65 | 75.83–99.86 | 2.04–2.84× |
| float64 | argmin | (128, 128) | None | F | 170.40–198.00 | 36.57–40.85 | 189.58–200.80 | 46.15–55.08 | 3.44–4.35× |
| float64 | argmin | (128, 128) | 0 | C | 45.00–58.61 | 23.69–25.08 | 56.34–79.50 | 33.23–36.30 | 1.55–2.39× |
| float64 | argmin | (128, 128) | 1 | C | 44.97–66.18 | 23.12–23.91 | 55.74–82.41 | 31.91–33.27 | 1.68–2.58× |
| float64 | argmin | (128, 128) | 1 | F | 45.44–54.91 | 24.92–35.48 | 55.92–70.09 | 34.53–44.81 | 1.25–2.03× |
| float64 | argmax | (16,) | None | C | 2.79–4.49 | 2.84–3.23 | 10.03–16.27 | 9.95–11.36 | 0.88–1.63× |
| float64 | argmax | (65536,) | None | C | 171.21–211.33 | 80.43–85.36 | 175.49–249.39 | 89.35–99.85 | 1.76–2.79× |
| float64 | argmax | (65536,) | None | step | 168.51–209.18 | 82.34–84.34 | 178.68–235.96 | 91.82–94.69 | 1.89–2.57× |
| float64 | argmax | (65536,) | None | reverse | 167.58–226.68 | 83.40–91.77 | 178.09–218.13 | 92.87–93.91 | 1.90–2.35× |
| float64 | argmax | (128, 128) | None | F | 149.17–204.95 | 42.75–44.04 | 138.79–218.75 | 52.09–55.13 | 2.52–4.20× |
| float64 | argmax | (128, 128) | 0 | C | 46.26–61.96 | 29.65–29.76 | 55.70–68.22 | 37.52–40.91 | 1.36–1.82× |
| float64 | argmax | (128, 128) | 1 | C | 46.89–64.51 | 27.56–31.63 | 58.79–59.00 | 36.87–44.68 | 1.32–1.60× |
| float64 | argmax | (128, 128) | 1 | F | 45.76–57.91 | 31.27–32.62 | 55.26–68.52 | 40.06–78.07 | 0.71–1.71× |

## Slower or overlapping Python ranges

- ('bool', 'argmin', (16,), None, 'C', 'pattern'): 10.42–11.86 → 10.03–10.57 µs; 0.99–1.18×.
- ('int32', 'argmin', (16,), None, 'C', 'pattern'): 10.47–10.83 → 10.09–10.58 µs; 0.99–1.07×.
- ('int32', 'argmax', (16,), None, 'C', 'pattern'): 9.63–10.37 → 9.91–10.10 µs; 0.95–1.05×.
- ('int64', 'argmin', (16,), None, 'C', 'pattern'): 9.92–12.17 → 11.03–17.76 µs; 0.56–1.10×.
- ('int64', 'argmax', (16,), None, 'C', 'pattern'): 9.75–13.38 → 10.39–10.52 µs; 0.93–1.29×.
- ('float32', 'argmin', (16,), None, 'C', 'pattern'): 9.86–13.52 → 11.34–11.54 µs; 0.85–1.19×.
- ('float32', 'argmax', (16,), None, 'C', 'pattern'): 9.37–15.43 → 10.30–10.49 µs; 0.89–1.50×.
- ('float64', 'argmin', (16,), None, 'C', 'pattern'): 10.12–14.02 → 11.04–11.24 µs; 0.90–1.27×.
- ('float64', 'argmax', (16,), None, 'C', 'pattern'): 10.03–16.27 → 9.95–11.36 µs; 0.88–1.63×.
- ('float64', 'argmax', (128, 128), 1, 'F', 'pattern'): 55.26–68.52 → 40.06–78.07 µs; 0.71–1.71×.

These cases do not justify a broad wrapper rewrite. Small calls are dominated
by fixed validation, descriptor and handle costs; recheck results are kept in
`recheck-*.json` when present. Native small-call reruns are also retained rather
than discarding the original measurements.

## Isolated regression rechecks

The float64 F-order axis case improves on recheck: the optimized 78 µs Python
outlier was not reproduced. Small-call results remain mixed. In the two paired
rechecks, tiny int64 argmin is about 2–5% slower through Python (0.3–0.6 µs);
C medians move in opposite directions. This is retained as a limitation, not
claimed away as a universal speedup. No further wrapper changes are included.

| Case | C before | C after | Python before | Python after |
|---|---:|---:|---:|---:|
| ('int64', 'argmin', (16,), None, 'C') | 3.05–3.19 | 2.95–3.32 | 10.96–13.55 | 11.23–14.16 |
| ('int64', 'argmax', (16,), None, 'C') | 2.97–3.06 | 2.94–3.08 | 11.57–14.10 | 11.67–12.27 |
| ('float32', 'argmin', (16,), None, 'C') | 2.94–3.09 | 2.88–3.71 | 12.33–12.88 | 10.82–11.98 |
| ('float32', 'argmax', (16,), None, 'C') | 2.90–3.08 | 2.88–3.63 | 11.29–12.56 | 10.97–12.26 |
| ('float64', 'argmax', (128, 128), 1, 'F') | 52.79–55.18 | 30.95–33.26 | 64.84–67.40 | 41.98–45.49 |

## Native measurements

Values are medians of seven CPU-time batches, in microseconds. General native
rows show the range across the original and reverse-order process reruns.

| Dtype | Operation | Elements | Layout | Before | After |
|---|---|---:|---|---:|---:|
| bool | argmin | 16 | C | 1.02–1.17 | 0.97–1.02 |
| int32 | argmin | 16 | C | 1.00–1.10 | 0.98–1.23 |
| int64 | argmin | 16 | C | 1.03–1.15 | 0.99–1.17 |
| float32 | argmin | 16 | C | 1.02–1.19 | 0.99–1.06 |
| float64 | argmin | 16 | C | 1.01–1.08 | 0.99–1.06 |
| bool | argmin | 16 | step | 1.00–1.13 | 0.98–1.08 |
| int32 | argmin | 16 | step | 1.00–1.22 | 1.00–1.20 |
| int64 | argmin | 16 | step | 1.02–1.19 | 1.00–1.19 |
| float32 | argmin | 16 | step | 1.02–1.24 | 1.04–1.27 |
| float64 | argmin | 16 | step | 1.02–1.31 | 1.05–1.14 |
| bool | argmin | 16 | reverse | 1.00–1.16 | 1.01–1.15 |
| int32 | argmin | 16 | reverse | 1.00–1.44 | 1.16–1.17 |
| int64 | argmin | 16 | reverse | 1.00–1.39 | 1.11–1.19 |
| float32 | argmin | 16 | reverse | 1.00–1.21 | 1.09–1.15 |
| float64 | argmin | 16 | reverse | 1.04–1.24 | 1.09–1.24 |
| bool | argmin | 16 | F | 1.09–1.33 | 1.05–1.30 |
| int32 | argmin | 16 | F | 1.12–1.45 | 1.19–1.37 |
| int64 | argmin | 16 | F | 1.22–1.30 | 1.07–1.08 |
| float32 | argmin | 16 | F | 1.12–1.44 | 1.09–1.11 |
| float64 | argmin | 16 | F | 1.10–1.26 | 1.06–1.09 |
| bool | argmin | 65536 | C | 119.53–139.70 | 0.94–1.50 |
| int32 | argmin | 65536 | C | 133.75–152.77 | 48.25–53.79 |
| int64 | argmin | 65536 | C | 134.94–159.87 | 65.57–120.80 |
| float32 | argmin | 65536 | C | 162.54–172.77 | 61.88–88.92 |
| float64 | argmin | 65536 | C | 160.60–182.75 | 60.95–124.57 |
| bool | argmin | 65536 | step | 118.52–127.01 | 49.92–58.79 |
| int32 | argmin | 65536 | step | 131.90–144.64 | 45.83–47.34 |
| int64 | argmin | 65536 | step | 131.90–147.91 | 64.59–71.25 |
| float32 | argmin | 65536 | step | 161.87–176.00 | 46.04–49.33 |
| float64 | argmin | 65536 | step | 162.81–181.17 | 61.83–63.65 |
| bool | argmin | 65536 | reverse | 121.33–144.18 | 0.96–0.96 |
| int32 | argmin | 65536 | reverse | 137.01–152.73 | 44.63–50.34 |
| int64 | argmin | 65536 | reverse | 137.08–166.03 | 60.32–62.62 |
| float32 | argmin | 65536 | reverse | 163.04–176.18 | 44.86–53.31 |
| float64 | argmin | 65536 | reverse | 162.54–182.37 | 59.74–79.44 |
| bool | argmin | 65536 | F | 462.81–534.52 | 0.95–0.96 |
| int32 | argmin | 65536 | F | 463.71–509.50 | 101.05–106.37 |
| int64 | argmin | 65536 | F | 479.50–532.48 | 110.67–125.17 |
| float32 | argmin | 65536 | F | 626.48–662.64 | 128.88–146.20 |
| float64 | argmin | 65536 | F | 610.00–651.20 | 129.90–144.78 |
| bool | argmax | 16 | C | 0.99–1.20 | 0.96–1.16 |
| int32 | argmax | 16 | C | 1.04–1.12 | 1.00–1.33 |
| int64 | argmax | 16 | C | 0.99–1.16 | 1.00–1.11 |
| float32 | argmax | 16 | C | 0.97–1.16 | 1.00–1.11 |
| float64 | argmax | 16 | C | 0.98–1.12 | 1.01–1.14 |
| bool | argmax | 16 | step | 0.96–1.31 | 0.99–1.18 |
| int32 | argmax | 16 | step | 0.96–1.11 | 1.02–1.24 |
| int64 | argmax | 16 | step | 0.99–1.22 | 1.21–1.46 |
| float32 | argmax | 16 | step | 0.97–1.24 | 1.25–1.33 |
| float64 | argmax | 16 | step | 0.97–1.25 | 1.05–1.18 |
| bool | argmax | 16 | reverse | 1.00–1.07 | 1.01–1.13 |
| int32 | argmax | 16 | reverse | 0.97–1.12 | 1.00–1.20 |
| int64 | argmax | 16 | reverse | 0.97–1.31 | 1.05–1.40 |
| float32 | argmax | 16 | reverse | 0.99–1.12 | 1.04–1.39 |
| float64 | argmax | 16 | reverse | 0.99–1.09 | 1.03–1.06 |
| bool | argmax | 16 | F | 1.15–1.21 | 1.01–1.21 |
| int32 | argmax | 16 | F | 1.16–1.29 | 1.06–1.13 |
| int64 | argmax | 16 | F | 1.16–1.18 | 1.05–1.35 |
| float32 | argmax | 16 | F | 1.07–1.32 | 1.03–1.37 |
| float64 | argmax | 16 | F | 1.07–1.15 | 1.06–1.10 |
| bool | argmax | 65536 | C | 106.16–125.03 | 1.05–1.20 |
| int32 | argmax | 65536 | C | 119.51–182.32 | 46.04–58.39 |
| int64 | argmax | 65536 | C | 121.64–182.06 | 62.02–66.22 |
| float32 | argmax | 65536 | C | 161.52–181.33 | 62.68–64.45 |
| float64 | argmax | 65536 | C | 161.67–193.11 | 76.80–84.77 |
| bool | argmax | 65536 | step | 106.36–157.20 | 0.94–0.95 |
| int32 | argmax | 65536 | step | 119.95–167.82 | 44.97–46.25 |
| int64 | argmax | 65536 | step | 119.60–158.58 | 63.16–64.34 |
| float32 | argmax | 65536 | step | 160.40–205.54 | 62.44–66.90 |
| float64 | argmax | 65536 | step | 159.76–203.41 | 86.46–102.15 |
| bool | argmax | 65536 | reverse | 102.59–127.66 | 0.95–0.96 |
| int32 | argmax | 65536 | reverse | 119.93–166.42 | 45.31–51.55 |
| int64 | argmax | 65536 | reverse | 121.95–148.71 | 60.68–70.61 |
| float32 | argmax | 65536 | reverse | 162.61–190.30 | 62.89–86.05 |
| float64 | argmax | 65536 | reverse | 163.29–179.42 | 79.83–165.93 |
| bool | argmax | 65536 | F | 470.61–529.28 | 0.95–1.60 |
| int32 | argmax | 65536 | F | 496.40–522.45 | 97.57–168.97 |
| int64 | argmax | 65536 | F | 462.46–496.77 | 114.47–121.09 |
| float32 | argmax | 65536 | F | 504.21–572.18 | 143.18–161.30 |
| float64 | argmax | 65536 | F | 496.26–569.75 | 164.54–167.09 |

## Native bool distribution measurements

Single-run seven-sample CPU-time medians, 65,536 elements. Layout F is 256×256.

| Operation | Layout | Match | Before µs | After µs |
|---|---|---|---:|---:|
| argmin | C | first | 121.57 | 1.55 |
| argmin | C | middle | 136.46 | 25.70 |
| argmin | C | last | 124.03 | 49.56 |
| argmin | C | absent | 122.88 | 55.24 |
| argmin | step | first | 133.90 | 1.11 |
| argmin | step | middle | 132.12 | 30.70 |
| argmin | step | last | 127.61 | 52.91 |
| argmin | step | absent | 120.80 | 51.23 |
| argmin | reverse | first | 129.81 | 0.94 |
| argmin | reverse | middle | 123.10 | 26.15 |
| argmin | reverse | last | 120.39 | 48.49 |
| argmin | reverse | absent | 130.05 | 50.91 |
| argmin | F | first | 475.55 | 1.72 |
| argmin | F | middle | 473.21 | 48.58 |
| argmin | F | last | 471.50 | 97.16 |
| argmin | F | absent | 486.65 | 103.58 |
| argmax | C | first | 107.13 | 1.01 |
| argmax | C | middle | 109.21 | 33.07 |
| argmax | C | last | 108.51 | 70.52 |
| argmax | C | absent | 112.05 | 48.83 |
| argmax | step | first | 113.97 | 0.96 |
| argmax | step | middle | 115.96 | 25.59 |
| argmax | step | last | 105.06 | 47.82 |
| argmax | step | absent | 105.80 | 52.01 |
| argmax | reverse | first | 109.19 | 1.06 |
| argmax | reverse | middle | 107.33 | 26.19 |
| argmax | reverse | last | 137.19 | 48.62 |
| argmax | reverse | absent | 107.71 | 49.21 |
| argmax | F | first | 474.38 | 0.94 |
| argmax | F | middle | 485.71 | 43.03 |
| argmax | F | last | 476.03 | 90.83 |
| argmax | F | absent | 466.94 | 91.87 |

## Decision and limits

The bounded pass removes identifiable scan/traversal overhead while preserving
contracts and memory behavior. Return to functionality after reviewing the
small-call limitation above. NumPy still leads many numeric scans; SIMD
index tracking and generic wrapper overhead would be separate projects, not
reasons to extend this pass indefinitely. Bool early-exit ratios must always be
reported alongside late and absent matches.

## Reproduce and raw evidence

Use preserved baseline and optimized release directories. Compile both
`benchmarks/benchmark_arg_reductions.f90` and `benchmarks/benchmark_arg_bool.f90`
against each directory's core objects and module files, and run with `taskset -c 0`.
Set `FRUMPY_LIBRARY` to the corresponding shared library, `PYTHONPATH=python`,
and `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1` for the interface script:

```sh
.venv/bin/python benchmarks/compare_arg_reductions.py --source-commit REV --output interfaces.json
.venv/bin/python benchmarks/compare_arg_reductions.py --source-commit REV --bool-cases --output bool.json
```

Repeat with `--reverse` in reversed build order. All `arg-*` files are baseline;
`arg-opt-*` files are optimized. JSON files contain raw wall/CPU samples and
library hashes; native text files contain all seven samples. The optional `--review-cases` filter was added after the kernel commit
for isolated rechecks; it changes case selection only. Machine, executable
and benchmark-source hashes are in [provenance.json](provenance.json).
