"""Build the native library into a platform-specific local installation."""
import os
from pathlib import Path
import shutil
import subprocess
import sys

from setuptools import setup, Distribution
from setuptools.command.build_py import build_py


class NativeDistribution(Distribution):
    def has_ext_modules(self):
        return True


class BuildNative(build_py):
    def run(self):
        if sys.platform != "linux":
            raise RuntimeError("Frumpy v0.1 source installation is supported on Linux")
        super().run()
        root = Path(__file__).resolve().parent
        build = Path(self.build_lib).resolve().parent / "frumpy-native"
        command = ["make", "shared", f"BUILD_DIR={build}", f"FC={os.environ.get('FC', 'gfortran')}"]
        for variable in ("FFLAGS", "LINALG_LIBS"):
            if variable in os.environ:
                command.append(f"{variable}={os.environ[variable]}")
        subprocess.run(command, cwd=root, check=True)
        destination = Path(self.build_lib) / "frumpy" / "libfrumpy.so"
        shutil.copy2(build / "libfrumpy.so", destination)


setup(cmdclass={"build_py": BuildNative}, distclass=NativeDistribution)
