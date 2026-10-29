# Contiguous arithmetic and reductions — 2026-10-27

Before kernel: `61a6bba` (unchanged through `a1a9d15`). After: `1d83bc3`.
Both runs use the same Python wrapper and benchmark harness at `1d83bc3`.
The raw source_head identifies that checkout, while SHA-256 hashes identify the
frozen before/after libraries and native drivers. All four measured checkouts
were clean.

GNU 14, `-std=f2018 -O3 -fimplicit-none`, no fast-math; AMD Ryzen 5 5600X;
NumPy 2.4.6. Two sequential before/after pairs, each with seven warmed samples,
single-CPU affinity and thread settings fixed at one. No Frumpy builds or tests
ran during timing. Calls include result allocation and release; input creation,
imports and exports are excluded. Individual heap allocations are not counted.
The host was not otherwise dedicated to benchmarking.

Tables show the range of the two run medians. The conservative gain divides
the fastest before median by the slowest after median; it is an observed
comparison, not a confidence interval or a portable speed guarantee. A value
below one includes a slowdown. Raw files retain every sample and NumPy control.

## Implementation and numerical behavior

- Same-dtype float32/float64 add, subtract, multiply and divide use shared linear
  kernels in both the concrete native APIs and the mixed dispatcher used by Python.
  Eligible operands traverse the broadcast output in C order with step one or
  zero (a constant broadcast). Selection derives from shape and strides, ignores
  singleton strides, honors offsets and never trusts cached contiguity flags.
  Operation selection moves outside the element loop. Cross-dtype arithmetic,
  row/column broadcasting and other layouts keep their general traversal.
- Float64 all-axis C-contiguous reductions and unit-stride axis slices validate
  their range once and read linearly. Sum/mean/product retain sequential order;
  min/max retain the existing comparison, NaN and signed-zero behavior. Scalar
  and empty cases still use their original branches.
- Float32 all-axis C-contiguous sum/mean skip per-element division/modulo for
  addressing, retaining exactly the same recursive pairwise tree and sequential
  leaves of at most eight values. Float32 product/extrema and noncontiguous
  reductions are not optimized in this change.
- No input packing, new payload/scratch buffers, backend changes, parallelism or
  fast-math. This does not promise bitwise NumPy sums: Frumpy's documented
  reduction orders remain unchanged.

## Native calls

| Operation / dtype / layout | Elements | Before (ms) | After (ms) | Conservative gain |
| --- | ---: | ---: | ---: | ---: |
| add_r64 / contiguous | 1,024 | 0.0116–0.0133 | 0.0023–0.0027 | 4.4× |
| add_r64 / reverse | 1,024 | 0.0111–0.0130 | 0.0144–0.0146 | 0.8× |
| add_r64 / stride2 | 1,024 | 0.0132–0.0142 | 0.0145–0.0160 | 0.8× |
| add_r64 / broadcast | 1,024 | 0.0108–0.0127 | 0.0023–0.0025 | 4.3× |
| add_r32 / contiguous | 1,024 | 0.0051–0.0070 | 0.0023–0.0024 | 2.1× |
| sum_r64 / contiguous | 1,024 | 0.0063–0.0081 | 0.0023–0.0023 | 2.8× |
| sum_r64 / stride2 | 1,024 | 0.0068–0.0077 | 0.0064–0.0082 | 0.8× |
| add_r64 / contiguous | 1,048,576 | 10.4696–11.4450 | 0.8330–0.8846 | 11.8× |
| add_r64 / reverse | 1,048,576 | 10.8570–12.6598 | 11.3098–12.5604 | 0.9× |
| add_r64 / stride2 | 1,048,576 | 10.4768–11.4834 | 11.8359–12.6118 | 0.8× |
| add_r64 / broadcast | 1,048,576 | 11.8005–12.0623 | 0.5506–0.5636 | 20.9× |
| add_r32 / contiguous | 1,048,576 | 3.8297–3.8542 | 0.4614–0.4801 | 8.0× |
| sum_r64 / contiguous | 1,048,576 | 5.8585–5.9823 | 0.7215–0.7948 | 7.4× |
| sum_r64 / stride2 | 1,048,576 | 5.6664–5.8850 | 5.2108–6.0364 | 0.9× |

## Public Python calls

The `axis` cases reshape the input to rows of 128 elements and reduce the last
axis. The broadcast cases use a scalar right operand. Result allocation remains
inside timing. The native and Python addition paths previously used different
implementations, so their original difference was not purely Python overhead.

| Operation / dtype / layout | Elements | Before (ms) | After (ms) | Conservative gain |
| --- | ---: | ---: | ---: | ---: |
| add / float32 / contiguous | 1,048,576 | 17.0976–29.1127 | 0.4364–0.5443 | 31.4× |
| subtract / float32 / contiguous | 1,048,576 | 25.1149–26.7116 | 0.4967–0.6285 | 40.0× |
| multiply / float32 / contiguous | 1,048,576 | 22.7631–25.5316 | 0.4545–0.5731 | 39.7× |
| divide / float32 / contiguous | 1,048,576 | 17.6438–25.1397 | 0.4393–0.4540 | 38.9× |
| sum / float32 / contiguous | 1,048,576 | 3.9266–4.9220 | 1.0087–1.1990 | 3.3× |
| mean / float32 / contiguous | 1,048,576 | 4.6796–4.9164 | 1.0841–1.1583 | 4.0× |
| add / float32 / broadcast | 1,048,576 | 19.9958–21.5537 | 0.3743–0.4543 | 44.0× |
| sum / float32 / axis | 1,048,576 | 1.7300–2.0819 | 1.6568–2.5586 | 0.7× |
| mean / float32 / axis | 1,048,576 | 1.6200–2.2325 | 1.6275–1.7371 | 0.9× |
| add / float64 / contiguous | 1,048,576 | 21.0946–24.0480 | 1.0066–1.1577 | 18.2× |
| subtract / float64 / contiguous | 1,048,576 | 24.3732–29.8835 | 0.9024–1.1786 | 20.7× |
| multiply / float64 / contiguous | 1,048,576 | 19.9612–26.8465 | 0.9070–1.0641 | 18.8× |
| divide / float64 / contiguous | 1,048,576 | 14.2283–17.2802 | 1.1711–1.2650 | 11.2× |
| sum / float64 / contiguous | 1,048,576 | 6.2581–6.5615 | 0.8070–1.1207 | 5.6× |
| mean / float64 / contiguous | 1,048,576 | 7.0212–7.9569 | 0.8127–0.8138 | 8.6× |
| add / float64 / broadcast | 1,048,576 | 18.9425–19.0862 | 0.6695–0.7745 | 24.5× |
| sum / float64 / axis | 1,048,576 | 6.7255–8.5134 | 1.4826–1.5415 | 4.4× |
| mean / float64 / axis | 1,048,576 | 7.6014–7.7003 | 1.4541–1.6434 | 4.6× |

## Small calls and fallback costs

| Operation / dtype / layout | Elements | Before (ms) | After (ms) | Conservative gain |
| --- | ---: | ---: | ---: | ---: |
| add / float32 / contiguous | 1,024 | 0.0525–0.0649 | 0.0257–0.0270 | 1.9× |
| sum / float32 / contiguous | 1,024 | 0.0220–0.0265 | 0.0211–0.0229 | 1.0× |
| add / float64 / contiguous | 1,024 | 0.0441–0.0532 | 0.0262–0.0291 | 1.5× |
| sum / float64 / contiguous | 1,024 | 0.0212–0.0320 | 0.0209–0.0241 | 0.9× |

Small additions improved, while small sums remain dominated by call/metadata
costs and noise. Float32 axis-sum ranges overlap: one pair was slower, one faster;
no improvement is claimed there.

**Strided addition showed a regression worth retaining in the record.** In the
main pairs, native stride-2 addition was 10–13% slower and Python float64 stride-2
addition was 17–56% slower. A focused check then alternated before/after order
across five pairs, using seven samples of ten calls each. Comparing the median
of those five run medians, native stride-2 addition changed from 10.94 to 11.30 ms
(about 3% slower), and Python from 18.85 to 21.00 ms (about 11% slower). The wide
spread makes the exact penalty uncertain; the focused result does not erase
the slower main-run samples. No strided speedup is claimed. Reverse addition
and strided sums also varied across pairs.

These observations make strided dispatch/code generation a follow-up alongside
small-call metadata/allocation profiling. The clear contiguous wins do not imply
that every input layout is faster. The change preserves the general fallback's
results, but its measured performance is not identical.

## Validation

All six GNU 13/14 and Flang 19 debug/release configurations pass 35 native test
programs, two examples, 2,939 Python tests and the C caller. The 100 added Python
cases cover offset/singleton/scalar/row arithmetic and bitwise reduction
agreement with strided traversal, including cancellation, signed zeros, NaNs and
infinities. Native tests cover stale contiguity flags and invalid linear ranges.
GNU 14 memory/overflow gates pass; 268 ABI/package cases pass under both ASan
and UBSan. Native r64 arithmetic/reduction programs also pass ASan with leak
detection. fpm passes all 35 native programs. See
[validation evidence](../../validation/contiguous-2026-10-27.json).

## Reproduce

Build the two revisions with identical release flags in separate directories.
Keep the current wrapper and benchmark harness constant, replace LIBRARY and
DRIVER with the corresponding absolute paths, and run sequentially:

```sh
PYTHONPATH=python FRUMPY_LIBRARY=LIBRARY .venv/bin/python benchmarks/compare_contiguous.py \
  --driver DRIVER --label before-1 --samples 7 --output before-1.json
```

Repeat with the after build, then repeat the pair. The harness verifies results
against NumPy outside timing and records compiler flags, binary hashes, affinity,
NumPy controls, result payload bytes for Python, calibration counts and samples.
Raw results: [before 1](before-1.json), [after 1](after-1.json),
[before 2](before-2.json), [after 2](after-2.json).
The [focused control](stride-control.json) and its
[script](check-stride-control.py) preserve the extra investigation; edit its local
build paths before reproducing it elsewhere.
