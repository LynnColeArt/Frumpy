FC = gfortran
FFLAGS ?= -std=f2018 -Wall -Wextra -fimplicit-none -fcheck=all
BUILD_DIR ?= build
PYTHON ?= python3

.PHONY: all build test clean python-test fpm-test

all: build

build:
	@if command -v fpm >/dev/null 2>&1; then \
		fpm build; \
	else \
		$(MAKE) --no-print-directory $(BUILD_DIR)/test_runner; \
	fi

test:
	@if command -v fpm >/dev/null 2>&1; then \
		fpm test; \
	else \
		$(MAKE) --no-print-directory $(BUILD_DIR)/test_runner; \
		./$(BUILD_DIR)/test_runner; \
	fi

fpm-test:
	@if command -v fpm >/dev/null 2>&1; then \
		fpm test; \
	else \
		echo "fpm not found; install fpm or run make test for the gfortran fallback"; \
	fi

python-test:
	@if command -v $(PYTHON) >/dev/null 2>&1; then \
		if $(PYTHON) -m pytest --version >/dev/null 2>&1; then \
			$(PYTHON) -m pytest -q python/tests; \
		else \
			$(PYTHON) -m unittest discover -s python/tests -p 'test_*.py'; \
		fi; \
	else \
		echo "$(PYTHON) not found; skipping optional Python tests"; \
	fi

clean:
	rm -rf $(BUILD_DIR) python/tests/__pycache__

$(BUILD_DIR)/.dir:
	@mkdir -p $(BUILD_DIR)
	@touch $@

$(BUILD_DIR)/test_runner: test/test_smoke.f90 test/test_runner.f90 | $(BUILD_DIR)/.dir
	$(FC) $(FFLAGS) -J$(BUILD_DIR) -c test/test_smoke.f90 -o $(BUILD_DIR)/test_smoke.o
	$(FC) $(FFLAGS) -J$(BUILD_DIR) test/test_runner.f90 $(BUILD_DIR)/test_smoke.o -o $@
