"""Build the real Fortran differential driver once, including for direct pytest runs."""

import os
from pathlib import Path
import subprocess

import pytest


@pytest.fixture(scope="session")
def frumpy_driver(tmp_path_factory):
    configured = os.environ.get("FRUMPY_DIFFERENTIAL_DRIVER")
    if configured:
        driver = Path(configured)
        assert driver.is_file(), f"Missing Frumpy driver: {driver}"
        return driver

    root = Path(__file__).resolve().parents[2]
    build = tmp_path_factory.mktemp("frumpy-build")
    driver = build / "bin" / "differential_driver"
    subprocess.run(
        ["make", f"BUILD_DIR={build}", str(driver)], cwd=root,
        check=True, capture_output=True, text=True,
    )
    return driver
