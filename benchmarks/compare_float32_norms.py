"""Allocating floating norms through Python/C and NumPy, with setup untimed."""
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
    parser.add_argument('--reverse',action='store_true')
    parser.add_argument('--source-commit',help='Revision that produced the library')
    parser.add_argument('--varied',action='store_true',help='Float32 nonuniform inputs and irregular layouts')
    args=parser.parse_args()
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    library=Path(os.environ['FRUMPY_LIBRARY'])
    report=dict(source_commit=args.source_commit or subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
                library_sha256=hashlib.sha256(library.read_bytes()).hexdigest(),
                linkage=subprocess.check_output(['ldd',str(library)],text=True),
                numpy=np.__version__,numpy_build=np.show_config(mode='dicts'),
                compiler_flags='GNU14 -std=f2018 -O3 -fimplicit-none',
                affinity=sorted(os.sched_getaffinity(0)),threads=1,rows=[])
    cases=[('vector', (n,), None) for n in [16,65536,1048576]]
    cases += [('matrix',(128,128),None),('vector_axis',(16,64,64),1),('matrix_batch',(16,64,64),None)]
    dtypes=[np.float32,np.float64]
    if args.varied:
        cases=[('vector',(65536,),None),('matrix',(128,128),None),
               ('matrix_axes',(7,9,11),(0,2))]
        dtypes=[np.float32]
    if args.reverse:cases.reverse();dtypes.reverse()
    lib=_ffi.library()
    for dtype in dtypes:
        for name,shape,axis in cases:
            layouts=['C','step'] if not args.varied else ['C','reverse','F']
            for layout in layouts:
                storage=np.full(shape[:-1]+(shape[-1]*(2 if layout=='step' else 1),),.5,dtype=dtype)
                if args.varied:
                    rng=np.random.default_rng(20261027)
                    storage[:]=rng.uniform(-1,1,storage.shape)
                    if layout=='reverse':
                        storage[:]=np.ldexp(storage,rng.integers(-100,100,storage.shape))
                    if layout=='F':storage=np.asfortranarray(storage)
                with fp.asarray(storage,order='K') as owner:
                    a=owner[...,::2] if layout=='step' else owner[...,::-1] if layout=='reverse' else owner
                    source=storage[...,::2] if layout=='step' else storage[...,::-1] if layout=='reverse' else storage
                    matrix=name.startswith('matrix')
                    function=fp.linalg.matrix_norm if matrix else fp.linalg.vector_norm
                    oracle=np.linalg.matrix_norm if matrix else np.linalg.vector_norm
                    kwargs={} if axis is None else dict(axis=axis)
                    axes=np.array([] if axis is None else axis if matrix else [axis],dtype=np.int64)
                    if name=='matrix_axes':
                        oracle=lambda x,**kw:np.linalg.norm(x,ord='fro',**kw)
                    # Widened reference remains finite for the dynamic-range cases.
                    expected=oracle(source.astype(np.float64),**kwargs).astype(dtype)
                    with function(a,**kwargs) as result:
                        np.testing.assert_allclose(result.numpy(),expected,rtol=2e-6)
                        assert result.dtype==np.dtype(dtype)
                    with np.errstate(all='ignore'):
                        numpy_finite=bool(np.all(np.isfinite(oracle(source,**kwargs))))
                    out=_ffi.H()
                    def abi():
                        assert lib.frumpy_norm(int(matrix),a._handle,axes.ctypes.data,axes.size,0,C.byref(out))==0
                        assert lib.frumpy_release(out.value)==0
                    row=dict(dtype=np.dtype(dtype).name,operation=name,shape=shape,layout=layout,
                             input_bytes=source.nbytes,result_bytes=np.asarray(expected).nbytes,numpy_result_finite=numpy_finite,
                             widened_input_temporary_bytes=0,distribution='wide' if args.varied and layout=='reverse' else 'random' if args.varied else 'constant')
                    calls=dict(python=lambda:function(a,**kwargs).close(),c_abi=abi,
                               numpy=lambda:oracle(source,**kwargs))
                    keys=list(calls)
                    if args.reverse:keys.reverse()
                    with np.errstate(all='ignore'):
                        for key in keys:row[key]=timed(calls[key],7)
                    report['rows'].append(row)
                    if a is not owner:a.close()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':main()
