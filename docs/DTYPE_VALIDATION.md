# Dtype Validation

This document records the validation surface for the dtype metadata, promotion,
casting, descriptor, and closeout documentation mission.

## Canonical Command

Run the full local gate with:

```sh
make validate
```

This runs:

- Standalone Fortran tests.
- The first vertical-slice example.
- Python NumPy differential tests from `.venv/`.
- `git diff --check`.

## Focused Dtype Commands

The dtype-specific Fortran coverage is included in `make test`, but can also be
compiled and run through `make test` as these programs:

- `test/test_dtypes.f90`
- `test/test_dtype_promotion.f90`
- `test/test_casting.f90`
- `test/test_ndarray_bool.f90`
- `test/test_ndarray_i32.f90`
- `test/test_ndarray_i64.f90`
- `test/test_ndarray_r32.f90`
- `test/test_ndarray_r64.f90`

The NumPy differential dtype fixtures are:

```sh
.venv/bin/python -m pytest -q \
  python/tests/test_numpy_dtype_promotion.py \
  python/tests/test_numpy_casting.py
```

These fixtures pin the observed NumPy version to `2.4.6`.

## Stale Name Check

Current-facing Frumpy surfaces should not use the old pre-rename spelling
except in preserved historical identifiers. Run:

```sh
pattern='[fF]e'"num"'|[F]E'"NUM"
archive='kitty-specs/'"fe""num"'-numpy-compatible-array-engine-01KTB68D/**'

rg -n "$pattern" \
  README.md PROJECT_PLAN.md STYLE_GUIDE.md AGENTS.md SPEC_KITTY_HANDOFF.md \
  .kittify/charter/charter.md \
  kitty-specs/frumpy-dtype-promotion-tooling-and-roadmap-sync-01KTHYR2 \
  -g "!$archive" \
  -g '!**/acceptance-matrix.json' \
  -g '!**/lanes.json' \
  -g '!**/meta.json' \
  -g '!**/status.events.jsonl' \
  -g '!**/status.json'
```

The command should print no matches.

## Latest Local Validation

Observed on 2026-06-09 in the WP07 closeout lane:

| Check | Result |
| --- | --- |
| `make validate` | Passed. Fortran tests and the example passed; Python tests reported `24 passed` with two expected NumPy empty-reduction runtime warnings; `git diff --check` passed. |
| Python dtype fixtures | Passed: `6 passed` for `test_numpy_dtype_promotion.py` and `test_numpy_casting.py`. |
| Stale name check | Passed: the current-facing stale pre-rename-name check printed no matches. |
| `git diff --check` | Passed when run directly after the docs update. |
| `make fpm-test` | Optional check reported `fpm not found; install fpm to run fpm test. make validate remains canonical.` |
| Observed NumPy version | `2.4.6`. |

Update this section whenever the closeout gate is rerun.

## Regression Expectations

Closeout validation must keep the existing `r64` vertical slice green:

- Constructors and copies.
- Broadcasting.
- Elementwise kernels.
- Reductions.
- Views and slicing.
- Descriptor metadata and view sharing.

It must also keep the dtype foundation green:

- Registered dtype metadata and support states.
- NumPy-checked promotion policy.
- NumPy-checked dtype-level casting policy.
- Strict scalar casting status behavior.
- Non-`r64` descriptor metadata invariants.

If a future NumPy release changes dtype promotion or casting behavior, update
the Python fixtures and docs together so the observed oracle version remains
visible.
