# Five-dtype masking validation

Base: `b00967a` (PR #4 merged). Scope: full-shape mask extraction, same-dtype
basic-view assignment and boolean-mask assignment across native Fortran, C and
Python. See [the contract](../MASKING_DTYPES.md). No version bump, release tag or
publication is included.

## Evidence

- GNU 14 strict debug: 43 native programs, two examples, C ownership checks and
  8,229 Python tests pass (12 expected numerical warnings).
- GNU 13 and GNU 14, each in debug and optimized profiles, pass the full
  validation gate. Final hosted checks repeat these profiles and add Flang 19
  and OpenBLAS on the review commit.
- 258 focused masking tests pass across the native differential driver, direct
  ABI and public Python API. They include scalar/empty cases, signed/zero/stepped
  strides, F order/transposes, exact int64 values, float payload bits, dtype and
  shape rejection, overlapping RHS and masks, and result lifetime.
- Native ASan/leak checks pass, including the new five-dtype indexing program;
  the compiled differential suite passes 2,647 tests. C/Python ASan passes 5,554
  cases. Python-process leak detection is disabled; native leak detection is on.
- Integer-overflow gate passes, including the new native program and 2,159
  selected differential cases. All 258 masking cases also pass against separate
  UBSan-instrumented native/C builds.
- Seven injected failures cover explicit mask-assignment allocations (positions,
  staging descriptor and owned storage): each returns allocation status and
  leaves the target unchanged; a subsequent assignment succeeds. This runs under
  native ASan/leak checks. Compiler-generated constructor-result metadata copies
  remain outside recoverable failure injection, as in the existing contract.
- The native staging-byte-overflow regression passes in debug and UBSan builds
  using a huge zero-stride logical view backed by four values, without a huge
  allocation or target mutation.
- A source archive installs without cache into a fresh environment outside the
  repository. All 396 public package tests pass with Python `-I`, without checkout
  imports or library override variables. The new five package regressions persist
  in the normal installation gate.
- A reproducible [public-API timing baseline](../performance/masking-2026-10-29/README.md)
  records costs without making a performance improvement claim.
- No fresh macOS validation is claimed. Flang is provided by hosted CI.

Local environment: Linux x86-64, Python 3.12.3, NumPy 2.4.6, GNU Fortran 13/14;
reference LP64 BLAS/LAPACK (`-l:liblapack.so.3 -l:libblas.so.3`).

```sh
make validate FC=gfortran-14 BUILD_DIR=build/masking/debug
make memory-test integer-overflow-test c-memory-test FC=gfortran-14 BUILD_DIR=build/masking
bash scripts/validate_compilers.sh build/masking/portability gfortran-13 gfortran-14
```

## Review boundaries

The deliberate NumPy difference is snapshot-based masked assignment when the RHS
or mask aliases the target. The new generic native API uses immutable descriptor
dummies and mutates only pointed-to payloads, permitting identical descriptors.
Legacy typed float64 entry points remain unchanged. C ABI v1 gains one additive
symbol; the new Python package must be paired with the updated shared library.
Mask shape must exactly match the target, and assignment does not cast dtypes.
