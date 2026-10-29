# Reproducible random arrays

`random_generator` owns its state explicitly; there is no global generator or
Fortran intrinsic RNG dependency. A newly declared object is equivalent to seed
zero. Call `generator%seed(seed)` with any int64 bit pattern to restart it.

`uniform_r64(generator, shape, status)` returns owned C-order float64 values in
[0,1). `normal_r64` returns standard normal values. Scalars, empty shapes and
multidimensional output are supported. Shape and byte-count errors leave the
state unchanged and return no storage; explicit allocation failures do likewise.
Empty outputs consume no random numbers. Status is optional.

## Frozen version 1 algorithm

The engine is Blackman and Vigna's
[xoshiro256** 1.0](https://prng.di.unimi.it/xoshiro256starstar.c), seeded with four
successive outputs of Vigna's [SplitMix64](https://prng.di.unimi.it/splitmix.c).
The signed seed is interpreted as its two's-complement uint64 bit pattern.
Modular additions and products use Frumpy's checked limb arithmetic; they do not
rely on signed Fortran overflow. Shifts are logical.

A uniform consumes one engine word. Its upper 53 bits are converted exactly to
binary64 and multiplied by 2^-53. This stream is bitwise stable across supported
compilers using IEEE binary64. It is not the NumPy default_rng stream.

Normals use Box-Muller pairs: consume U then V, compute
`sqrt(-2*log(1-U))`, and multiply by cos/sin of `2*pi*V`. Return the cosine member
first and cache the sine member. The frozen binary64 angle constant is
6.283185307179586476925286766559 rounded to real64. Since U is below one,
`1-U` is positive. Uniform calls preserve any cached normal. Chunking a sequence
of normal calls does not change its stream; interleaving uniform calls advances
the engine but does not discard the cached partner.

Normal values depend on the compiler/math library's log/sqrt/sin/cos rounding.
Same-build state replay is exact; cross-toolchain tests use rtol=2e-13,
atol=2e-14. There is no cross-platform bitwise normal guarantee. Seeds alone do
not promise disjoint parallel streams. Separate generator objects are independent
in ownership; callers must synchronize concurrent mutation of the same object.

## Saved state

`generator%get_state()` returns seven int64 words in this order:

1. Format version (1).
2. Four engine state words, in engine order.
3. Cached-normal flag (0 or 1).
4. Cached-normal IEEE binary64 bits, or zero when the flag is zero.

`call generator%set_state(words, status)` validates the length, version, nonzero
engine state, flag and finite cached value before replacing anything. Rejected
state leaves the object unchanged even without status. Save the words as signed
integers or specify byte order when writing binary files; this API does not define
a native-endian file format. Copying the generator value copies the complete
stream state, without shared references.

## Evidence

`test_random.f90` checks fixed uniform golden bits, default seed, odd-normal
cache round trips, chunking, state validation and failure atomicity.
The Python unsigned-integer reference checks five seeds including both signed
limits, 1,024 draws per long stream, scalar/empty/2-D output, normal transforms,
and deterministic uniform/normal distribution sanity checks. These are regression
checks, not a statistical certification of a generator. NumPy stream equality is
intentionally not claimed. Both GNU sanitizer gates include random state tests.
