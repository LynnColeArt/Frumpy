ifeq ($(origin FC),default)
FC := gfortran
endif
PYTHON ?= python3
FPM ?= fpm

BUILD_DIR ?= build
BIN_DIR := $(BUILD_DIR)/bin
MOD_DIR := $(BUILD_DIR)/mod
OBJ_DIR := $(BUILD_DIR)/obj
VENV ?= .venv
VENV_PY := $(VENV)/bin/python
PY_DEPS_STAMP := $(VENV)/.frumpy-python-deps

FFLAGS ?= -std=f2018 -Wall -Wextra -Werror -fimplicit-none -fcheck=all -fbacktrace

SOURCES := \
	src/frumpy_constants.f90 \
	src/frumpy_statuses.f90 \
	src/frumpy_shape.f90 \
	src/frumpy_strides.f90 \
	src/frumpy_dtypes.f90 \
	src/frumpy_promotion.f90 \
	src/frumpy_ndarray_r64.f90 \
	src/frumpy_constructors_r64.f90 \
	src/frumpy_broadcast.f90 \
	src/frumpy_elementwise_r64.f90 \
	src/frumpy_reductions_r64.f90 \
	src/frumpy_slices.f90 \
	src/frumpy_views_r64.f90 \
	src/frumpy.f90

FORTRAN_TESTS := \
	test/test_statuses.f90 \
	test/test_dtypes.f90 \
	test/test_dtype_promotion.f90 \
	test/test_shape.f90 \
	test/test_strides.f90 \
	test/test_ndarray_r64.f90 \
	test/test_constructors_r64.f90 \
	test/test_broadcast.f90 \
	test/test_elementwise_r64.f90 \
	test/test_reductions_r64.f90 \
	test/test_views_r64.f90

EXAMPLES := \
	examples/first_vertical_slice.f90

TEST_BINS := $(patsubst test/%.f90,$(BIN_DIR)/%,$(FORTRAN_TESTS))
EXAMPLE_BINS := $(patsubst examples/%.f90,$(BIN_DIR)/example_%,$(EXAMPLES))

.PHONY: all build test examples python-test fpm-test validate diff-check clean

all: build

build: | $(OBJ_DIR) $(MOD_DIR)
	@set -eu; \
	for src in $(SOURCES); do \
		obj="$(OBJ_DIR)/$$(basename "$${src%.f90}").o"; \
		echo "FC $$src"; \
		$(FC) $(FFLAGS) -J$(MOD_DIR) -I$(MOD_DIR) -c "$$src" -o "$$obj"; \
	done

test: $(TEST_BINS)
	@set -eu; \
	for test_bin in $(TEST_BINS); do \
		echo "RUN $$test_bin"; \
		"$$test_bin"; \
	done

examples: $(EXAMPLE_BINS)
	@set -eu; \
	for example_bin in $(EXAMPLE_BINS); do \
		echo "RUN $$example_bin"; \
		"$$example_bin"; \
	done

python-test: $(PY_DEPS_STAMP)
	$(VENV_PY) -m pytest -q python/tests

fpm-test:
	@if command -v $(FPM) >/dev/null 2>&1; then \
		$(FPM) test; \
	else \
		echo "fpm not found; install fpm to run fpm test. make validate remains canonical."; \
	fi

validate: test examples python-test diff-check

diff-check:
	git diff --check

clean:
	rm -rf $(BUILD_DIR) .pytest_cache python/tests/__pycache__
	rm -f *.o *.mod *.smod

$(BIN_DIR)/%: test/%.f90 $(SOURCES) | $(BIN_DIR) $(MOD_DIR)
	$(FC) $(FFLAGS) -J$(MOD_DIR) -I$(MOD_DIR) $(SOURCES) $< -o $@

$(BIN_DIR)/example_%: examples/%.f90 $(SOURCES) | $(BIN_DIR) $(MOD_DIR)
	$(FC) $(FFLAGS) -J$(MOD_DIR) -I$(MOD_DIR) $(SOURCES) $< -o $@

$(PY_DEPS_STAMP):
	@test -x "$(VENV_PY)" || "$(PYTHON)" -m venv "$(VENV)"
	$(VENV_PY) -m pip install --upgrade pip
	$(VENV_PY) -m pip install pytest numpy
	@touch "$@"

$(BIN_DIR) $(MOD_DIR) $(OBJ_DIR):
	@mkdir -p $@
