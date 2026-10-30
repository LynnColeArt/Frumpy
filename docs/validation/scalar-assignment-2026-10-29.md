# Scalar assignment optimization validation

Base `2cb5f2c` merges PR #5. Implementation `44d8967` captures single-element RHS
values once, removes ordinary scalar staging, and retains masked destination
snapshots. [Performance evidence](../performance/scalar-assignment-2026-10-29/README.md)
includes matching native, C and Python before/after runs.

- GNU 13 and GNU 14, debug and optimized: full validation passes, including
  43 native programs, examples, C ownership checks and 8,288 Python tests.
- 317 focused masking/scalar tests pass with optimized C and debug native builds;
  all 317 also pass with UBSan-instrumented native and C builds.
- Native ASan/leak checks and the 2,647-case compiled differential suite pass.
  C/Python ASan passes 5,613 cases (Python leak checking disabled; native enabled).
- Integer-overflow tests pass, including 2,159 selected differential cases and
  native malformed-storage, repeated-position and huge zero-stride cases.
- The allocation-injection test failed on the baseline ('scalar fill must not
  allocate') and passes after the change. Ordinary scalar assignment succeeds
  with allocations disabled. Masked scalar assignment fails atomically when its
  position allocation fails and succeeds when only that one allocation is allowed.
  The seven existing nonscalar staging failure/recovery tests remain passing.
- Shape expansion and multidimensional masked RHS rejection remain unchanged.
  Aliased scalar views, bool normalization, signed-zero/NaN payloads, empty
  selections, reversed/stepped/F/irregular layouts and nonscalar overlap paths pass.
- A fresh source archive installs without cache outside the repository. All
  396 public package tests pass under Python `-I`, without checkout/library
  override variables.
- `git diff --check` passes. Hosted CI repeats the final commit and adds Flang
  and OpenBLAS. No new macOS validation or release publication is claimed.

Local environment: Linux x86-64, Python 3.12.3, NumPy 2.4.6, GNU 13/14; reference
LP64 BLAS/LAPACK (`-l:liblapack.so.3 -l:libblas.so.3`).

```sh
make validate FC=gfortran-14 BUILD_DIR=build/scalar-assignment/debug
make memory-test integer-overflow-test c-memory-test FC=gfortran-14 BUILD_DIR=build/scalar-assignment
bash scripts/validate_compilers.sh build/scalar-assignment/portability gfortran-13 gfortran-14
```

Compiler-generated temporary allocation limits are unchanged. Fast paths validate
metadata and use actual strides, not cached flags. No target storage is replaced;
masked positions and the scalar value are captured before any mutation. A valid
huge zero-stride scalar fill now succeeds in constant space; nonscalar oversized
staging is still rejected without changing the target.
