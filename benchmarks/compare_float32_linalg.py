"""Float32/float64 allocating linalg across Python, C ABI and matched LP64 BLAS."""
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--blas', required=True)
    parser.add_argument('--lapack', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--reverse', action='store_true', help='Measure float64 before float32')
    args = parser.parse_args()
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    blas, lapack = C.CDLL(args.blas), C.CDLL(args.lapack)
    library = Path(os.environ['FRUMPY_LIBRARY'])
    report = dict(source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
                  compiler_flags='GNU 14 -std=f2018 -O3 -fimplicit-none',
                  library_sha256=hashlib.sha256(library.read_bytes()).hexdigest(),
                  linkage=subprocess.check_output(['ldd', str(library)], text=True),
                  numpy=np.__version__, numpy_build=np.show_config(mode='dicts'),
                  blas=str(Path(args.blas).resolve()), lapack=str(Path(args.lapack).resolve()),
                  threads=1, affinity=sorted(os.sched_getaffinity(0)), rows=[])
    lib = _ffi.library()
    precisions = [(np.float32, 's', C.c_float), (np.float64, 'd', C.c_double)]
    if args.reverse:
        precisions.reverse()
    for dtype, prefix, scalar in precisions:
        gemm = getattr(blas, 'cblas_'+prefix+'gemm')
        gemm.argtypes = [C.c_int]*6 + [scalar,C.c_void_p,C.c_int,C.c_void_p,C.c_int,
                                       scalar,C.c_void_p,C.c_int]
        gemm.restype = None
        gesv = getattr(lapack, prefix+'gesv_')
        gesv.argtypes, gesv.restype = [C.c_void_p]*8, None
        for n in (16, 128, 512):
            for operation, layout in [('matmul','C'),('matmul','F'),('matmul','stepped'),('solve','C')]:
                a = (np.arange(n*n).reshape(n,n)%17).astype(dtype)/dtype(17)
                b = np.ones((n,n), dtype=dtype)
                if operation == 'solve':
                    a += np.eye(n,dtype=dtype)*n
                if layout == 'F':
                    a, b = np.asfortranarray(a), np.asfortranarray(b)
                owner = None
                if layout == 'stepped':
                    storage = np.zeros((n,n*2), dtype=dtype)
                    storage[:,::2] = a
                    owner = fp.asarray(storage)
                    fa = owner[:,::2]
                else:
                    fa = fp.asarray(a,order='K')
                fb = fp.asarray(b,order='K')
                code = 3 if operation == 'matmul' else 4
                out = _ffi.H()
                def abi():
                    assert lib.frumpy_linalg(code,fa._handle,fb._handle,C.byref(out)) == 0
                    assert lib.frumpy_release(out.value) == 0
                def public():
                    result = fa@fb if operation == 'matmul' else fp.linalg.solve(fa,fb)
                    result.close()
                ac, bc = np.ascontiguousarray(a), np.ascontiguousarray(b)
                if operation == 'matmul':
                    def raw():
                        c = np.empty((n,n),dtype=dtype)
                        gemm(101,111,111,n,n,n,1,ac.ctypes.data,n,bc.ctypes.data,n,0,c.ctypes.data,n)
                        return c
                    oracle = lambda: a@b
                else:
                    def raw():
                        aa,bb = np.array(a,order='F'),np.array(b,order='F')
                        pivots = np.empty(n,dtype=np.int32)
                        nn, info = C.c_int(n), C.c_int()
                        gesv(C.byref(nn),C.byref(nn),aa.ctypes.data,C.byref(nn),pivots.ctypes.data,
                             bb.ctypes.data,C.byref(nn),C.byref(info))
                        assert info.value == 0
                        return bb
                    oracle = lambda: np.linalg.solve(a,b)
                tolerance = 1e-4 if dtype == np.float32 else 2e-12
                with (fa@fb if operation == 'matmul' else fp.linalg.solve(fa,fb)) as actual:
                    assert actual.dtype == np.dtype(dtype)
                    np.testing.assert_allclose(actual.numpy(),oracle(),rtol=tolerance,atol=tolerance)
                    np.testing.assert_allclose(actual.numpy(),raw(),rtol=tolerance,atol=tolerance)
                report['rows'].append(dict(dtype=np.dtype(dtype).name,operation=operation,size=n,
                    layout=layout,result_bytes=n*n*np.dtype(dtype).itemsize, python=timed(public,7),
                    c_abi=timed(abi,7),raw_backend=timed(raw,7),numpy=timed(oracle,7)))
                fa.close()
                fb.close()
                if owner is not None:
                    owner.close()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')


if __name__ == '__main__':
    main()
