ifeq ($(origin FC),default)
FC := gfortran
endif
PYTHON ?= python3
FPM ?= fpm
COMPILERS ?= gfortran-13 gfortran-14 flang-new-19

BUILD_DIR ?= build
BIN_DIR := $(BUILD_DIR)/bin
MOD_DIR := $(BUILD_DIR)/mod
OBJ_DIR := $(BUILD_DIR)/obj
VENV ?= .venv
VENV_PY := $(VENV)/bin/python
PY_DEPS_STAMP := $(VENV)/.frumpy-python-deps

LINALG_LIBS ?= -llapack -lblas

FFLAGS ?= -std=f2018 -Wall -Wextra -Werror -fimplicit-none -fcheck=all -fbacktrace

# Each executable build writes the same Fortran module files.
.NOTPARALLEL:

SOURCES := \
	src/frumpy_constants.f90 \
	src/frumpy_statuses.f90 \
	src/frumpy_shape.f90 \
	src/frumpy_strides.f90 \
	src/frumpy_dtypes.f90 \
	src/frumpy_ndarray_bool.f90 \
	src/frumpy_ndarray_i32.f90 \
	src/frumpy_ndarray_i64.f90 \
	src/frumpy_ndarray_r32.f90 \
	src/frumpy_ndarray_r64.f90 \
	src/frumpy_access_r64.f90 \
	src/frumpy_constructors_bool.f90 \
	src/frumpy_constructors_i32.f90 \
	src/frumpy_constructors_i64.f90 \
	src/frumpy_constructors_r32.f90 \
	src/frumpy_constructors_r64.f90 \
	src/frumpy_casting.f90 \
	src/frumpy_broadcast.f90 \
	src/frumpy_integer_scalars.f90 \
	src/frumpy_random.f90 \
	src/frumpy_linear_arithmetic.f90 \
	src/frumpy_elementwise_i32.f90 \
	src/frumpy_elementwise_i64.f90 \
	src/frumpy_elementwise_r32.f90 \
	src/frumpy_elementwise_r64.f90 \
	src/frumpy_promotion.f90 \
	src/frumpy_operands.f90 \
	src/frumpy_array_casting.f90 \
	src/frumpy_comparisons.f90 \
	src/frumpy_arithmetic.f90 \
	src/frumpy_indexing_r64.f90 \
	src/frumpy_products_r32.f90 \
	src/frumpy_products_r64.f90 \
	src/frumpy_norms_r64.f90 \
	src/frumpy_norms_r32.f90 \
	src/frumpy_linalg_backend.f90 \
	src/frumpy_linalg_r32.f90 \
	src/frumpy_linalg_r64.f90 \
	src/frumpy_product_promotion.f90 \
	src/frumpy_reduction_plans.f90 \
	src/frumpy_arg_reductions.f90 \
	src/frumpy_reductions_discrete.f90 \
	src/frumpy_reductions_r32.f90 \
	src/frumpy_reductions_r64.f90 \
	src/frumpy_slices.f90 \
	src/frumpy_selection_r64.f90 \
	src/frumpy_searching_r64.f90 \
	src/frumpy_searching.f90 \
	src/frumpy_sorting_r64.f90 \
	src/frumpy_sorting.f90 \
	src/frumpy_view_plans.f90 \
	src/frumpy_views_bool.f90 \
	src/frumpy_views_i32.f90 \
	src/frumpy_views_i64.f90 \
	src/frumpy_views_r32.f90 \
	src/frumpy_views_r64.f90 \
	src/frumpy.f90

FORTRAN_TESTS := \
	test/test_release_edges.f90 \
	test/test_statuses.f90 \
	test/test_dtypes.f90 \
	test/test_dtype_promotion.f90 \
	test/test_casting.f90 \
	test/test_array_casting.f90 \
	test/test_comparisons.f90 \
	test/test_shape.f90 \
	test/test_strides.f90 \
	test/test_ndarray_bool.f90 \
	test/test_ndarray_i32.f90 \
	test/test_ndarray_i64.f90 \
	test/test_ndarray_r32.f90 \
	test/test_ndarray_r64.f90 \
	test/test_storage_lifetime_r64.f90 \
	test/test_storage_lifetime_dtypes.f90 \
	test/test_constructors_r64.f90 \
	test/test_constructors_dtypes.f90 \
	test/test_broadcast.f90 \
	test/test_products_r32.f90 \
	test/test_product_promotion.f90 \
	test/test_linalg_r32.f90 \
	test/test_linalg_r64.f90 \
	test/test_random.f90 \
	test/test_arithmetic.f90 \
	test/test_elementwise_integer.f90 \
	test/test_elementwise_r32.f90 \
	test/test_elementwise_r64.f90 \
	test/test_reductions_r32.f90 \
	test/test_reductions_r64.f90 \
	test/test_reductions_discrete.f90 \
	test/test_arg_reductions.f90 \
	test/test_selection_r64.f90 \
	test/test_indexing_r64.f90 \
	test/test_selection_validation.f90 \
	test/test_searching_r64.f90 \
	test/test_searching_dtypes.f90 \
	test/test_sorting_r64.f90 \
	test/test_sorting_dtypes.f90 \
	test/test_views_dtypes.f90 \
	test/test_views_r64.f90

EXAMPLES := \
	examples/first_vertical_slice.f90 \
	examples/v01_workflow.f90

TEST_BINS := $(patsubst test/%.f90,$(BIN_DIR)/%,$(FORTRAN_TESTS))
EXAMPLE_BINS := $(patsubst examples/%.f90,$(BIN_DIR)/example_%,$(EXAMPLES))

.PHONY: all build test examples python-test memory-test integer-overflow-test portability-test fpm-test validate diff-check clean

all: build

CORE_OBJECTS = $(patsubst src/%.f90,$(OBJ_DIR)/%.o,$(SOURCES))

build: $(OBJ_DIR)/core.stamp

# Compile the dependency-ordered core once for each compiler/profile directory.
# PIC objects work in both native executables and the C shared library.
$(OBJ_DIR)/core.stamp: $(SOURCES) Makefile | $(OBJ_DIR) $(MOD_DIR)
	cd $(OBJ_DIR) && $(FC) $(FFLAGS) -fPIC -J$(abspath $(MOD_DIR)) \
		-I$(abspath $(MOD_DIR)) -c $(abspath $(SOURCES))
	@touch $@

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

python-test: $(PY_DEPS_STAMP) $(BIN_DIR)/differential_driver shared
	FRUMPY_DIFFERENTIAL_DRIVER="$(abspath $(BIN_DIR)/differential_driver)" \
		FRUMPY_LIBRARY="$(abspath $(BUILD_DIR)/libfrumpy.so)" $(VENV_PY) -m pytest -q python/tests

# Optional GNU/Linux memory gate; keep instrumentation out of normal build products.
memory-test: $(PY_DEPS_STAMP)
	$(MAKE) BUILD_DIR="$(BUILD_DIR)/memory" \
		FFLAGS="$(FFLAGS) -g -fsanitize=address -fno-omit-frame-pointer -no-pie" \
		"$(BUILD_DIR)/memory/bin/test_release_edges" \
		"$(BUILD_DIR)/memory/bin/test_storage_lifetime_r64" \
		"$(BUILD_DIR)/memory/bin/test_storage_lifetime_dtypes" \
		"$(BUILD_DIR)/memory/bin/test_products_r32" \
		"$(BUILD_DIR)/memory/bin/test_product_promotion" \
		"$(BUILD_DIR)/memory/bin/test_linalg_r32" \
		"$(BUILD_DIR)/memory/bin/test_linalg_r64" \
		"$(BUILD_DIR)/memory/bin/test_random" \
		"$(BUILD_DIR)/memory/bin/test_array_casting" \
		"$(BUILD_DIR)/memory/bin/test_comparisons" \
		"$(BUILD_DIR)/memory/bin/test_reductions_discrete" \
		"$(BUILD_DIR)/memory/bin/test_arg_reductions" \
		"$(BUILD_DIR)/memory/bin/test_sorting_dtypes" \
		"$(BUILD_DIR)/memory/bin/test_searching_dtypes" \
		"$(BUILD_DIR)/memory/bin/test_indexing_r64" \
		"$(BUILD_DIR)/memory/bin/test_constructors_dtypes" \
		"$(BUILD_DIR)/memory/bin/test_views_dtypes" \
		"$(BUILD_DIR)/memory/bin/test_views_r64" \
		"$(BUILD_DIR)/memory/bin/test_arithmetic" \
		"$(BUILD_DIR)/memory/bin/test_elementwise_integer" \
		"$(BUILD_DIR)/memory/bin/test_elementwise_r32" \
		"$(BUILD_DIR)/memory/bin/test_reductions_r32" \
		"$(BUILD_DIR)/memory/bin/allocation_failure_driver" \
		"$(BUILD_DIR)/memory/bin/differential_driver"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_release_edges"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_storage_lifetime_r64"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_storage_lifetime_dtypes"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_products_r32"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_product_promotion"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_linalg_r32"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_linalg_r64"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_random"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_array_casting"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_comparisons"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_reductions_discrete"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_arg_reductions"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_sorting_dtypes"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_searching_dtypes"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_indexing_r64"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_constructors_dtypes"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_views_dtypes"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_views_r64"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_arithmetic"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_elementwise_integer"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_elementwise_r32"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/test_reductions_r32"
	ASAN_OPTIONS=detect_leaks=1 "$(BUILD_DIR)/memory/bin/allocation_failure_driver"
	ASAN_OPTIONS=detect_leaks=1 \
		FRUMPY_DIFFERENTIAL_DRIVER="$(abspath $(BUILD_DIR)/memory/bin/differential_driver)" \
		$(VENV_PY) -m pytest -q python/tests/test_frumpy_differential.py

# GNU-only: modular integer payload arithmetic must not execute signed overflow.
integer-overflow-test: $(PY_DEPS_STAMP)
	$(MAKE) BUILD_DIR="$(BUILD_DIR)/integer-overflow" \
		FFLAGS="$(FFLAGS) -ftrapv -fsanitize=undefined -fno-sanitize-recover=undefined" \
		"$(BUILD_DIR)/integer-overflow/bin/test_release_edges" \
		"$(BUILD_DIR)/integer-overflow/bin/test_products_r32" \
		"$(BUILD_DIR)/integer-overflow/bin/test_product_promotion" \
		"$(BUILD_DIR)/integer-overflow/bin/test_linalg_r32" \
		"$(BUILD_DIR)/integer-overflow/bin/test_linalg_r64" \
		"$(BUILD_DIR)/integer-overflow/bin/test_random" \
		"$(BUILD_DIR)/integer-overflow/bin/test_array_casting" \
		"$(BUILD_DIR)/integer-overflow/bin/test_comparisons" \
		"$(BUILD_DIR)/integer-overflow/bin/test_reductions_discrete" \
		"$(BUILD_DIR)/integer-overflow/bin/test_arg_reductions" \
		"$(BUILD_DIR)/integer-overflow/bin/test_sorting_dtypes" \
		"$(BUILD_DIR)/integer-overflow/bin/test_searching_dtypes" \
		"$(BUILD_DIR)/integer-overflow/bin/test_indexing_r64" \
		"$(BUILD_DIR)/integer-overflow/bin/test_constructors_dtypes" \
		"$(BUILD_DIR)/integer-overflow/bin/test_views_dtypes" \
		"$(BUILD_DIR)/integer-overflow/bin/test_views_r64" \
		"$(BUILD_DIR)/integer-overflow/bin/test_arithmetic" \
		"$(BUILD_DIR)/integer-overflow/bin/test_elementwise_integer" \
		"$(BUILD_DIR)/integer-overflow/bin/differential_driver"
	"$(BUILD_DIR)/integer-overflow/bin/test_release_edges"
	"$(BUILD_DIR)/integer-overflow/bin/test_products_r32"
	"$(BUILD_DIR)/integer-overflow/bin/test_product_promotion"
	"$(BUILD_DIR)/integer-overflow/bin/test_linalg_r32"
	"$(BUILD_DIR)/integer-overflow/bin/test_linalg_r64"
	"$(BUILD_DIR)/integer-overflow/bin/test_random"
	"$(BUILD_DIR)/integer-overflow/bin/test_array_casting"
	"$(BUILD_DIR)/integer-overflow/bin/test_comparisons"
	"$(BUILD_DIR)/integer-overflow/bin/test_reductions_discrete"
	"$(BUILD_DIR)/integer-overflow/bin/test_arg_reductions"
	"$(BUILD_DIR)/integer-overflow/bin/test_sorting_dtypes"
	"$(BUILD_DIR)/integer-overflow/bin/test_searching_dtypes"
	"$(BUILD_DIR)/integer-overflow/bin/test_indexing_r64"
	"$(BUILD_DIR)/integer-overflow/bin/test_constructors_dtypes"
	"$(BUILD_DIR)/integer-overflow/bin/test_views_dtypes"
	"$(BUILD_DIR)/integer-overflow/bin/test_views_r64"
	"$(BUILD_DIR)/integer-overflow/bin/test_arithmetic"
	"$(BUILD_DIR)/integer-overflow/bin/test_elementwise_integer"
	FRUMPY_DIFFERENTIAL_DRIVER="$(abspath $(BUILD_DIR)/integer-overflow/bin/differential_driver)" \
		$(VENV_PY) -m pytest -q python/tests/test_frumpy_differential.py -k "numpy_integer or numpy_mixed or matmul or solve or outer or dot or norm or random or dtype_constructors or dtype_views or astype or comparisons or logical_bool or discrete_reductions or bool_reductions or integer_mean or mask_select or numpy_assign or linalg_nonfinite"

portability-test:
	bash scripts/validate_compilers.sh "$(BUILD_DIR)/portability" $(COMPILERS)

fpm-test:
	@if command -v $(FPM) >/dev/null 2>&1; then \
		$(FPM) test; \
	else \
		echo "fpm not found; install fpm to run fpm test. make validate remains canonical."; \
	fi

validate: test examples python-test c-test diff-check

diff-check:
	git diff --check

clean:
	rm -rf $(BUILD_DIR) .pytest_cache python/tests/__pycache__
	rm -f *.o *.mod *.smod

$(BIN_DIR)/%: test/%.f90 $(OBJ_DIR)/core.stamp | $(BIN_DIR) $(MOD_DIR)
	$(FC) $(FFLAGS) -J$(MOD_DIR) -I$(MOD_DIR) $< $(CORE_OBJECTS) -o $@ $(LINALG_LIBS)

$(BIN_DIR)/example_%: examples/%.f90 $(OBJ_DIR)/core.stamp | $(BIN_DIR) $(MOD_DIR)
	$(FC) $(FFLAGS) -J$(MOD_DIR) -I$(MOD_DIR) $< $(CORE_OBJECTS) -o $@ $(LINALG_LIBS)

$(BIN_DIR)/differential_driver: python/fortran/differential_driver.f90 $(OBJ_DIR)/core.stamp | $(BIN_DIR) $(MOD_DIR)
	$(FC) $(FFLAGS) -J$(MOD_DIR) -I$(MOD_DIR) $< $(CORE_OBJECTS) -o $@ $(LINALG_LIBS)

$(BIN_DIR)/benchmark_driver: benchmarks/benchmark_driver.f90 $(OBJ_DIR)/core.stamp | $(BIN_DIR) $(MOD_DIR)
	$(FC) $(FFLAGS) -J$(MOD_DIR) -I$(MOD_DIR) $< $(CORE_OBJECTS) -o $@ $(LINALG_LIBS)

$(OBJ_DIR)/allocation_failure.o: python/fortran/allocation_failure.c | $(OBJ_DIR)
	$(CC) -g -Wall -Wextra -Werror -fsanitize=address -c $< -o $@

# GFortran finalizers allocate unchecked scratch arrays; keep only those on the
# stack in the fault driver so injection exercises Frumpy allocation/status paths.
$(BIN_DIR)/allocation_failure_driver: python/fortran/allocation_failure_driver.f90 $(SOURCES) $(OBJ_DIR)/allocation_failure.o | $(BIN_DIR) $(MOD_DIR)
	$(FC) $(FFLAGS) -fstack-arrays -J$(MOD_DIR) -I$(MOD_DIR) $(SOURCES) $< \
		$(OBJ_DIR)/allocation_failure.o -Wl,--wrap=malloc,--wrap=calloc,--wrap=realloc -o $@ $(LINALG_LIBS)

$(PY_DEPS_STAMP): python/requirements-test.txt
	@test -x "$(VENV_PY)" || "$(PYTHON)" -m venv "$(VENV)"
	$(VENV_PY) -m pip install -r python/requirements-test.txt
	@touch "$@"

$(BIN_DIR) $(MOD_DIR) $(OBJ_DIR):
	@mkdir -p $@

# The C boundary is separate from the native library surface.
C_SOURCES := src/frumpy_c_handles.f90 src/frumpy_c_core.f90 \
	src/frumpy_c_operations.f90 src/frumpy_c_views.f90 src/frumpy_c_reductions.f90 \
	src/frumpy_c_numerical.f90 src/frumpy_c_random.f90 \
	src/frumpy_c_sequences.f90 src/frumpy_c_indexing.f90 \
	src/frumpy_c_selection.f90 src/frumpy_c_ordering.f90

.PHONY: shared c-test
shared: $(BUILD_DIR)/libfrumpy.so

$(BUILD_DIR)/libfrumpy.so: $(OBJ_DIR)/core.stamp $(C_SOURCES) | $(MOD_DIR)
	$(FC) $(FFLAGS) -fPIC -shared -J$(MOD_DIR) -I$(MOD_DIR) \
		$(C_SOURCES) $(CORE_OBJECTS) $(LINALG_LIBS) -o $@

c-test: shared
	$(CC) -std=c11 -Wall -Wextra -Werror -Iinclude c_tests/test_c_api.c \
		-L$(BUILD_DIR) -lfrumpy -Wl,-rpath,$(abspath $(BUILD_DIR)) -o $(BUILD_DIR)/test_c_api
	$(BUILD_DIR)/test_c_api

# Standalone C leak checks plus Python/ctypes address checks. CPython/NumPy
# process-global allocations are excluded only in the Python invocation.
.PHONY: c-memory-test
c-memory-test: $(PY_DEPS_STAMP)
	$(MAKE) c-test BUILD_DIR="$(BUILD_DIR)/c-memory" \
		CC="$(CC) -fsanitize=address -fno-omit-frame-pointer -no-pie" \
		FFLAGS="$(FFLAGS) -g -fsanitize=address -fno-omit-frame-pointer"
	$(MAKE) "$(BUILD_DIR)/c-memory/bin/differential_driver" BUILD_DIR="$(BUILD_DIR)/c-memory" \
		FFLAGS="$(FFLAGS) -g -fsanitize=address -fno-omit-frame-pointer -no-pie"
	LD_PRELOAD="$$($(FC) -print-file-name=libasan.so)" ASAN_OPTIONS=detect_leaks=0 \
		FRUMPY_LIBRARY="$(abspath $(BUILD_DIR)/c-memory/libfrumpy.so)" \
		FRUMPY_DIFFERENTIAL_DRIVER="$(abspath $(BUILD_DIR)/c-memory/bin/differential_driver)" \
		$(VENV_PY) -m pytest -q python/tests/test_c_boundary.py python/tests/test_package.py \
		python/tests/test_float32_linalg.py python/tests/test_float32_products.py \
		python/tests/test_promoted_products.py python/tests/test_contiguous_casting.py python/tests/test_float32_norms.py python/tests/test_norm_accumulation.py python/tests/test_arg_reductions.py python/tests/test_arg_scan_contracts.py python/tests/test_sort_dtypes.py python/tests/test_searchsorted_dtypes.py

# Linux/glibc only; run separately from ASan's own malloc interposition.
.PHONY: registry-allocation-test
registry-allocation-test: shared
	$(CC) -std=c11 -Wall -Wextra -Werror -shared -fPIC c_tests/registry_alloc_probe.c \
		-o "$(BUILD_DIR)/libfrumpy_registry_alloc_probe.so"
	$(CC) -std=c11 -Wall -Wextra -Werror -Iinclude c_tests/test_registry_allocation.c \
		-L"$(BUILD_DIR)" -lfrumpy -lfrumpy_registry_alloc_probe \
		-Wl,-rpath,"$(abspath $(BUILD_DIR))" -o "$(BUILD_DIR)/test_registry_allocation"
	LD_PRELOAD="$(abspath $(BUILD_DIR)/libfrumpy_registry_alloc_probe.so)" \
		"$(BUILD_DIR)/test_registry_allocation"
