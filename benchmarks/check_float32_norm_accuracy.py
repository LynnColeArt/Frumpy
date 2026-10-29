"""Precision diagnostics: result stays float32, accumulator is float64."""
import json
import numpy as np
import frumpy as fp

cases={
    'ordinary':np.array([3,4],dtype=np.float32),
    'square_overflow':np.array([1e30,-1e30],dtype=np.float32),
    'square_underflow':np.array([1e-30,-1e-30],dtype=np.float32),
    'subnormal':np.full(2,np.nextafter(np.float32(0),np.float32(1)),dtype=np.float32),
    'result_overflow':np.full(2,np.finfo(np.float32).max,dtype=np.float32),
    'nan_dominates_inf':np.array([np.inf,np.nan],dtype=np.float32),
    'signed_zero':np.array([-0.,0.],dtype=np.float32),
}
for n in [4096,65536,1048576]:
    a=np.ones(n+1,dtype=np.float32);a[0]=4096;cases[f'small_contributions_{n}']=a
rows=[]
for name,a in cases.items():
    with np.errstate(all='ignore'):
        numpy=np.linalg.vector_norm(a)
        reference=np.float32(np.sqrt(np.sum(a.astype(np.float64)**2)))
    with fp.linalg.vector_norm(a) as result:
        actual=np.float32(result.item())
    np.testing.assert_allclose(actual,reference,rtol=2*np.finfo(np.float32).eps,atol=0)
    rows.append(dict(case=name,count=a.size,frumpy=repr(float(actual)),numpy=repr(float(numpy)),
                     rounded_float64_reference=repr(float(reference))))
print(json.dumps(dict(numpy_version=np.__version__,rows=rows),indent=2))
