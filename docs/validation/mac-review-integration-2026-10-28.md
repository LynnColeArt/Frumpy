# macOS review fix integration

Integrated the Darwin install-name and portable-oracle fixes from
[review #1](https://github.com/LynnColeArt/Frumpy/issues/1#issuecomment-6469008558)
against baseline `efc298fd36953d6bf96aa7993290e861dd8142ef`. The signed-zero
regression additionally checks result value, shape and dtype. No numerical
kernels or installer platform policy changed.

Linux x86-64 validation used GNU Fortran 14.2.0, Python 3.12.3 and NumPy 2.4.6:

```sh
make validate FC=gfortran-14 BUILD_DIR=build/mac-review-integration/debug \
  LINALG_LIBS='-l:liblapack.so.3 -l:libblas.so.3'
```

Result: all 41 native programs, two examples, 7,349 Python tests, the C ABI
caller and whitespace checks passed. The 12 Python warnings are NumPy oracle
warnings. The C executable also passed when launched by absolute path from
`/tmp`, outside the checkout working directory.

Local log: `build/mac-review-integration/debug.log`.
SHA-256: `0a4918e8a867639ad9eb01f7212c64dcfabd12d041871d60c998bd3bbc2f8497`.

The Darwin link change matches the patch tested by the Mac reviewer. This
integration was validated on Linux; a fresh Mac run of this exact integration,
Mac sanitizer/fpm coverage and GNU 16 failure isolation remain outstanding.
The source installer remains Linux-only.
