"""Allocating float32/float64 dot and outer through Python and the raw C ABI."""
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


def cases(dtype):
    rng = np.random.default_rng(20261028)
    for n in (16,1024,65536,1048576):
        a = (rng.integers(-128,129,n).astype(dtype)/128)
        b = (rng.integers(-128,129,n).astype(dtype)/128)
        for layout in ('C','reverse','step'):
            yield 'dot',str(n),layout,a,b
    for n in (16,64,128):
        a = rng.uniform(-1,1,(n,n)).astype(dtype)
        b = rng.uniform(-1,1,(n,n)).astype(dtype)
        yield 'dot',f'{n}x{n}','C',a,b
    yield 'dot','higher-rank','C',np.ones((2,3,16),dtype=dtype),np.ones((4,16,5),dtype=dtype)
    for n in (16,256,1024):
        a = np.linspace(-1,1,n,dtype=dtype)
        b = np.linspace(1,-1,n,dtype=dtype)
        yield 'outer',str(n),'C',a,b
        yield 'outer',str(n),'reverse',a,b


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--reverse',action='store_true')
    args = parser.parse_args()
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    library = Path(os.environ['FRUMPY_LIBRARY'])
    report = dict(source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
                  library_sha256=hashlib.sha256(library.read_bytes()).hexdigest(),
                  linkage=subprocess.check_output(['ldd',str(library)],text=True),
                  numpy=np.__version__,numpy_build=np.show_config(mode='dicts'),
                  compiler_flags='GNU 14 -std=f2018 -O3 -fimplicit-none',
                  affinity=sorted(os.sched_getaffinity(0)),threads=1,rows=[])
    lib = _ffi.library()
    for dtype in ([np.float64,np.float32] if args.reverse else [np.float32,np.float64]):
        for operation,size,layout,a,b in cases(dtype):
            owner = None
            if layout=='step':
                storage = np.zeros(a.size*2,dtype=dtype)
                storage[::2] = a
                owner = fp.asarray(storage)
                fa = owner[::2]
                a = storage[::2]
            elif layout=='reverse':
                owner = fp.asarray(a)
                fa = owner[::-1]
                a = a[::-1]
            else:
                fa = fp.asarray(a)
            fb = fp.asarray(b)
            oracle = getattr(np,operation)
            function = getattr(fp,operation)
            expected = oracle(a,b)
            reference = oracle(a.astype(float),b.astype(float))
            with function(fa,fb) as result:
                actual = result.numpy()
                assert actual.dtype==np.dtype(dtype) and actual.shape==np.shape(expected)
                if operation=='outer':
                    np.testing.assert_array_equal(actual,expected)
                else:
                    k = a.shape[-1]
                    scale = np.dot(np.abs(a.astype(float)),np.abs(b.astype(float)))
                    depth = 32+int(np.ceil(np.log2(max(1,k)))) if dtype==np.float32 else k+1
                    bound = 2*depth*np.finfo(dtype).eps*scale
                    assert np.all(np.abs(actual-reference)<=bound+np.finfo(dtype).tiny)
            out = _ffi.H()
            code = 1 if operation=='outer' else 2
            def abi():
                assert lib.frumpy_linalg(code,fa._handle,fb._handle,C.byref(out))==0
                assert lib.frumpy_release(out.value)==0
            def public():
                function(fa,fb).close()
            report['rows'].append(dict(dtype=np.dtype(dtype).name,operation=operation,size=size,
                layout=layout,result_bytes=np.asarray(expected).nbytes,
                max_absolute_error_to_float64=float(np.max(np.abs(actual-reference))),
                numpy_max_absolute_error_to_float64=float(np.max(np.abs(expected-reference))),
                python=timed(public,7),c_abi=timed(abi,7),numpy=timed(lambda:oracle(a,b),7)))
            fa.close()
            fb.close()
            if owner is not None:
                owner.close()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':
    main()
