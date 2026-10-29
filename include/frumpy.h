#ifndef FRUMPY_H
#define FRUMPY_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* ABI v1. Handles are positive, process-local IDs; zero is null. Callers serialize
   all calls. Input/output buffers must be valid for their declared element counts.
   Failed constructors/operations set *out to zero. Release every owned handle.
   Shape/stride units are elements; info offsets are zero-based. Buffers use native
   endian fixed-width values; bool uses uint8_t, where nonzero means true. */
typedef int64_t frumpy_handle;
enum frumpy_status { FRUMPY_OK=0, FRUMPY_INVALID_SHAPE=1, FRUMPY_INVALID_AXIS=2,
  FRUMPY_ALLOCATION_FAILED=3, FRUMPY_OVERFLOW=4, FRUMPY_UNSUPPORTED_DTYPE=5,
  FRUMPY_UNSUPPORTED_BEHAVIOR=6, FRUMPY_SINGULAR_MATRIX=7, FRUMPY_INVALID_HANDLE=8 };
enum frumpy_dtype { FRUMPY_BOOL=1, FRUMPY_I32=2, FRUMPY_I64=3, FRUMPY_R32=4, FRUMPY_R64=5 };
enum frumpy_order { FRUMPY_C=0, FRUMPY_F=1, FRUMPY_A=2, FRUMPY_K=3 };
enum frumpy_binary_op { FRUMPY_ADD=1, FRUMPY_SUBTRACT=2, FRUMPY_MULTIPLY=3,
  FRUMPY_DIVIDE=4, FRUMPY_EQUAL=5, FRUMPY_NOT_EQUAL=6, FRUMPY_LESS=7,
  FRUMPY_LESS_EQUAL=8, FRUMPY_GREATER=9, FRUMPY_GREATER_EQUAL=10,
  FRUMPY_LOGICAL_AND=11, FRUMPY_LOGICAL_OR=12, FRUMPY_LOGICAL_XOR=13 };
enum frumpy_unary_op { FRUMPY_NEGATE=1, FRUMPY_ABS=2, FRUMPY_SQRT=3, FRUMPY_EXP=4,
  FRUMPY_LOG=5, FRUMPY_SIN=6, FRUMPY_COS=7, FRUMPY_LOGICAL_NOT=8 };
enum frumpy_reduce_op { FRUMPY_SUM=1, FRUMPY_PROD=2, FRUMPY_MIN=3, FRUMPY_MAX=4,
  FRUMPY_MEAN=5, FRUMPY_ALL=6, FRUMPY_ANY=7, FRUMPY_ARGMIN=8, FRUMPY_ARGMAX=9 };
enum frumpy_view_op { FRUMPY_RESHAPE=1, FRUMPY_TRANSPOSE=2, FRUMPY_SWAPAXES=3,
  FRUMPY_SQUEEZE=4, FRUMPY_EXPAND_DIMS=5, FRUMPY_SLICE=6, FRUMPY_RAVEL=7,
  FRUMPY_FLATTEN=8, FRUMPY_COPY=9, FRUMPY_ASCONTIGUOUS=10 };
enum frumpy_linalg_op { FRUMPY_OUTER=1, FRUMPY_DOT=2, FRUMPY_MATMUL=3, FRUMPY_SOLVE=4 };
int32_t frumpy_abi_version(void);
int32_t frumpy_retain(frumpy_handle handle);
int32_t frumpy_release(frumpy_handle handle);
int32_t frumpy_create(int32_t dtype, int32_t rank, const int64_t *shape,
                      int32_t order, frumpy_handle *out);
int32_t frumpy_import(int32_t dtype, int32_t rank, const int64_t *shape,
                      int32_t order, const void *data, int64_t count, frumpy_handle *out);
int32_t frumpy_export(frumpy_handle handle, void *data, int64_t count);
int32_t frumpy_info(frumpy_handle handle, int32_t *dtype, int32_t *rank,
                    int64_t *shape, int64_t *strides, int32_t capacity,
                    int64_t *offset0, int32_t *flags);
int32_t frumpy_binary(int32_t op, frumpy_handle lhs, frumpy_handle rhs, frumpy_handle *out);
int32_t frumpy_unary(int32_t op, frumpy_handle source, frumpy_handle *out);
int32_t frumpy_cast(frumpy_handle source, int32_t dtype, int32_t casting, frumpy_handle *out);
int32_t frumpy_reduce(int32_t op, frumpy_handle source, int32_t has_axis,
                      int32_t axis, int32_t keepdims, frumpy_handle *out);
/* View parameters: reshape=shape; swapaxes=two axes; squeeze=zero/one axis;
   expand_dims=one axis; slice=rank triples of normalized start,stop,step;
   copy=zero/one order; transpose/ravel/flatten/ascontiguous=no parameters. */
int32_t frumpy_view(int32_t op, frumpy_handle source, const int64_t *parameters,
                    int32_t count, frumpy_handle *out);
/* OUTER/DOT/MATMUL promote to R32/R64; integral-only pairs are unsupported.
 * SOLVE requires same-dtype R32 or R64 inputs. ABI version remains 1. */
int32_t frumpy_linalg(int32_t op, frumpy_handle lhs, frumpy_handle rhs, frumpy_handle *out);
/* Euclidean/Frobenius: matching output dtype. R32: pairwise R64 widened squares;
 * R64: scaled R64 accumulation. */
int32_t frumpy_norm(int32_t matrix, frumpy_handle source, const int64_t *axes,
                    int32_t count, int32_t keepdims, frumpy_handle *out);
int32_t frumpy_mask_select(frumpy_handle source, frumpy_handle mask, frumpy_handle *out);
int32_t frumpy_assign(frumpy_handle target, frumpy_handle values);
int32_t frumpy_full(int32_t dtype, int32_t rank, const int64_t *shape,
                    int32_t order, const void *value, frumpy_handle *out);
int32_t frumpy_arange(double start, double stop, double step, frumpy_handle *out);
int32_t frumpy_linspace(double start, double stop, int64_t count, int32_t endpoint, frumpy_handle *out);
int32_t frumpy_where(frumpy_handle condition, frumpy_handle lhs, frumpy_handle rhs, frumpy_handle *out);
int32_t frumpy_take(frumpy_handle source, const int64_t *indices, int64_t count,
                    int32_t axis, frumpy_handle *out);
int32_t frumpy_join(int32_t stack, const frumpy_handle *sources, int32_t count,
                    int32_t axis, frumpy_handle *out);
int32_t frumpy_sort(int32_t indices, frumpy_handle source, int32_t axis, frumpy_handle *out);
int32_t frumpy_searchsorted(frumpy_handle source, frumpy_handle values, int32_t right,
                            frumpy_handle *out);
int32_t frumpy_flatnonzero(frumpy_handle source, frumpy_handle *out);
int32_t frumpy_rng_create(int64_t seed, frumpy_handle *out);
int32_t frumpy_rng_get_state(frumpy_handle generator, int64_t *words, int32_t count);
int32_t frumpy_rng_set_state(frumpy_handle generator, const int64_t *words, int32_t count);
int32_t frumpy_rng_fill(frumpy_handle generator, int32_t normal, int32_t rank,
                        const int64_t *shape, frumpy_handle *out);
#ifdef __cplusplus
}
#endif
#endif
