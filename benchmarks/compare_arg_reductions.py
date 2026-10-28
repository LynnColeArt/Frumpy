"""Allocating arg reductions, with imports/exports outside timing."""
import argparse
import ctypes as C
import hashlib
import json
import os
from pathlib import Path
import subprocess
from compare_queue import timed
import numpy as np
import frumpy as fp
from frumpy import _ffi


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--source-commit')
    parser.add_argument('--bool-cases',action='store_true')
    parser.add_argument('--reverse',action='store_true')
    parser.add_argument('--focus',action='store_true',help='Recheck noisy bool/int64 and F-order minima')
    args=parser.parse_args()
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    library=Path(os.environ['FRUMPY_LIBRARY'])
    report=dict(source_commit=args.source_commit or subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
                library_sha256=hashlib.sha256(library.read_bytes()).hexdigest(),
                numpy=np.__version__,numpy_build=np.show_config(mode='dicts'),
                compiler_flags='GNU14 -std=f2018 -O3 -fimplicit-none',
                affinity=sorted(os.sched_getaffinity(0)),threads=1,rows=[])
    cases=[((16,),None,'C'),((65536,),None,'C'),((65536,),None,'step'),
           ((65536,),None,'reverse'),((128,128),None,'F'),
           ((128,128),0,'C'),((128,128),1,'C'),((128,128),1,'F')]
    jobs=[(dtype,op,shape,axis,layout) for dtype in [np.bool_,np.int32,np.int64,np.float32,np.float64]
          for op in ['argmin','argmax'] for shape,axis,layout in cases]
    if args.focus:
        jobs=[j for j in jobs if j[1]=='argmin' and (
            (j[0] in (np.bool_,np.int64) and j[2:]==((65536,),None,'C')) or
            (j[0]==np.float32 and j[2:]==((128,128),None,'F')))]
    jobs=[(*j,'pattern') for j in jobs]
    if args.bool_cases:
        jobs=[(np.bool_,op,shape,None,layout,dist)
              for op in ['argmin','argmax']
              for shape,layout in [((65536,),'C'),((65536,),'step'),((65536,),'reverse'),((256,256),'F')]
              for dist in ['first','middle','last','absent']]
    if args.reverse:jobs.reverse()
    lib=_ffi.library()
    for dtype,op,shape,axis,layout,distribution in jobs:
        storage_shape=shape[:-1]+(shape[-1]*(2 if layout=='step' else 1),)
        indices=np.arange(1,np.prod(storage_shape)+1).reshape(storage_shape)
        storage=((indices%2) if dtype==np.bool_ else ((indices*37)%257-128)).astype(dtype)
        if layout=='F':storage=np.asfortranarray(storage)
        source=storage[...,::2] if layout=='step' else storage[...,::-1] if layout=='reverse' else storage
        if distribution!='pattern':
            target=op=='argmax'
            source[:]=not target
            if distribution!='absent':
                index={'first':0,'middle':source.size//2,'last':source.size-1}[distribution]
                source.flat[index]=target
        expected=getattr(np,op)(source,axis=axis)
        with fp.asarray(storage,order='K') as owner:
            a=owner[...,::2] if layout=='step' else owner[...,::-1] if layout=='reverse' else owner
            with getattr(fp,op)(a,axis=axis) as result:
                np.testing.assert_array_equal(result.numpy(),expected)
            out=_ffi.H()
            def abi():
                assert lib.frumpy_reduce(8 if op=='argmin' else 9,a._handle,int(axis is not None),
                                         0 if axis is None else axis,0,C.byref(out))==0
                assert lib.frumpy_release(out.value)==0
            calls=dict(python=lambda:getattr(fp,op)(a,axis=axis).close(),c_abi=abi,
                       numpy=lambda:getattr(np,op)(source,axis=axis))
            row=dict(distribution=distribution,dtype=np.dtype(dtype).name,operation=op,shape=shape,axis=axis,layout=layout,
                     input_bytes=source.nbytes,result_bytes=np.asarray(expected).nbytes)
            for key in reversed(list(calls)) if args.reverse else calls:
                row[key]=timed(calls[key],7)
            report['rows'].append(row)
            if a is not owner:a.close()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':main()
