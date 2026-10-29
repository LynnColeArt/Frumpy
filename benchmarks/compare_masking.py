"""Small public-API baseline; inputs imported before timing, outputs released inside it."""
import json
import statistics
import time

import numpy as np
import frumpy as fp


def median_us(call, repeats=7, loops=5):
    call()
    samples = []
    for _ in range(repeats):
        start = time.perf_counter_ns()
        for _ in range(loops):
            call()
        samples.append((time.perf_counter_ns() - start) / loops / 1000)
    return statistics.median(samples)


def extract(source, mask):
    source[mask].close()


def masked_assign(target, mask, rhs):
    target[mask] = rhs


def assign(target, rhs):
    target[:] = rhs


def main():
    rows = []
    for dtype in (np.bool_, np.int32, np.int64, np.float32, np.float64):
        for size in (16, 65536):
            for step in (1, 2):
                data = np.arange(size * step).astype(dtype)
                mask = np.arange(size) % 2 == 0
                scalar = np.array(1, dtype=dtype)
                array = data.copy()[::step]
                with fp.asarray(data) as owner, fp.asarray(mask) as condition, fp.asarray(scalar) as rhs:
                    source = owner[::step]
                    try:
                        for operation, native, numpy_call in (
                            ('extract', lambda: extract(source, condition), lambda: array[mask]),
                            ('mask_assign', lambda: masked_assign(source, condition, rhs),
                             lambda: masked_assign(array, mask, scalar)),
                            ('assign', lambda: assign(source, rhs), lambda: assign(array, scalar)),
                        ):
                            rows.append(dict(dtype=np.dtype(dtype).name, size=size, step=step,
                                             operation=operation, frumpy_us=median_us(native),
                                             numpy_us=median_us(numpy_call)))
                    finally:
                        source.close()
    print(json.dumps(rows, indent=2))


if __name__ == '__main__':
    main()
