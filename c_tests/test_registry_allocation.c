#include "frumpy.h"
#include <assert.h>
#include <stddef.h>
#include <stdio.h>
void frumpy_test_fail_size(size_t);
int frumpy_test_failure_consumed(void);
int main(void) {
  frumpy_handle ids[130], failed=123;
  double value=2, output=0;
  /* GNU LP64 handle buckets contain one scalar pointer; first capacity is 64. */
  frumpy_test_fail_size(64*sizeof(void *));
  assert(frumpy_import(FRUMPY_R64,0,NULL,FRUMPY_C,&value,1,&failed)==FRUMPY_ALLOCATION_FAILED);
  assert(failed==0 && frumpy_test_failure_consumed());
  for (int i=0;i<128;i++)
    assert(frumpy_import(FRUMPY_R64,0,NULL,FRUMPY_C,&value,1,&ids[i])==FRUMPY_OK);
  frumpy_test_fail_size(128*sizeof(void *));
  assert(frumpy_import(FRUMPY_R64,0,NULL,FRUMPY_C,&value,1,&ids[128])==FRUMPY_OK);
  assert(frumpy_test_failure_consumed());
  /* The next insertion retries growth; both old and new handles must survive. */
  assert(frumpy_import(FRUMPY_R64,0,NULL,FRUMPY_C,&value,1,&ids[129])==FRUMPY_OK);
  for (int i=0;i<130;i++) {
    assert(frumpy_export(ids[i],&output,1)==FRUMPY_OK && output==value);
    assert(frumpy_release(ids[i])==FRUMPY_OK);
  }
  puts("Registry allocation recovery passed");
  return 0;
}
