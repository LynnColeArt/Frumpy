/* Diagnostic interposer: time backend calls without changing Frumpy's kernels.
 * Build: cc -shared -fPIC -O2 -Wall -Wextra -Werror probe_linalg.c -ldl -o probe.so
 * Set FRUMPY_PROBE_BACKEND to the LP64 shared library and LD_PRELOAD to probe.so.
 * Single-threaded measurement only; counters are deliberately not synchronized. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdlib.h>
#include <time.h>
#include <stddef.h>
static double gemm_time, gesv_time;
static double now(void) {
    struct timespec t;
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}
static void *symbol(const char *name) {
    static void *backend;
    if (!backend) backend = dlopen(getenv("FRUMPY_PROBE_BACKEND"), RTLD_NOW | RTLD_LOCAL);
    void *result = backend ? dlsym(backend, name) : NULL;
    if (!result) abort();
    return result;
}
void frumpy_probe_reset(void) { gemm_time = gesv_time = 0; }
double frumpy_probe_gemm(void) { return gemm_time; }
double frumpy_probe_gesv(void) { return gesv_time; }
void dgemm_(const char *ta, const char *tb, const int *m, const int *n, const int *k,
            const double *alpha, const double *a, const int *lda,
            const double *b, const int *ldb, const double *beta, double *c,
            const int *ldc, size_t la, size_t lb) {
    typedef void (*fn)(const char *,const char *,const int *,const int *,const int *,
                       const double *,const double *,const int *,const double *,
                       const int *,const double *,double *,const int *,size_t,size_t);
    static fn real;
    if (!real) real = (fn)symbol("dgemm_");
    double start = now();
    real(ta,tb,m,n,k,alpha,a,lda,b,ldb,beta,c,ldc,la,lb);
    gemm_time += now() - start;
}
void dgesv_(const int *n, const int *nrhs, double *a, const int *lda, int *pivots,
            double *b, const int *ldb, int *info) {
    typedef void (*fn)(const int *,const int *,double *,const int *,int *,double *,
                       const int *,int *);
    static fn real;
    if (!real) real = (fn)symbol("dgesv_");
    double start = now();
    real(n,nrhs,a,lda,pivots,b,ldb,info);
    gesv_time += now() - start;
}
