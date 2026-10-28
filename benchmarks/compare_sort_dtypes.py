"""Allocating stable sort and argsort across the five concrete dtypes."""
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
    parser.add_argument('--review-cases',action='store_true')
    parser.add_argument('--reverse',action='store_true')
    parser.add_argument('--only-float64',action='store_true')
    args=parser.parse_args()
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    library=Path(os.environ['FRUMPY_LIBRARY'])
    report=dict(source_commit=args.source_commit or subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
                library_sha256=hashlib.sha256(library.read_bytes()).hexdigest(),numpy=np.__version__,
                numpy_build=np.show_config(mode='dicts'),affinity=sorted(os.sched_getaffinity(0)),
                compiler_flags='GNU14 -std=f2018 -O3 -fimplicit-none',rows=[])
    cases=[((32,),'C','random'),((8192,),'C','random'),((8192,),'C','sorted'),
           ((8192,),'C','reverse'),((8192,),'C','duplicates'),((8192,),'step','random'),
           ((64,128),'F','random'),((64,128),'reverse','duplicates')]
    dtypes=[np.float64] if args.only_float64 else [np.bool_,np.int32,np.int64,np.float32,np.float64]
    jobs=[(dtype,op,*case) for dtype in dtypes for op in ['sort','argsort'] for case in cases]
    if args.review_cases:
        jobs=[j for j in jobs if j[1]=='argsort' and j[3:] == ('C','random') and
              ((j[0]==np.bool_ and j[2]==(8192,)) or (j[0]==np.float64 and j[2]==(32,)))]
    if args.reverse:jobs.reverse()
    lib=_ffi.library()
    for dtype,op,shape,layout,distribution in jobs:
        storage_shape=shape[:-1]+(shape[-1]*(2 if layout=='step' else 1),)
        x=np.arange(np.prod(storage_shape)).reshape(storage_shape)
        values=(x*37)%257-128
        if distribution=='duplicates':values=x%5-2
        if dtype==np.bool_:values=x%2
        storage=values.astype(dtype)
        if distribution in ['sorted','reverse']:
            storage=np.sort(storage,kind='stable')
            if distribution=='reverse':storage=storage[...,::-1].copy()
        if layout=='F':storage=np.asfortranarray(storage)
        source=storage[...,::2] if layout=='step' else storage[...,::-1] if layout=='reverse' else storage
        expected=getattr(np,op)(source,axis=-1,kind='stable')
        with fp.asarray(storage,order='K') as owner:
            a=owner[...,::2] if layout=='step' else owner[...,::-1] if layout=='reverse' else owner
            with getattr(fp,op)(a) as result:
                np.testing.assert_array_equal(result.numpy(),expected)
            output=_ffi.H()
            def abi():
                assert lib.frumpy_sort(int(op=='argsort'),a._handle,-1,C.byref(output))==0
                assert lib.frumpy_release(output.value)==0
            calls=dict(c_abi=abi,python=lambda:getattr(fp,op)(a).close(),
                       numpy=lambda:getattr(np,op)(source,axis=-1,kind='stable'))
            row=dict(dtype=np.dtype(dtype).name,operation=op,shape=shape,layout=layout,
                     distribution=distribution,input_bytes=source.nbytes,result_bytes=expected.nbytes)
            for name in reversed(list(calls)) if args.reverse else calls:row[name]=timed(calls[name],7)
            report['rows'].append(row)
            if a is not owner:a.close()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':main()
