"""Cancellation diagnostics against exact integer sums; not a timing benchmark."""
import json
import os
os.environ['OPENBLAS_NUM_THREADS']='1'
import numpy as np
import frumpy as fp

rows=[]
for small_terms in (64,4096,65536):
    a=np.ones(small_terms+2,dtype=np.float32)
    a[0],a[-1]=2**24,-2**24
    b=np.ones_like(a)
    with fp.asarray(a) as left,fp.asarray(b) as right,fp.dot(left,right) as result:
        actual=float(result.item())
    sequential=np.float32(0)
    for term in a:
        sequential=np.float32(sequential+term)
    rows.append(dict(small_terms=small_terms,contracted_length=a.size,
                     exact_sum=small_terms,frumpy=actual,
                     numpy=float(np.dot(a,b)),sequential_float32=float(sequential),
                     frumpy_absolute_error=abs(actual-small_terms),
                     numpy_absolute_error=abs(float(np.dot(a,b))-small_terms)))
print(json.dumps(dict(numpy=np.__version__,rows=rows),indent=2))
