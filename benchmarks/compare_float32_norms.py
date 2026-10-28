"""Allocating scaled norms through Python/C and NumPy, with setup untimed."""
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
    args=parser.parse_args()
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    library=Path(os.environ['FRUMPY_LIBRARY'])
    report=dict(source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
                library_sha256=hashlib.sha256(library.read_bytes()).hexdigest(),
                linkage=subprocess.check_output(['ldd',str(library)],text=True),
                numpy=np.__version__,numpy_build=np.show_config(mode='dicts'),
                compiler_flags='GNU14 -std=f2018 -O3 -fimplicit-none',
                affinity=sorted(os.sched_getaffinity(0)),threads=1,rows=[])
    cases=[('vector', (n,), None) for n in [16,65536,1048576]]
    cases += [('matrix',(128,128),None),('vector_axis',(16,64,64),1),('matrix_batch',(16,64,64),None)]
    dtypes=[np.float32,np.float64]
    if args.reverse:cases.reverse();dtypes.reverse()
    lib=_ffi.library()
    for dtype in dtypes:
        for name,shape,axis in cases:
            for layout in ['C','step']:
                storage=np.full(shape[:-1]+(shape[-1]*(2 if layout=='step' else 1),),.5,dtype=dtype)
                with fp.asarray(storage) as owner:
                    a=owner[...,::2] if layout=='step' else owner
                    source=storage[...,::2] if layout=='step' else storage
                    matrix=name.startswith('matrix')
                    function=fp.linalg.matrix_norm if matrix else fp.linalg.vector_norm
                    oracle=np.linalg.matrix_norm if matrix else np.linalg.vector_norm
                    kwargs={} if matrix or axis is None else dict(axis=axis)
                    axes=np.array([] if axis is None else [axis],dtype=np.int64)
                    expected=oracle(source,**kwargs)
                    with function(a,**kwargs) as result:
                        np.testing.assert_allclose(result.numpy(),expected,rtol=2e-6)
                        assert result.dtype==np.dtype(dtype)
                    out=_ffi.H()
                    def abi():
                        assert lib.frumpy_norm(int(matrix),a._handle,axes.ctypes.data,axes.size,0,C.byref(out))==0
                        assert lib.frumpy_release(out.value)==0
                    row=dict(dtype=np.dtype(dtype).name,operation=name,shape=shape,layout=layout,
                             input_bytes=source.nbytes,result_bytes=np.asarray(expected).nbytes,
                             widened_input_temporary_bytes=0)
                    calls=dict(python=lambda:function(a,**kwargs).close(),c_abi=abi,
                               numpy=lambda:oracle(source,**kwargs))
                    keys=list(calls)
                    if args.reverse:keys.reverse()
                    for key in keys:row[key]=timed(calls[key],7)
                    report['rows'].append(row)
                    if a is not owner:a.close()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':main()
