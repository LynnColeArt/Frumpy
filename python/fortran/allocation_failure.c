/* Test-only GNU linker wrappers; fail one selected allocation, then resume normally. */
#include <errno.h>
#include <stddef.h>

static int remaining = -1;

void frumpy_test_fail_after(int count) { remaining = count; }
void frumpy_test_allow_allocations(void) { remaining = -1; }

static int should_fail(void) {
    if (remaining < 0) return 0;
    if (remaining-- != 0) return 0;
    errno = ENOMEM;
    return 1;
}

void *__real_malloc(size_t size);
void *__real_calloc(size_t count, size_t size);
void *__real_realloc(void *pointer, size_t size);

void *__wrap_malloc(size_t size) {
    return should_fail() ? NULL : __real_malloc(size);
}

void *__wrap_calloc(size_t count, size_t size) {
    return should_fail() ? NULL : __real_calloc(count, size);
}

void *__wrap_realloc(void *pointer, size_t size) {
    return should_fail() ? NULL : __real_realloc(pointer, size);
}
