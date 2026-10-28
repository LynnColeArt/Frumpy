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
  /* Float32 linalg uses four-byte buffers and owns results after input release. */
  int64_t square[2]={2,2};
  float coefficients[4]={2,0,0,4}, rhs32[4]={2,4,8,12}, answer32[4];
  frumpy_handle left32=0,right32=0,solution32=0,product32=0;
  ok(frumpy_import(FRUMPY_R32,2,square,FRUMPY_C,coefficients,4,&left32));
  ok(frumpy_import(FRUMPY_R32,2,square,FRUMPY_F,rhs32,4,&right32));
  ok(frumpy_linalg(FRUMPY_SOLVE,left32,right32,&solution32));
  ok(frumpy_linalg(FRUMPY_MATMUL,left32,right32,&product32));
  frumpy_handle dot32=0,outer32=0;
  ok(frumpy_linalg(FRUMPY_DOT,left32,right32,&dot32));
  ok(frumpy_linalg(FRUMPY_OUTER,left32,right32,&outer32));
  ok(frumpy_export(dot32,answer32,4));
  assert(answer32[0]==4 && answer32[1]==8 && answer32[2]==32 && answer32[3]==48);
  float outer_values[16];
  ok(frumpy_export(outer32,outer_values,16));
  assert(outer_values[0]==4 && outer_values[3]==24 && outer_values[15]==48);
  ok(frumpy_release(dot32));
  ok(frumpy_release(outer32));
  int32_t integer_values[4]={1,2,3,4};
  double promoted_values[16];
  frumpy_handle integers=0,promoted=0;
  ok(frumpy_import(FRUMPY_I32,2,square,FRUMPY_C,integer_values,4,&integers));
  for (int operation=FRUMPY_OUTER;operation<=FRUMPY_MATMUL;operation++) {
    ok(frumpy_linalg(operation,integers,left32,&promoted));
    ok(frumpy_info(promoted,&dtype,&rank,actual_shape,strides,2,&offset,&flags));
    assert(dtype==FRUMPY_R64 && rank==2);
    ok(frumpy_export(promoted,promoted_values,operation==FRUMPY_OUTER?16:4));
    assert(promoted_values[0]==2);
    ok(frumpy_release(promoted));
  }
  promoted=999;
  assert(frumpy_linalg(FRUMPY_SOLVE,integers,left32,&promoted)==FRUMPY_UNSUPPORTED_DTYPE);
  assert(promoted==0);
  ok(frumpy_release(integers));
  frumpy_handle norm32=0;
  ok(frumpy_norm(1,left32,NULL,0,0,&norm32));
  ok(frumpy_info(norm32,&dtype,&rank,actual_shape,strides,2,&offset,&flags));
  assert(dtype==FRUMPY_R32 && rank==0);
  ok(frumpy_release(left32));
  ok(frumpy_release(right32));
  ok(frumpy_export(norm32,answer32,1));
  assert(answer32[0]>4.47213f && answer32[0]<4.47214f);
  ok(frumpy_release(norm32));
  ok(frumpy_export(solution32,answer32,4));
  assert(answer32[0]==1 && answer32[1]==2 && answer32[2]==2 && answer32[3]==3);
  ok(frumpy_info(product32,&dtype,&rank,actual_shape,strides,2,&offset,&flags));
  assert(dtype==FRUMPY_R32 && rank==2 && (flags&1) && (flags&4));
  ok(frumpy_export(product32,answer32,4));
  assert(answer32[0]==4 && answer32[1]==8 && answer32[2]==32 && answer32[3]==48);
  ok(frumpy_release(solution32));
  ok(frumpy_release(product32));
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
