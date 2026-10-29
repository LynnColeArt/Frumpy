"""Same-dtype binary search through C/Python, with stable sorted inputs."""
import argparse
import ctypes as C
import hashlib
import json
import os
from pathlib import Path
import subprocess
import numpy as np
import frumpy as fp
from frumpy import _ffi
from compare_queue import timed


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--source-commit')
    parser.add_argument('--reverse',action='store_true')
    parser.add_argument('--only-float64',action='store_true')
    args=parser.parse_args()
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    library=Path(os.environ['FRUMPY_LIBRARY'])
    report=dict(source_commit=args.source_commit or subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
                library_sha256=hashlib.sha256(library.read_bytes()).hexdigest(),numpy=np.__version__,
                numpy_build=np.show_config(mode='dicts'),affinity=sorted(os.sched_getaffinity(0)),
                compiler_flags='GNU14 -std=f2018 -O3 -fimplicit-none',rows=[])
    cases=[(32,(16,),'C'),(8192,(),'C'),(8192,(4096,),'C'),(8192,(4096,),'source_step'),
           (8192,(4096,),'source_reverse'),(8192,(64,64),'query_F'),
           (8192,(4096,),'query_reverse'),(8192,(4096,),'duplicates')]
    dtypes=[np.float64] if args.only_float64 else [np.bool_,np.int32,np.int64,np.float32,np.float64]
    jobs=[(dtype,side,*case) for dtype in dtypes for side in ['left','right'] for case in cases]
    if args.reverse:jobs.reverse()
    lib=_ffi.library()
    for dtype,side,n,shape,layout in jobs:
        source=(np.arange(n)//(64 if layout=='duplicates' else 2)-n//(128 if layout=='duplicates' else 4))
        query=(np.arange(np.prod(shape,dtype=int))*37)%(n+17)-n//2
        if dtype==np.int64:source=source+2**60;query=query+2**60
        if dtype==np.bool_:source=np.arange(n)>=n//2;query=np.arange(query.size)%2
        source=source.astype(dtype);query=query.astype(dtype).reshape(shape)
        storage=source
        if layout=='source_step':storage=np.repeat(source,2)
        if layout=='source_reverse':storage=source[::-1].copy()
        logical_source=storage[::2] if layout=='source_step' else storage[::-1] if layout=='source_reverse' else source
        if layout=='query_F':query=np.asfortranarray(query)
        query_storage=query
        if layout=='query_reverse':query=query[::-1]
        with fp.asarray(storage) as owner,fp.asarray(query_storage,order='K') as qowner:
            a=owner[::2] if layout=='source_step' else owner[::-1] if layout=='source_reverse' else owner
            q=qowner[::-1] if layout=='query_reverse' else qowner
            expected=np.searchsorted(logical_source,query,side=side)
            with fp.searchsorted(a,q,side=side) as result:
                np.testing.assert_array_equal(result.numpy(),expected)
            output=_ffi.H()
            def abi():
                assert lib.frumpy_searchsorted(a._handle,q._handle,int(side=='right'),C.byref(output))==0
                assert lib.frumpy_release(output.value)==0
            calls=dict(c_abi=abi,python=lambda:fp.searchsorted(a,q,side=side).close(),
                       numpy=lambda:np.searchsorted(logical_source,query,side=side))
            row=dict(dtype=np.dtype(dtype).name,side=side,source_length=n,query_shape=shape,layout=layout,
                     input_bytes=source.nbytes+query.nbytes,result_bytes=np.asarray(expected).nbytes)
            for name in reversed(list(calls)) if args.reverse else calls:row[name]=timed(calls[name],7)
            report['rows'].append(row)
            if a is not owner:a.close()
            if q is not qowner:q.close()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':main()
