#include "frumpy.h"
#include <assert.h>
#include <stddef.h>
#include <stdio.h>
void frumpy_test_fail_size(size_t);
int frumpy_test_failure_consumed(void);
size_t coordinate_handle_size(void);
void frumpy_test_fail_nth_size(size_t,int);
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
  /* Fail the second tuple handle after the first has been published. */
  int64_t shape[3]={2,2,2};
  int32_t data[8]={0,0,0,0,0,0,0,1};
  frumpy_handle input, marker, axes[3]={-1,-1,-1}, next;
  assert(frumpy_import(FRUMPY_I32,3,shape,FRUMPY_C,data,8,&input)==FRUMPY_OK);
  assert(frumpy_import(FRUMPY_R64,0,NULL,FRUMPY_C,&value,1,&marker)==FRUMPY_OK);
  assert(frumpy_release(marker)==FRUMPY_OK);
  frumpy_test_fail_nth_size(coordinate_handle_size(),1);
  assert(frumpy_nonzero(input,axes,3)==FRUMPY_ALLOCATION_FAILED);
  assert(frumpy_test_failure_consumed());
  assert(axes[0]==0 && axes[1]==0 && axes[2]==0);
  assert(frumpy_import(FRUMPY_R64,0,NULL,FRUMPY_C,&value,1,&next)==FRUMPY_OK);
  assert(next==marker+2); /* Exactly one rolled-back tuple handle consumed an ID. */
  assert(frumpy_release(marker+1)==FRUMPY_INVALID_HANDLE);
  assert(frumpy_nonzero(input,axes,3)==FRUMPY_OK);
  for(int i=0;i<3;i++) {
    int64_t coordinate=-1;
    assert(frumpy_export(axes[i],&coordinate,1)==FRUMPY_OK && coordinate==1);
    assert(frumpy_release(axes[i])==FRUMPY_OK);
  }
  assert(frumpy_release(input)==FRUMPY_OK);
  assert(frumpy_release(next)==FRUMPY_OK);
  puts("Registry and coordinate tuple allocation recovery passed");
  return 0;
}
