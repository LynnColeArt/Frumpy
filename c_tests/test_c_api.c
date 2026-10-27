#include "frumpy.h"
#include <assert.h>
#include <stddef.h>
#include <stdio.h>
static void ok(int32_t status) { assert(status == FRUMPY_OK); }
int main(void) {
  assert(frumpy_abi_version() == 1);
  frumpy_handle a=0, scalar=0, sum=0, transposed=0;
  int64_t shape[2]={2,3};
  double values[6]={1,2,3,4,5,6}, two=2, result[6];
  ok(frumpy_import(FRUMPY_R64,2,shape,FRUMPY_F,values,6,&a));
  ok(frumpy_import(FRUMPY_R64,0,NULL,FRUMPY_C,&two,1,&scalar));
  ok(frumpy_binary(FRUMPY_ADD,a,scalar,&sum));
  ok(frumpy_export(sum,result,6));
  for (int i=0;i<6;i++) assert(result[i] == values[i]+2);
  ok(frumpy_view(FRUMPY_TRANSPOSE,a,NULL,0,&transposed));
  ok(frumpy_release(a));
  ok(frumpy_export(transposed,result,6));
  double expected[6]={1,4,2,5,3,6};
  for (int i=0;i<6;i++) assert(result[i] == expected[i]);
  int32_t dtype=0,rank=0,flags=0;
  int64_t actual_shape[2],strides[2],offset=-1;
  ok(frumpy_info(transposed,&dtype,&rank,actual_shape,strides,2,&offset,&flags));
  assert(dtype==FRUMPY_R64 && rank==2 && actual_shape[0]==3 && actual_shape[1]==2);
  assert(strides[0]==2 && strides[1]==1 && offset==0 && (flags&1) && !(flags&4));
  ok(frumpy_retain(sum));
  ok(frumpy_release(sum));
  ok(frumpy_export(sum,result,6));
  ok(frumpy_release(sum));
  assert(frumpy_release(sum)==FRUMPY_INVALID_HANDLE);
  assert(frumpy_export(sum,result,6)==FRUMPY_INVALID_HANDLE);
  assert(frumpy_retain(INT64_MAX)==FRUMPY_INVALID_HANDLE);
  assert(frumpy_import(FRUMPY_R64,2,shape,FRUMPY_C,NULL,6,&sum)==FRUMPY_INVALID_SHAPE);
  assert(sum==0);
  assert(frumpy_create(FRUMPY_R64,2,NULL,FRUMPY_C,&sum)==FRUMPY_INVALID_SHAPE);
  assert(frumpy_create(FRUMPY_R64,2,shape,FRUMPY_C,NULL)==FRUMPY_INVALID_SHAPE);
  assert(frumpy_export(transposed,NULL,6)==FRUMPY_INVALID_SHAPE);
  ok(frumpy_release(transposed));
  ok(frumpy_release(scalar));
  /* Rehashing and registry reset must preserve retains and release all storage. */
  frumpy_handle many[2048];
  for (int i=0;i<2048;i++)
    ok(frumpy_import(FRUMPY_R64,0,NULL,FRUMPY_C,&two,1,&many[i]));
  ok(frumpy_retain(many[0]));
  for (int i=0;i<2048;i+=2) ok(frumpy_release(many[i]));
  for (int i=1;i<2048;i+=2) ok(frumpy_release(many[i]));
  ok(frumpy_export(many[0],result,1));
  assert(result[0]==two);
  ok(frumpy_release(many[0]));
  assert(frumpy_release(many[0])==FRUMPY_INVALID_HANDLE);
  ok(frumpy_import(FRUMPY_R64,0,NULL,FRUMPY_C,&two,1,&scalar));
  assert(scalar>many[2047]);
  ok(frumpy_release(scalar));
  puts("C ABI ownership and argument checks passed");
  return 0;
}
