/* Linux/glibc fault injection for the standalone registry allocation test. */
#include <stddef.h>
extern void *__libc_malloc(size_t);
extern void *__libc_calloc(size_t, size_t);
static size_t failure_size;
static int consumed;
void frumpy_test_fail_size(size_t size) { failure_size=size; consumed=0; }
int frumpy_test_failure_consumed(void) { return consumed; }
void *malloc(size_t size) {
  if (failure_size && size==failure_size) {
    failure_size=0;
    consumed=1;
    return NULL;
  }
  return __libc_malloc(size);
}

void *calloc(size_t count, size_t size) {
  if (failure_size && count && failure_size/count==size && failure_size%count==0) {
    failure_size=0;
    consumed=1;
    return NULL;
  }
  return __libc_calloc(count, size);
}
