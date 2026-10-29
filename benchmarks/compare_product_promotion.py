"""Measure implicit promotion, reusable precasts and isolated conversion costs."""
import argparse
import ctypes as C
import hashlib
import json
import os
import re
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
    parser.add_argument('--source-commit',help='Commit that produced the supplied library')
    parser.add_argument('--case-filter',help='Regex on left/right/operation/n/layout')
    args=parser.parse_args()
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    library=Path(os.environ['FRUMPY_LIBRARY'])
    report=dict(source_commit=args.source_commit or subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
                library_sha256=hashlib.sha256(library.read_bytes()).hexdigest(),
                linkage=subprocess.check_output(['ldd',str(library)],text=True),
                numpy=np.__version__,numpy_build=np.show_config(mode='dicts'),
                compiler_flags='GNU 14 -std=f2018 -O3 -fimplicit-none',
                affinity=sorted(os.sched_getaffinity(0)),threads=1,case_filter=args.case_filter,rows=[])
    lib=_ffi.library()
    pairs=[(np.bool_,np.float32),(np.int32,np.float32),(np.float32,np.float64)]
    cases=[('dot',16),('dot',65536),('outer',256),('matmul',16),('matmul',128)]
    if args.reverse: pairs.reverse();cases.reverse()
    for left,right in pairs:
        dtype=np.result_type(left,right)
        dtype_id=4 if dtype==np.float32 else 5
        for operation,n in cases:
            shape=(n,n) if operation=='matmul' else (n,)
            for layout in ['C','step']:
                key=f'{np.dtype(left).name}/{np.dtype(right).name}/{operation}/{n}/{layout}'
                if args.case_filter and not re.search(args.case_filter,key):
                    continue
                owners=[]
                arrays=[]
                values=[]
                for dt in [left,right]:
                    base=np.ones(shape[:-1]+(shape[-1]*(2 if layout=='step' else 1),),dtype=dt)
                    owner=fp.asarray(base);owners.append(owner)
                    arrays.append(owner[...,::2] if layout=='step' else owner)
                    values.append(base[...,::2] if layout=='step' else base)
                a,b=arrays
                pa=a.astype(dtype) if left!=dtype else a
                pb=b.astype(dtype) if right!=dtype else b
                conversions=[x for x,dt in zip(arrays,[left,right]) if dt!=dtype]
                function=getattr(fp,operation)
                oracle=getattr(np,operation)
                with function(a,b) as result:
                    np.testing.assert_array_equal(result.numpy(),oracle(*values))
                code={'outer':1,'dot':2,'matmul':3}[operation]
                out=_ffi.H()
                def abi(x,y):
                    assert lib.frumpy_linalg(code,x._handle,y._handle,C.byref(out))==0
                    assert lib.frumpy_release(out.value)==0
                def cast_c():
                    for x in conversions:
                        assert lib.frumpy_cast(x._handle,dtype_id,4,C.byref(out))==0
                        assert lib.frumpy_release(out.value)==0
                def cast_python():
                    for x in conversions:x.astype(dtype).close()
                row=dict(left=np.dtype(left).name,right=np.dtype(right).name,
                         result_dtype=dtype.name,operation=operation,n=n,layout=layout,
                         cast_payload_bytes=sum(v.size*dtype.itemsize for v,dt in zip(values,[left,right]) if dt!=dtype),
                         result_bytes=np.asarray(oracle(*values)).nbytes)
                workloads=dict(python_mixed=lambda:function(a,b).close(),
                               python_precast=lambda:function(pa,pb).close(),
                               c_mixed=lambda:abi(a,b),c_precast=lambda:abi(pa,pb),
                               python_cast_only=cast_python,c_cast_only=cast_c,
                               numpy_mixed=lambda:oracle(*values))
                order=list(workloads)
                if args.reverse:order.reverse()
                for key in order:row[key]=timed(workloads[key],7)
                report['rows'].append(row)
                for obj in {id(x):x for x in [*owners,*arrays,pa,pb]}.values():obj.close()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':main()
