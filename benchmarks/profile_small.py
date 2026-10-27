"""Diagnostic cProfile run, separate from uninstrumented wall-clock measurements."""
import cProfile
import pstats
import numpy as np
import frumpy as fp

x = fp.asarray(np.arange(16.))
y = fp.asarray(np.ones(16))


def calls():
    for _ in range(20000):
        (x + y).close()


profile = cProfile.Profile()
profile.runcall(calls)
pstats.Stats(profile).strip_dirs().sort_stats('cumtime').print_stats(22)
