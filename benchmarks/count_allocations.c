/* Linux/glibc-only measurement helper, not part of libfrumpy. Single-threaded use. */
#include <stddef.h>
#include <stdint.h>
extern void *__libc_malloc(size_t);
extern void *__libc_calloc(size_t, size_t);
extern void *__libc_realloc(void *, size_t);
extern void __libc_free(void *);
static int enabled;
static uint64_t calls, requested;
void frumpy_measure_start(void) { calls = requested = 0; enabled = 1; }
void frumpy_measure_stop(void) { enabled = 0; }
uint64_t frumpy_measure_calls(void) { return calls; }
uint64_t frumpy_measure_bytes(void) { return requested; }
void *malloc(size_t n) {
  if (enabled) { ++calls; requested += n; }
  return __libc_malloc(n);
}
void *calloc(size_t n, size_t size) {
  if (enabled) { ++calls; requested += n * size; }
  return __libc_calloc(n, size);
}
void *realloc(void *p, size_t n) {
  if (enabled) { ++calls; requested += n; }
  return __libc_realloc(p, n);
}
void free(void *p) { __libc_free(p); }
