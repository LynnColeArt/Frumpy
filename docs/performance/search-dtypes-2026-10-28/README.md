# Same-dtype searchsorted — 2026-10-28

Searchsorted now accepts matching bool, int32, int64, float32 and float64
source/query dtypes through native Fortran, C and Python. It preserves left/right
insertion, exact integer ordering, NaNs-last equivalence and signed-zero ties.
Results are owned C-order int64 arrays with the query shape, including scalar
and empty queries. The source must be a sorted vector. Mixed-dtype queries and
`sorter` remain unsupported. See [the contract](../../SEARCHSORTED_DTYPES.md).

## Validation

Source revision `6329097`. GNU 13/14 and Flang 19 debug/release each pass
41 native programs, 7,345 Python tests, two examples and the C caller.
There are 1,295 new search test cases and five package smoke cases. Tests cover
exact int64 extremes, duplicate insertion boundaries, NaNs/infinities/signed
zeros, scalar/empty/arbitrary-shaped queries, C/F and signed/zero strides,
input preservation, lifetime, invalid ranks/flags, mixed-dtype rejection,
malformed bounds and output-size overflow. A native zero-stride virtual source
of length `huge(int64)` verifies that midpoint arithmetic and the final insertion
index do not overflow.

ASan native leak checks and 4,674 C/Python cases pass; the integer-overflow gate
and separate 1,681-case UBSan search/package suite pass. fpm, the full OpenBLAS
suite and 386 isolated installed-package tests pass. GNU debug initially rejected
an explicit real equality under `-Werror=compare-reals`; ordered comparisons
replaced it before the final matrix and sanitizer runs. See the
[validation manifest](../../validation/search-dtypes-2026-10-28.json).

## Implementation and memory

The four added dtypes share overflow-safe binary search. Integer keys compare
as integers; bool uses normalized truth values. Float32 probes and targets widen
exactly to float64 for comparison, without a full cast buffer. Queries traverse
in logical C order, and sources are accessed directly through their signed
stride. There is no full source/query temporary, packing or sortedness scan.
Sorted input remains a caller precondition.

Output payload is 8Q bytes for Q queries, plus small descriptor metadata.
Float64 retains its existing kernel and direct C path; its release kernel
object hash is identical to baseline. Native generic float64 calls delegate to
the established function. Work is O(Q log N), plus query-rank-dependent offset
calculation. The new path uses shared typed-access helpers at each probe; no
specialized SIMD or batched-query optimization is claimed.

## Measurement method

GNU 14 release: `-std=f2018 -O3 -fimplicit-none`, no fast-math. CPU 0 affinity,
thread counts one, build/validation jobs stopped. Native uses seven CPU-time
batches (20 calls, or 1,000 for fewer than 32 queries). Interfaces use seven
warmed wall/CPU samples, calibrated toward 30 ms and capped at 1,000 calls.
Input construction/import/export is outside timing; result allocation/release
is timed. Raw C includes ctypes dispatch. NumPy is 2.4.6. No BLAS calls occur.

The native driver checks every output against an independent linear-count oracle
before timing. Interface outputs are checked against NumPy. Both drivers use
identical values and layouts. Numeric sources contain `i//2 - N//4`; the
source-duplicate case uses `i//64 - N//128`. Queries use `(37*i) % (N+17) - N//2`.
Int64 sources and queries add 2**60, exercising distinctions beyond float64
integer precision. Bool sources are half False then half True, with alternating
queries. Timed floating inputs are finite; nonfinite ordering is covered by tests.

The duplicate-source case retains the broad query range: most such numeric
queries lie outside its narrower key range. Do not interpret it as an all-hit
benchmark. Source-step and source-reverse cases keep logical ascending order,
with doubled backing storage or a descending backing array viewed in reverse;
NumPy receives matching logical strided views. Query cases include F-order
64×64 arrays and reversed vectors.

Two interface rounds reverse case/interface order and baseline/final build order.
Ranges are the two per-run wall medians, not confidence intervals. Native values
are single-run medians of seven CPU-time batches. Separate native and interface
runs should not be subtracted to estimate precise wrapper overhead.

Baseline `2ff58eb` supports float64 only; other dtypes are new functionality
baselines. Final source is `6329097`. The direct float64 C path is retained to
avoid introducing the redundant generic validation/result transfer seen during
the preceding sorting slice. All float64 control measurements are retained below.

## Representative batched results

8,192 source elements, 4,096 contiguous queries, left insertion. Times in µs.

| Dtype | Native | C | Python | NumPy |
|---|---:|---:|---:|---:|
| bool | 115.65 | 128.87–129.26 | 137.07–146.65 | 28.76–28.78 |
| int32 | 230.50 | 243.56–248.19 | 255.04–263.70 | 35.38–36.16 |
| int64 | 229.20 | 243.76–249.65 | 256.14–257.22 | 35.47–35.87 |
| float32 | 277.25 | 276.28–278.84 | 279.45–290.76 | 42.63–44.69 |
| float64 | 192.30 | 194.35–194.44 | 206.43–206.96 | 43.20–43.35 |

The new integer and float32 paths are slower than the existing float64 kernel
on this batch. NumPy remains faster across these five rows. This completes a
functionality slice; it is not a performance upgrade. Per-probe helper dispatch,
query traversal and branch behavior are candidates for a future measured pass,
not an established allocation bottleneck or a reason to broaden this slice.
In the two float64 control rounds, no C/Python case was more than 3% slower in
both paired runs; that limited observation does not prove exact equivalence.

## All interface cases

| Dtype | Side | Source N | Query shape | Layout | C µs | Python µs | NumPy µs |
|---|---|---:|---|---|---:|---:|---:|
| bool | left | 32 | (16,) | C | 2.74–2.81 | 10.12–10.77 | 0.96–1.09 |
| bool | left | 8192 | () | C | 2.40–3.19 | 9.64–9.70 | 0.89–0.89 |
| bool | left | 8192 | (4096,) | C | 128.87–129.26 | 137.07–146.65 | 28.76–28.78 |
| bool | left | 8192 | (4096,) | source_step | 126.89–130.71 | 136.61–147.58 | 36.16–36.51 |
| bool | left | 8192 | (4096,) | source_reverse | 130.11–138.72 | 138.69–147.05 | 35.49–36.26 |
| bool | left | 8192 | (64, 64) | query_F | 130.76–140.37 | 146.65–148.65 | 29.82–30.38 |
| bool | left | 8192 | (4096,) | query_reverse | 127.61–133.31 | 134.19–137.09 | 29.37–30.66 |
| bool | left | 8192 | (4096,) | duplicates | 129.29–130.06 | 143.29–152.35 | 29.45–30.25 |
| bool | right | 32 | (16,) | C | 2.67–2.77 | 10.12–11.13 | 0.94–1.09 |
| bool | right | 8192 | () | C | 2.50–2.73 | 9.83–10.28 | 0.86–0.90 |
| bool | right | 8192 | (4096,) | C | 149.42–154.50 | 164.28–173.87 | 38.26–38.86 |
| bool | right | 8192 | (4096,) | source_step | 150.39–156.58 | 160.62–173.12 | 41.60–43.16 |
| bool | right | 8192 | (4096,) | source_reverse | 150.97–157.10 | 158.85–169.75 | 41.52–42.37 |
| bool | right | 8192 | (64, 64) | query_F | 153.67–156.35 | 169.43–174.32 | 39.68–41.15 |
| bool | right | 8192 | (4096,) | query_reverse | 151.92–157.95 | 168.93–169.97 | 39.92–40.37 |
| bool | right | 8192 | (4096,) | duplicates | 149.84–158.70 | 162.14–164.31 | 37.27–37.99 |
| int32 | left | 32 | (16,) | C | 2.69–2.71 | 10.34–10.34 | 0.89–0.90 |
| int32 | left | 8192 | () | C | 2.39–2.47 | 9.78–10.26 | 0.86–0.88 |
| int32 | left | 8192 | (4096,) | C | 243.56–248.19 | 255.04–263.70 | 35.38–36.16 |
| int32 | left | 8192 | (4096,) | source_step | 247.18–251.82 | 262.96–263.85 | 36.98–37.15 |
| int32 | left | 8192 | (4096,) | source_reverse | 250.25–251.14 | 260.85–261.96 | 35.19–37.01 |
| int32 | left | 8192 | (64, 64) | query_F | 248.92–253.72 | 261.22–268.13 | 36.89–37.10 |
| int32 | left | 8192 | (4096,) | query_reverse | 245.56–247.90 | 259.78–262.66 | 36.33–37.08 |
| int32 | left | 8192 | (4096,) | duplicates | 147.95–166.85 | 159.61–168.21 | 25.98–27.29 |
| int32 | right | 32 | (16,) | C | 2.73–2.79 | 10.49–10.94 | 0.91–0.94 |
| int32 | right | 8192 | () | C | 2.40–2.49 | 9.99–10.22 | 0.89–1.01 |
| int32 | right | 8192 | (4096,) | C | 251.71–253.60 | 268.87–269.65 | 37.12–37.77 |
| int32 | right | 8192 | (4096,) | source_step | 250.44–266.09 | 258.92–269.10 | 35.38–36.39 |
| int32 | right | 8192 | (4096,) | source_reverse | 243.28–252.01 | 257.99–260.53 | 35.70–35.78 |
| int32 | right | 8192 | (64, 64) | query_F | 251.69–254.18 | 263.15–287.51 | 36.53–37.71 |
| int32 | right | 8192 | (4096,) | query_reverse | 243.18–251.65 | 263.01–266.36 | 36.12–36.85 |
| int32 | right | 8192 | (4096,) | duplicates | 147.97–150.56 | 156.88–168.73 | 25.04–25.40 |
| int64 | left | 32 | (16,) | C | 2.64–2.67 | 9.95–10.19 | 0.91–0.92 |
| int64 | left | 8192 | () | C | 2.38–2.39 | 9.36–9.65 | 0.88–0.98 |
| int64 | left | 8192 | (4096,) | C | 243.76–249.65 | 256.14–257.22 | 35.47–35.87 |
| int64 | left | 8192 | (4096,) | source_step | 249.55–253.79 | 268.64–279.00 | 37.04–39.37 |
| int64 | left | 8192 | (4096,) | source_reverse | 252.58–262.55 | 262.37–268.36 | 35.60–40.00 |
| int64 | left | 8192 | (64, 64) | query_F | 255.86–269.83 | 263.95–270.54 | 37.03–37.78 |
| int64 | left | 8192 | (4096,) | query_reverse | 243.13–244.92 | 252.94–255.06 | 35.98–36.76 |
| int64 | left | 8192 | (4096,) | duplicates | 148.92–150.22 | 157.10–187.34 | 26.34–29.10 |
| int64 | right | 32 | (16,) | C | 2.82–2.87 | 10.25–10.80 | 0.87–0.94 |
| int64 | right | 8192 | () | C | 2.58–2.68 | 10.06–10.70 | 0.89–0.95 |
| int64 | right | 8192 | (4096,) | C | 249.46–256.31 | 264.59–266.88 | 35.93–36.36 |
| int64 | right | 8192 | (4096,) | source_step | 248.76–263.17 | 262.18–266.15 | 35.96–36.83 |
| int64 | right | 8192 | (4096,) | source_reverse | 245.10–245.22 | 254.91–259.40 | 35.41–36.00 |
| int64 | right | 8192 | (64, 64) | query_F | 257.25–257.31 | 272.10–279.46 | 37.82–38.15 |
| int64 | right | 8192 | (4096,) | query_reverse | 246.69–250.09 | 261.83–264.90 | 36.11–36.42 |
| int64 | right | 8192 | (4096,) | duplicates | 146.85–147.63 | 157.20–162.80 | 25.14–25.29 |
| float32 | left | 32 | (16,) | C | 2.69–2.71 | 10.22–10.42 | 0.94–0.97 |
| float32 | left | 8192 | () | C | 2.43–2.44 | 9.44–9.84 | 0.88–0.89 |
| float32 | left | 8192 | (4096,) | C | 276.28–278.84 | 279.45–290.76 | 42.63–44.69 |
| float32 | left | 8192 | (4096,) | source_step | 282.78–297.69 | 290.44–332.37 | 44.23–45.77 |
| float32 | left | 8192 | (4096,) | source_reverse | 278.49–279.53 | 284.53–288.35 | 42.23–45.15 |
| float32 | left | 8192 | (64, 64) | query_F | 282.80–300.52 | 294.15–300.25 | 43.41–45.95 |
| float32 | left | 8192 | (4096,) | query_reverse | 276.49–285.19 | 294.52–304.30 | 43.46–44.11 |
| float32 | left | 8192 | (4096,) | duplicates | 160.84–166.31 | 171.37–179.77 | 31.97–32.44 |
| float32 | right | 32 | (16,) | C | 2.68–2.78 | 10.20–10.42 | 0.93–0.93 |
| float32 | right | 8192 | () | C | 2.38–2.49 | 9.60–10.79 | 0.88–0.89 |
| float32 | right | 8192 | (4096,) | C | 239.64–282.38 | 247.88–287.73 | 38.55–38.76 |
| float32 | right | 8192 | (4096,) | source_step | 244.02–244.87 | 252.64–283.41 | 38.71–39.50 |
| float32 | right | 8192 | (4096,) | source_reverse | 234.51–275.07 | 256.93–290.68 | 38.03–38.54 |
| float32 | right | 8192 | (64, 64) | query_F | 282.25–284.00 | 294.41–299.88 | 40.62–42.13 |
| float32 | right | 8192 | (4096,) | query_reverse | 241.62–241.95 | 256.50–290.18 | 44.74–45.07 |
| float32 | right | 8192 | (4096,) | duplicates | 142.50–144.98 | 153.90–161.11 | 26.58–27.52 |
| float64 | left | 32 | (16,) | C | 2.54–2.62 | 9.87–10.16 | 0.93–0.95 |
| float64 | left | 8192 | () | C | 2.32–2.36 | 9.41–10.24 | 0.92–0.94 |
| float64 | left | 8192 | (4096,) | C | 194.35–194.44 | 206.43–206.96 | 43.20–43.35 |
| float64 | left | 8192 | (4096,) | source_step | 198.93–202.18 | 214.86–216.14 | 43.50–47.28 |
| float64 | left | 8192 | (4096,) | source_reverse | 195.80–202.17 | 207.43–213.17 | 42.72–45.49 |
| float64 | left | 8192 | (64, 64) | query_F | 205.29–212.62 | 219.81–221.64 | 44.75–44.82 |
| float64 | left | 8192 | (4096,) | query_reverse | 192.69–196.26 | 203.81–205.65 | 42.12–42.12 |
| float64 | left | 8192 | (4096,) | duplicates | 96.79–99.34 | 106.68–107.65 | 31.72–32.15 |
| float64 | right | 32 | (16,) | C | 2.50–2.57 | 10.03–10.48 | 0.93–0.95 |
| float64 | right | 8192 | () | C | 2.38–2.40 | 9.56–9.67 | 0.87–0.88 |
| float64 | right | 8192 | (4096,) | C | 183.96–184.81 | 196.70–197.65 | 42.85–43.18 |
| float64 | right | 8192 | (4096,) | source_step | 187.30–194.54 | 201.45–208.78 | 41.15–41.83 |
| float64 | right | 8192 | (4096,) | source_reverse | 183.68–184.26 | 194.67–201.49 | 41.33–42.88 |
| float64 | right | 8192 | (64, 64) | query_F | 189.38–194.05 | 199.61–211.32 | 43.28–50.02 |
| float64 | right | 8192 | (4096,) | query_reverse | 183.28–193.37 | 195.00–208.81 | 45.11–47.23 |
| float64 | right | 8192 | (4096,) | duplicates | 91.58–93.36 | 100.20–103.70 | 28.15–29.83 |

## Float64 control

| Side | Source N | Query shape | Layout | C before | C after | Python before | Python after |
|---|---:|---|---|---:|---:|---:|---:|
| left | 32 | (16,) | C | 2.47–2.48 | 2.54–2.62 | 10.67–10.89 | 9.87–10.16 |
| left | 8192 | () | C | 2.29–2.36 | 2.32–2.36 | 10.06–10.09 | 9.41–10.24 |
| left | 8192 | (4096,) | C | 194.07–194.74 | 194.35–194.44 | 206.95–207.48 | 206.43–206.96 |
| left | 8192 | (4096,) | source_step | 201.70–201.95 | 198.93–202.18 | 212.86–215.70 | 214.86–216.14 |
| left | 8192 | (4096,) | source_reverse | 192.37–193.45 | 195.80–202.17 | 207.26–207.28 | 207.43–213.17 |
| left | 8192 | (64, 64) | query_F | 203.57–204.36 | 205.29–212.62 | 216.40–221.36 | 219.81–221.64 |
| left | 8192 | (4096,) | query_reverse | 193.37–194.94 | 192.69–196.26 | 203.76–204.70 | 203.81–205.65 |
| left | 8192 | (4096,) | duplicates | 95.79–96.50 | 96.79–99.34 | 106.46–107.02 | 106.68–107.65 |
| right | 32 | (16,) | C | 2.48–2.58 | 2.50–2.57 | 9.97–10.14 | 10.03–10.48 |
| right | 8192 | () | C | 2.30–2.34 | 2.38–2.40 | 9.71–9.79 | 9.56–9.67 |
| right | 8192 | (4096,) | C | 182.75–184.63 | 183.96–184.81 | 198.40–199.90 | 196.70–197.65 |
| right | 8192 | (4096,) | source_step | 187.63–194.56 | 187.30–194.54 | 201.81–206.81 | 201.45–208.78 |
| right | 8192 | (4096,) | source_reverse | 183.57–185.88 | 183.68–184.26 | 192.87–200.16 | 194.67–201.49 |
| right | 8192 | (64, 64) | query_F | 190.39–193.07 | 189.38–194.05 | 206.12–207.86 | 199.61–211.32 |
| right | 8192 | (4096,) | query_reverse | 183.77–196.66 | 183.28–193.37 | 203.77–213.16 | 195.00–208.81 |
| right | 8192 | (4096,) | duplicates | 93.13–93.84 | 91.58–93.36 | 102.76–103.26 | 100.20–103.70 |

## Native cases

Case 1: N=32/Q=16; 2: N=8192/scalar query; 3: N=8192/Q=4096 contiguous;
4: stepped source; 5: negative-stride sorted source; 6: F-order 64×64 queries;
7: reversed queries; 8: duplicate-heavy source. Cases 4–8 use N=8192/Q=4096.

| Dtype | Side | Case | Native µs |
|---|---|---:|---:|
| bool | left | 1 | 1.06 |
| int32 | left | 1 | 1.07 |
| int64 | left | 1 | 1.04 |
| float32 | left | 1 | 1.31 |
| float64 | left | 1 | 1.68 |
| bool | left | 2 | 0.80 |
| int32 | left | 2 | 0.78 |
| int64 | left | 2 | 0.82 |
| float32 | left | 2 | 0.81 |
| float64 | left | 2 | 0.88 |
| bool | left | 3 | 115.65 |
| int32 | left | 3 | 230.50 |
| int64 | left | 3 | 229.20 |
| float32 | left | 3 | 277.25 |
| float64 | left | 3 | 192.30 |
| bool | left | 4 | 107.90 |
| int32 | left | 4 | 227.40 |
| int64 | left | 4 | 227.35 |
| float32 | left | 4 | 267.70 |
| float64 | left | 4 | 195.60 |
| bool | left | 5 | 107.75 |
| int32 | left | 5 | 225.05 |
| int64 | left | 5 | 224.60 |
| float32 | left | 5 | 264.75 |
| float64 | left | 5 | 190.95 |
| bool | left | 6 | 117.10 |
| int32 | left | 6 | 224.00 |
| int64 | left | 6 | 231.30 |
| float32 | left | 6 | 269.35 |
| float64 | left | 6 | 200.60 |
| bool | left | 7 | 107.35 |
| int32 | left | 7 | 218.50 |
| int64 | left | 7 | 223.95 |
| float32 | left | 7 | 263.40 |
| float64 | left | 7 | 194.30 |
| bool | left | 8 | 113.20 |
| int32 | left | 8 | 130.75 |
| int64 | left | 8 | 136.15 |
| float32 | left | 8 | 136.60 |
| float64 | left | 8 | 95.85 |
| bool | right | 1 | 1.06 |
| int32 | right | 1 | 1.04 |
| int64 | right | 1 | 1.03 |
| float32 | right | 1 | 1.09 |
| float64 | right | 1 | 1.07 |
| bool | right | 2 | 0.79 |
| int32 | right | 2 | 0.82 |
| int64 | right | 2 | 0.81 |
| float32 | right | 2 | 0.78 |
| float64 | right | 2 | 0.86 |
| bool | right | 3 | 134.50 |
| int32 | right | 3 | 230.90 |
| int64 | right | 3 | 231.15 |
| float32 | right | 3 | 237.75 |
| float64 | right | 3 | 183.55 |
| bool | right | 4 | 130.00 |
| int32 | right | 4 | 236.40 |
| int64 | right | 4 | 243.50 |
| float32 | right | 4 | 256.90 |
| float64 | right | 4 | 192.10 |
| bool | right | 5 | 142.95 |
| int32 | right | 5 | 239.75 |
| int64 | right | 5 | 240.80 |
| float32 | right | 5 | 248.30 |
| float64 | right | 5 | 186.60 |
| bool | right | 6 | 138.95 |
| int32 | right | 6 | 243.45 |
| int64 | right | 6 | 247.80 |
| float32 | right | 6 | 321.60 |
| float64 | right | 6 | 189.60 |
| bool | right | 7 | 133.05 |
| int32 | right | 7 | 270.90 |
| int64 | right | 7 | 234.95 |
| float32 | right | 7 | 240.30 |
| float64 | right | 7 | 191.15 |
| bool | right | 8 | 130.60 |
| int32 | right | 8 | 205.20 |
| int64 | right | 8 | 219.65 |
| float32 | right | 8 | 170.80 |
| float64 | right | 8 | 94.35 |

## Reproduce and raw evidence

Build/validate a GNU 14 release directory. Compile
`benchmarks/benchmark_search_dtypes.f90` against its core objects and module
directory; run with `taskset -c 0`. Set `FRUMPY_LIBRARY` to that shared library,
`PYTHONPATH=python`, `OPENBLAS_NUM_THREADS=1` and `OMP_NUM_THREADS=1`:

```sh
.venv/bin/python benchmarks/compare_search_dtypes.py --source-commit 6329097 --output after.json
.venv/bin/python benchmarks/compare_search_dtypes.py --source-commit 6329097 --reverse --output after-reverse.json
```

For the preserved baseline, pass `--only-float64 --source-commit 2ff58eb`.
[Native samples](native.txt), [first interface round](after-1.json),
[reverse round](after-2.json), [baseline one](baseline-1.json),
[baseline two](baseline-2.json) retain all samples. [Provenance](provenance.json)
records host, source and executable hashes. Unsupported mixed-dtype queries
are rejected explicitly rather than silently routed through NumPy.
