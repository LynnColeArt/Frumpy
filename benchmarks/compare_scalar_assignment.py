"""Matched scalar fills through C and Python, with NumPy reference timings."""
import argparse
import hashlib
import json
import os
from pathlib import Path
from statistics import median
from time import perf_counter_ns

import numpy as np
import frumpy as fp
from frumpy import _ffi


def timed(call, loops):
    call()
    samples=[]
    for _ in range(7):
        start=perf_counter_ns()
        for _ in range(loops):
            call()
        samples.append((perf_counter_ns()-start)/loops/1000)
    return dict(median_us=median(samples), samples_us=samples)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--source',required=True)
    parser.add_argument('--reverse',action='store_true')
    args=parser.parse_args()
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    lib=_ffi.library()
    path=Path(os.environ['FRUMPY_LIBRARY'])
    report=dict(source=args.source,library_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                numpy=np.__version__,affinity=sorted(os.sched_getaffinity(0)),
                compiler_flags='GNU14 -std=f2018 -O3 -fimplicit-none',rows=[])
    cases=[(dtype,n,layout,masked) for n in (16,65536)
           for layout in ('C','step','reverse','F','irregular') for masked in (False,True)
           for dtype in (np.bool_,np.int32,np.int64,np.float32,np.float64)]
    if args.reverse:cases.reverse()
    for dtype,n,layout,masked in cases:
        side=int(np.sqrt(n))
        shape=(side,side) if layout=='F' else (2*side,side) if layout=='irregular' else (2*n,)
        backing=np.zeros(shape,dtype=dtype,order='F' if layout=='F' else 'C')
        owner=fp.asarray(backing,order='K')
        if layout=='C': a,x=owner[:n],backing[:n]
        elif layout=='step':a,x=owner[::2],backing[::2]
        elif layout=='reverse':a,x=owner[n-1::-1],backing[n-1::-1]
        elif layout=='irregular':a,x=owner[::2,::-1],backing[::2,::-1]
        else:a,x=owner,backing
        mask=np.arange(n).reshape(x.shape)%2==0
        scalar=np.array(1,dtype=dtype)
        with fp.asarray(mask) as condition,fp.asarray(scalar) as rhs:
            def abi():
                code=(lib.frumpy_mask_assign(a._handle,condition._handle,rhs._handle) if masked
                      else lib.frumpy_assign(a._handle,rhs._handle))
                assert code==0
            def python():
                if masked:a[condition]=rhs
                else:a[:]=rhs
            def numpy():
                if masked:x[mask]=scalar
                else:x[:]=scalar
            abi();numpy()
            np.testing.assert_array_equal(a.numpy(),x)
            row=dict(dtype=np.dtype(dtype).name,size=n,layout=layout,masked=masked)
            calls=dict(c_abi=abi,python=python,numpy=numpy)
            for name in reversed(list(calls)) if args.reverse else calls:
                row[name]=timed(calls[name],100 if n==16 else 10)
            report['rows'].append(row)
        if a is not owner:a.close()
        owner.close()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':main()
