# Remaining v0.1 optimization queue — 2026-10-27

The bounded queue is complete at `f1b9e05`: nonuniform floating arithmetic,
handle lookup/FFI overhead, and matched BLAS/packing experiments. This is a
measured stopping point, not a claim that every operation is fully optimized.

## Changes and decisions

- Same-dtype float32/float64 nonuniform arithmetic processes rows of four or
  more elements with the existing signed-stride kernel. Outer indexing happens
  once per row. No payload copies, reassociation, or fast-math were added.
- The C ABI indexes live handles in hash buckets instead of scanning a global
  list. IDs remain monotonic and never reused; retaining/releasing and owner
  lifetimes retain their contract. Failed growth keeps the old index usable;
  failed initial allocation returns an allocation status with output handle zero.
  The table is freed with the last handle. At roughly 8,192 live handles its
  bucket storage is about 64 KiB, additional to existing descriptor storage.
- Loaded Python FFI calls skip the redundant initialization lock; C calls remain
  serialized. No result-reuse or metadata-cache API was introduced.
- Both-C-contiguous rank-two matmul uses `C^T = B^T A^T` with DGEMM NN and
  writes into the owned C result. Both-F-contiguous inputs bypass input packing
  but retain one backend output buffer. Mixed, irregular, vector and batched
  cases keep the packed NN fallback.
- An attempted TT call eliminated more output copying but made reference-BLAS
  512-square F/stepped cases about five times slower. It was rejected. The
  representative raw experiment is retained in `rejected-tt/`; it is not the
  final implementation or part of the final speedup calculations.
- OpenBLAS exposed an existing empty-RHS singularity discrepancy: DGESV could
  return without factoring A when NRHS was zero. A dummy zero-filled workspace
  column now forces factorization, while the public result remains empty.

## Measurement method

The whole-queue baseline is `42fa9a9` (numerical core `f8882d5`), compared with
`f1b9e05`. GNU 14 uses `-std=f2018 -O3 -fimplicit-none`. Each backend runs in
before/after then after/before order, seven warmed samples per case, pinned to
one available CPU. Calls allocate and release their result; setup and export
are outside timing. All our build/test jobs were stopped during measurement.
Wall and process CPU samples are retained. These are local observations, not
portable performance guarantees or statistical confidence intervals.

Reference LP64 BLAS/LAPACK and Ubuntu OpenBLAS 0.3.26 LP64 pthread are tested
separately, with one thread. Raw CBLAS/DGESV calls load the same library as
Frumpy; `ldd`, hashes, affinity and configuration are in every report. Raw DGEMM
uses pre-created C inputs and allocates its output, omitting Frumpy metadata and
finite checks; it does not reproduce the F-layout packing algorithm. Raw solve
copies inputs into destructive backend workspaces. NumPy 2.4.6 uses its own
wheel OpenBLAS backend and is a separate reference, not a matched-backend claim.

The registry experiment isolates the registry change using a saved library
with the final NN numerical core and the pre-index `frumpy_c_handles` module
from `0dba0dc`, versus the indexed core at `15892ae`. The Python wrapper is held
constant. Its 16-element linear add is unaffected by the later row threshold.
Hashes are retained in `registry-*.json`; these are two alternating-order runs.

## Repeated results

Ranges below span the two run medians, in microseconds. “Gain” is the fastest
baseline median divided by the slowest final median: a conservative observed
ratio, not a confidence bound. Values below 1 retain the slower observations.

### Reference backend

| Workload | Before µs | After µs | Gain |
| --- | ---: | ---: | ---: |
| Add 1024×1 row | 12.61–12.65 | 11.85–13.85 | 0.91× |
| Add 1024×1 column | 12.13–13.82 | 12.57–12.94 | 0.94× |
| Add 1024×1 transpose | 11.17–13.67 | 12.35–12.64 | 0.88× |
| Add 1024×1 reverse_rows | 11.50–12.46 | 10.99–11.70 | 0.98× |
| Add 1024×4 row | 73.43–105.29 | 22.50–23.68 | 3.10× |
| Add 1024×4 column | 83.98–92.10 | 23.59–23.71 | 3.54× |
| Add 1024×4 transpose | 79.65–81.39 | 26.94–27.27 | 2.92× |
| Add 1024×4 reverse_rows | 78.28–85.56 | 23.12–26.03 | 3.01× |
| Add 1024×8 row | 143.28–148.80 | 24.72–29.30 | 4.89× |
| Add 1024×8 column | 149.07–153.92 | 25.88–26.38 | 5.65× |
| Add 1024×8 transpose | 143.86–150.62 | 27.21–27.78 | 5.18× |
| Add 1024×8 reverse_rows | 141.07–144.09 | 25.38–26.17 | 5.39× |
| Add 256×1024 row | 3811.62–3835.66 | 117.29–117.74 | 32.37× |
| Add 256×1024 column | 3852.42–4695.45 | 116.82–118.45 | 32.52× |
| Add 256×1024 transpose | 4099.38–4524.52 | 418.64–422.88 | 9.69× |
| Add 256×1024 reverse_rows | 3946.61–3981.93 | 127.09–137.97 | 28.60× |
| matmul 16² C | 13.05–13.51 | 14.85–15.29 | 0.85× |
| matmul 16² F | 13.26–15.36 | 12.74–15.94 | 0.83× |
| matmul 16² stepped | 15.17–15.74 | 13.62–16.12 | 0.94× |
| solve 16² C | 18.31–18.57 | 18.31–18.54 | 0.99× |
| matmul 128² C | 1136.14–1225.07 | 1156.29–1261.25 | 0.90× |
| matmul 128² F | 1122.43–1241.71 | 1180.31–1351.92 | 0.83× |
| matmul 128² stepped | 1147.68–1490.93 | 1166.46–1252.60 | 0.92× |
| solve 128² C | 1623.30–1701.43 | 1580.73–1691.77 | 0.96× |
| matmul 512² C | 72807.29–85899.12 | 68914.71–77142.31 | 0.94× |
| matmul 512² F | 68379.01–73101.82 | 66533.02–67891.71 | 1.01× |
| matmul 512² stepped | 73442.09–93589.58 | 72374.09–77161.55 | 0.95× |
| solve 512² C | 98059.71–100903.92 | 99110.33–99848.70 | 0.98× |
| public_add | 11.01–22.35 | 10.97–12.79 | 0.86× |
| checked_ffi | 3.95–7.20 | 3.73–3.93 | 1.00× |

### Openblas backend

| Workload | Before µs | After µs | Gain |
| --- | ---: | ---: | ---: |
| matmul 16² C | 13.28–14.68 | 12.18–13.07 | 1.02× |
| matmul 16² F | 12.88–13.02 | 11.56–13.51 | 0.95× |
| matmul 16² stepped | 13.30–14.29 | 11.68–12.75 | 1.04× |
| solve 16² C | 16.90–26.46 | 14.17–15.81 | 1.07× |
| matmul 128² C | 151.35–153.02 | 106.89–107.30 | 1.41× |
| matmul 128² F | 153.22–172.32 | 123.35–146.49 | 1.05× |
| matmul 128² stepped | 155.58–174.95 | 155.69–177.90 | 0.87× |
| solve 128² C | 257.27–304.21 | 285.91–411.94 | 0.62× |
| matmul 512² C | 11426.36–13068.59 | 5066.18–5311.13 | 2.15× |
| matmul 512² F | 6976.76–7174.35 | 5707.29–6138.94 | 1.14× |
| matmul 512² stepped | 7257.67–7695.03 | 7869.57–8972.18 | 0.81× |
| solve 512² C | 10641.35–10786.33 | 10512.94–11215.35 | 0.95× |
| public_add | 11.36–20.50 | 10.50–13.56 | 0.84× |
| checked_ffi | 3.98–4.58 | 3.93–4.40 | 0.90× |

### Registry scaling

| Other live arrays | Layer | Before µs | After µs | Gain |
| ---: | --- | ---: | ---: | ---: |
| 0 | raw | 2.66–2.75 | 2.75–2.85 | 0.93× |
| 0 | public | 11.36–11.94 | 12.08–12.58 | 0.90× |
| 0 | retain_release | 0.81–0.83 | 0.84–1.54 | 0.53× |
| 64 | raw | 3.08–3.36 | 3.19–3.22 | 0.95× |
| 64 | public | 14.48–15.35 | 13.16–13.68 | 1.06× |
| 64 | retain_release | 1.33–1.92 | 0.82–0.88 | 1.50× |
| 1024 | raw | 8.93–8.96 | 2.91–2.94 | 3.03× |
| 1024 | public | 21.29–28.50 | 12.48–13.41 | 1.59× |
| 1024 | retain_release | 6.13–6.74 | 0.87–1.46 | 4.18× |
| 8192 | raw | 46.21–47.85 | 3.14–3.95 | 11.68× |
| 8192 | public | 58.80–58.91 | 11.44–13.52 | 4.35× |
| 8192 | retain_release | 44.57–44.68 | 0.86–0.97 | 45.83× |

### Interpretation and limits

The strongest repeatable changes are wider nonuniform arithmetic, handle lookup
with many live arrays, and C-contiguous matmul on OpenBLAS. Four-element rows
also improve about threefold. Tiny operations have no universal latency gain;
the index can add overhead when there are few live handles. Reference-BLAS
matrix timing is broadly dominated by the backend and does not establish a
consistent speedup from packing changes alone.

Slower observations are retained: reference 16-square C matmul rises from
13.05–13.51 to 14.85–15.29 µs; OpenBLAS 512-square stepped matmul rises from
7.26–7.70 to 7.87–8.97 ms, and 128-square solve spans 257–304 before versus
286–412 µs after. These fallback paths remain unoptimized; this experiment does
not establish the cause of every difference. Process CPU medians track wall
medians closely, so descheduling alone does not explain their variation. Treat
these cases as follow-up regression workloads rather than claiming every path
improved. The copy savings and large row/index gains justify retaining this
bounded change, with these limitations visible for review.

Backend choice has a larger effect than packing on large dense matrices:
final 512-square C matmul is 5.07–5.31 ms with OpenBLAS versus 68.91–77.14 ms
with reference BLAS on this host. LP64 OpenBLAS is therefore a useful optional
configuration for matrix-heavy workloads. This result does not choose thread
counts, deployment packaging, or change the default backend.

## Correctness and lifetime validation

[Machine-readable validation](../../validation/queue-2026-10-27.json) records
35 native programs, two examples, 3,078 Python tests and the C caller passing in
all six GNU 13/14 and Flang 19 debug/release configurations. GNU 14 release also
passes the full suite with LP64 OpenBLAS. GNU 14 memory and overflow gates pass
2,643 and 2,159 differential cases; ABI/package ASan and UBSan each pass 407.
Standalone C leak detection, registry allocation-failure recovery on both
backends, and fpm's 35 native programs pass. Python ASan leak detection is off;
backend libraries themselves are not sanitizer-built. An OpenBLAS CI job is
configured; hosted CI execution is not claimed.

## Allocation and memory costs

Warmed glibc-interposer measurements at 16×16 count native allocation requests,
not all Python allocator activity or process RSS:

| C ABI operation | Before requests / bytes | After requests / bytes |
| --- | ---: | ---: |
| 16-element add | 29 / 689 | 29 / 689 |
| C matmul | 35 / 8,850 | 32 / 2,706 |
| F matmul | 35 / 8,850 | 33 / 4,754 |
| Solve | 35 / 6,866 | 35 / 6,866 |

C matmul removes three matrix work arrays; F matmul removes two. At 512-square
float64 these save 6 MiB and 4 MiB respectively. Solve still needs destructive
backend workspaces. Warmed counts exclude initial registry allocation/growth;
its separate bucket-memory tradeoff is described above. Full Python and C counts
are retained in `alloc-*.json`.

## Explicitly deferred

Mixed-dtype/integer/boolean arithmetic and very narrow nonuniform rows keep the
general fallback. Mixed/irregular/batched matmul packing and solve workspace
remain. More invasive combined metadata/operation APIs, result reuse and caching
need workload evidence before changing the public interface. Multithreading,
backend packaging/default selection and further compiler-specific tuning remain
separate decisions. The next product work can follow the numeric-coverage and
distribution slices in [the roadmap](../../POST_V0_1_PLAN.md).

## Reproduction

Build independent baseline/final checkouts with the flags above. For each,
point `PYTHONPATH` at that checkout's `python` directory and `FRUMPY_LIBRARY` at
its shared library. Run the final `benchmarks/compare_queue.py` harness with
`--label`, `--output`, `--blas` and `--lapack` pointing at the selected LP64
libraries. Set `LD_LIBRARY_PATH` consistently and inspect recorded `ldd` output.
Run baseline/final then final/baseline, with no concurrent builds. Use
`benchmarks/compare_registry.py` for live-handle scaling and
`benchmarks/count_allocations.py --operation matmul --layout C` with the existing
glibc allocation interposer for the allocation experiment. The Make target
`registry-allocation-test` exercises first allocation and growth recovery.
