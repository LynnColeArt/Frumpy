# Float32 Euclidean and Frobenius norms — 2026-10-27

Implementation: `bc5e0b7`. NumPy oracle: 2.4.6. Native `vector_norm_r32` and
`matrix_norm_r32`, C ABI `frumpy_norm`, and Python `linalg.vector_norm` /
`linalg.matrix_norm` now support float32. This adds functionality; there was no
previous float32 norm implementation. Timings compare the new path with existing
float64 Frumpy and NumPy, not an unsupported before-version.

The new path delivers float32 storage and robust accumulation, not a throughput
speedup over float64. A contiguous 65,536-element vector takes **480–485 µs**
through Python, **459–468 µs** through C, and **455–495 µs** natively in the
reference-linked runs. Python float64 takes **472 µs** on the same case; NumPy
float32 takes **20 µs** with its different direct-square numerical policy.
For 128×128 Frobenius norm, Python float32 takes **156–169 µs**, versus NumPy's
**6–7 µs**. These substantial throughput gaps remain visible for future review.

## Settled numerical policy

- **Float32 input and result; scaled sequential float64 accumulation.** Each
  value is widened on read. Scale, normalized square sum, square root and final
  rescaling use real64; the result is rounded once to real32.
- No full-size widened input or product buffer. Inputs retain their values,
  ownership and signed/zero strides; outputs are independent C-order arrays.
- Shape/axis/keepdims rules match the existing bounded float64 API. Vector norm
  accepts no axis (flatten) or one axis; matrix norm accepts two distinct axes.
  Matrix input rank must be at least two. No extra p/spectral/complex norms or
  integral-input promotion is added. C ABI version remains 1.
- Empty/all-zero reductions produce positive zero. NaN dominates infinity.
  True out-of-range float32 results produce infinity; final rounding may produce
  subnormal/zero values. Existing float64 implementation is unchanged.
- Scaling and widening improve robustness, but this is not compensated summation,
  a universal error bound, or bitwise NumPy equivalence. Signed cancellation does
  not occur in a sum of squared magnitudes; small-contribution loss is the
  relevant accuracy stress case. Fast-math/trapping modes are outside the contract.

See [the full API policy](../../LINEAR_ALGEBRA.md#float32-norm-policy).

## Accuracy diagnostics

NumPy returns float32, but its float32 squaring can overflow/underflow before the
square root. Ordinary cases are checked against NumPy; extreme cases and long
reductions use float64 arithmetic rounded to float32. For the finite float32
inputs used here, that reference's squares/sum fit safely in float64.

| Case | Frumpy float32 | NumPy float32 | Rounded float64 reference |
| --- | ---: | ---: | ---: |
| ordinary | 5.0 | 5.0 | 5.0 |
| square_overflow | 1.4142135130433894e+30 | inf | 1.4142135130433894e+30 |
| square_underflow | 1.4142135555081815e-30 | 0.0 | 1.4142135555081815e-30 |
| subnormal | 1.401298464324817e-45 | 0.0 | 1.401298464324817e-45 |
| result_overflow | inf | inf | inf |
| nan_dominates_inf | nan | nan | nan |
| signed_zero | 0.0 | 0.0 | 0.0 |
| small_contributions_4096 | 4096.5 | 4096.498046875 | 4096.5 |
| small_contributions_65536 | 4103.9921875 | 4103.990234375 | 4103.9921875 |
| small_contributions_1048576 | 4222.06005859375 | 4222.05810546875 | 4222.06005859375 |

The small-contribution cases contain `[4096, 1, ..., 1]` with the indicated
number of ones. All listed Frumpy results match the rounded reference; this
finite diagnostic set is not a proof of correctly rounded norms in general.

## Validation

All six GNU13/GNU14/Flang19 debug/release profiles passed **4,480 Python tests**,
**38 native programs**, two examples and the standalone C caller. The 120 norm
tests cover C/F layouts, offset/stepped/reversed/broadcast views, scalar and empty
inputs, default/custom/negative axes, keepdims, IEEE values, precision differences
and unsupported integral inputs. Native tests cover ownership, lifetime,
malformed bounds/dtype, missing storage, optional status and output-byte overflow.
One-thread OpenBLAS passed all 4,480 tests. Native memory/overflow gates pass;
1,806 combined tests plus the final three rejection tests pass under each of
ASan and UBSan. fpm passes, and an isolated source install passes 366 package tests.
[Validation manifest](../../validation/float32-norms-2026-10-27.json) retains log
hashes and scope. Python ASan leak detection is off; native/C checks enable it.
Hosted CI and other platforms are not claimed.

## Timing method

GNU14 release (`-std=f2018 -O3 -fimplicit-none`), CPU affinity 0, one backend
thread. No builds/tests overlap timing. C/Python workloads have seven samples
after warmup/calibration; the tables show ranges of two run medians in **µs/call**.
Run two reverses backend, dtype, case and C/Python/NumPy workload order. Native
benchmarks have seven CPU-time samples with fixed case order; each includes
result allocation/release, status and one-element checks.

Timing inputs are exactly representable constant 0.5 values, so the scaled
kernel changes scale only at the first nonzero value. These bounded cases do not
characterize every distribution; accuracy tests separately exercise varying
magnitudes and IEEE extremes. Setup/import and correctness checks are untimed. Python/C inputs already exist
as handles; calls include result allocation/release. C measurements use ctypes.
Native and C/Python run in separate processes with different allocation histories;
absolute timing differences are not isolated language-boundary overhead.

Frumpy norms do not call BLAS. Reference and OpenBLAS linkage runs are controls
for the linked environment; differences are not evidence of BLAS acceleration.
NumPy uses its own wheel backend, recorded in each JSON. Its faster direct-square
float32 reduction has a different robustness/accumulation contract. No raw-BLAS
norm comparison is presented because no backend norm routine is dispatched.

## Python/C and NumPy: float32, reference-linked run

| Operation / shape | Layout | Python µs | C ABI µs | NumPy µs |
| --- | --- | ---: | ---: | ---: |
| vector 16 | C | 11.83–12.46 | 3.57–3.60 | 2.51–2.53 |
| vector 16 | step | 11.88–12.26 | 3.55–3.56 | 2.67–2.68 |
| vector 65536 | C | 479.73–485.30 | 459.28–467.93 | 19.69–19.69 |
| vector 65536 | step | 476.77–483.56 | 459.97–466.49 | 34.94–37.07 |
| vector 1048576 | C | 7379.96–7714.82 | 7251.47–7414.47 | 228.51–246.91 |
| vector 1048576 | step | 7404.37–7416.80 | 7322.71–7392.16 | 506.45–2398.69 |
| matrix 128×128 | C | 155.93–169.37 | 143.47–148.21 | 6.20–6.58 |
| matrix 128×128 | step | 157.34–158.21 | 142.30–157.21 | 10.64–12.15 |
| vector_axis 16×64×64 | C | 491.27–499.99 | 480.88–481.78 | 28.70–29.71 |
| vector_axis 16×64×64 | step | 509.87–559.05 | 484.51–524.14 | 43.53–43.79 |
| matrix_batch 16×64×64 | C | 562.53–591.67 | 568.65–832.10 | 19.04–19.77 |
| matrix_batch 16×64×64 | step | 579.82–659.03 | 556.58–575.33 | 32.50–34.19 |

## Float32 versus float64: Python timings

Both Frumpy paths use scaled real64 accumulator state; this is primarily a dtype
coverage and payload-size comparison, not a promise of faster arithmetic.

| Linked environment | Operation / shape | Layout | Float32 µs | Float64 µs |
| --- | --- | --- | ---: | ---: |
| reference | vector 16 | C | 11.83–12.46 | 11.86–12.61 |
| reference | vector 16 | step | 11.88–12.26 | 11.94–12.28 |
| reference | vector 65536 | C | 479.73–485.30 | 471.75–472.45 |
| reference | vector 65536 | step | 476.77–483.56 | 469.34–471.34 |
| reference | vector 1048576 | C | 7379.96–7714.82 | 7192.99–7802.04 |
| reference | vector 1048576 | step | 7404.37–7416.80 | 7232.80–7264.22 |
| reference | matrix 128×128 | C | 155.93–169.37 | 152.27–157.01 |
| reference | matrix 128×128 | step | 157.34–158.21 | 153.43–158.88 |
| reference | vector_axis 16×64×64 | C | 491.27–499.99 | 494.09–496.38 |
| reference | vector_axis 16×64×64 | step | 509.87–559.05 | 503.84–563.55 |
| reference | matrix_batch 16×64×64 | C | 562.53–591.67 | 564.65–584.67 |
| reference | matrix_batch 16×64×64 | step | 579.82–659.03 | 561.34–570.77 |
| openblas | vector 16 | C | 11.74–11.75 | 11.91–11.91 |
| openblas | vector 16 | step | 11.88–11.98 | 11.88–12.21 |
| openblas | vector 65536 | C | 469.82–471.78 | 464.07–465.71 |
| openblas | vector 65536 | step | 473.83–480.47 | 466.03–480.18 |
| openblas | vector 1048576 | C | 7224.08–7334.27 | 7117.62–7172.78 |
| openblas | vector 1048576 | step | 7376.36–7653.92 | 7193.37–7216.57 |
| openblas | matrix 128×128 | C | 148.89–153.42 | 151.38–160.14 |
| openblas | matrix 128×128 | step | 151.12–152.79 | 151.33–160.88 |
| openblas | vector_axis 16×64×64 | C | 494.86–502.54 | 490.37–494.54 |
| openblas | vector_axis 16×64×64 | step | 495.52–501.85 | 489.73–494.26 |
| openblas | matrix_batch 16×64×64 | C | 567.55–582.49 | 567.54–570.09 |
| openblas | matrix_batch 16×64×64 | step | 572.13–574.02 | 565.91–579.90 |

## Native Fortran

| Linked environment | Operation / size | Layout | Float32 µs | Float64 µs |
| --- | --- | --- | ---: | ---: |
| reference | vector 16 | C | 0.90–0.91 | 0.88–0.97 |
| reference | vector 16 | step | 0.92–0.99 | 0.87–0.97 |
| reference | vector 65536 | C | 455.00–495.05 | 440.40–450.35 |
| reference | vector 65536 | step | 457.15–464.35 | 440.85–444.20 |
| reference | vector 1048576 | C | 7252.60–7478.15 | 7104.25–7143.45 |
| reference | vector 1048576 | step | 7323.00–7366.95 | 7151.05–7609.85 |
| reference | matrix 128 | C | 138.55–140.50 | 134.55–137.45 |
| reference | matrix 128 | step | 136.70–139.85 | 132.45–132.80 |
| openblas | vector 16 | C | 0.86–0.90 | 0.84–0.89 |
| openblas | vector 16 | step | 0.86–0.89 | 0.86–0.91 |
| openblas | vector 65536 | C | 455.75–462.30 | 446.70–448.40 |
| openblas | vector 65536 | step | 455.00–467.60 | 436.85–449.30 |
| openblas | vector 1048576 | C | 7325.30–7426.60 | 7036.00–7620.10 |
| openblas | vector 1048576 | step | 7259.45–7269.80 | 7063.80–7250.80 |
| openblas | matrix 128 | C | 137.10–138.45 | 133.60–134.35 |
| openblas | matrix 128 | step | 137.85–138.35 | 134.40–135.00 |

## Costs and limitations

Float32 halves logical input/result payload relative to float64, without an
8-byte-per-element widening buffer. Stepped benchmark owners have twice the
logical last dimension; reported input bytes are logical view bytes, not RSS.
Fixed-size axis metadata and scalar accumulator state remain. Every reduction
still performs general stride addressing and scaled arithmetic per element.

NumPy is a throughput comparator, not an equal-algorithm baseline. If throughput
later matters, norm traversal and accumulation deserve a separate profile-led
pass with these robustness tests retained. This functionality pass does not
optimize those loops or change existing dot/matmul/solve policies.

## Reproduction and raw evidence

[run-benchmarks.sh](run-benchmarks.sh) records backend environment and run order.
Use `benchmarks/compare_float32_norms.py --output <path>` and repeat with
`--reverse`, supplying `FRUMPY_LIBRARY`, `PYTHONPATH=python`, backend
`LD_LIBRARY_PATH` and single-thread variables. Compile
`benchmarks/benchmark_norms_precision.f90` against the same release core objects
and run with `taskset -c 0`. Accuracy diagnostics are generated by
`benchmarks/check_float32_norm_accuracy.py`.

- [accuracy.json](accuracy.json)
- [native-openblas-1.txt](native-openblas-1.txt)
- [native-openblas-2.txt](native-openblas-2.txt)
- [native-reference-1.txt](native-reference-1.txt)
- [native-reference-2.txt](native-reference-2.txt)
- [openblas-1.json](openblas-1.json)
- [openblas-2.json](openblas-2.json)
- [reference-1.json](reference-1.json)
- [reference-2.json](reference-2.json)
