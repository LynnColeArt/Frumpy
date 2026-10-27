"""Alternate two Python wrappers in one process against the same native library.

Arguments: baseline/frumpy candidate/frumpy. Both use FRUMPY_LIBRARY.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
import time

os.environ["OPENBLAS_NUM_THREADS"] = "1"


def load(name, path):
    spec = importlib.util.spec_from_file_location(
        name, path / "__init__.py", submodule_search_locations=[str(path)])
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    args = parser.parse_args()
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    paths = (args.baseline, args.candidate)
    modules = [load(name, path) for name, path in zip(("before", "after"), paths)]
    arrays = [(module.ones(16), module.ones(16)) for module in modules]
    rows = {name: {"before": [], "after": []}
            for name in ("public", "checked", "wrap_retained")}
    for name in rows:
        for repeat in range(21):
            for index in ([0, 1] if repeat % 2 == 0 else [1, 0]):
                module = modules[index]
                a, b = arrays[index]
                if name == "public":
                    def call():
                        (a+b).close()
                elif name == "checked":
                    def call():
                        handle = module._ffi.make("binary", 1, a._handle, b._handle)
                        module._ffi.call("release", handle)
                else:
                    def call():
                        module._ffi.call("retain", a._handle)
                        module.ndarray(a._handle).close()
                for _ in range(100):
                    call()
                start = time.process_time()
                for _ in range(3000):
                    call()
                rows[name]["before" if index == 0 else "after"].append(
                    (time.process_time() - start) / 3000)
    for a, b in arrays:
        a.close()
        b.close()
    library = Path(os.environ["FRUMPY_LIBRARY"])
    print(json.dumps(dict(rows=rows, library=str(library),
                          library_sha256=hashlib.sha256(library.read_bytes()).hexdigest(),
                          wrappers={name: hashlib.sha256((path / "_array.py").read_bytes()).hexdigest()
                                    for name, path in zip(("before", "after"), paths)},
                          affinity=sorted(os.sched_getaffinity(0)), samples=21, iterations=3000)))


if __name__ == "__main__":
    main()
