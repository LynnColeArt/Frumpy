# Frumpy Benchmarks

This directory is reserved for benchmark programs and notes.

Benchmarks are not a source of performance claims yet. For now, they provide a
stable place to add reproducible checks as dtype coverage grows.

Initial benchmark candidates:

- Constructor throughput for contiguous `r64` arrays.
- Broadcasting plan setup cost.
- Elementwise `r64` kernel throughput.
- Reduction behavior across axis choices and memory layouts.

Any future benchmark result should record compiler version, flags, CPU, array
shape, dtype, and whether the operation allocates.
