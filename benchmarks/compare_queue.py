"""Nonuniform traversal, small-call overhead and matched LP64 backend measurements."""
import argparse
import ctypes as C
import hashlib
import json
import os
from pathlib import Path
import subprocess
import statistics
import time
for name in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ[name] = "1"
import numpy as np
import frumpy as fp
from frumpy import _ffi


def timed(call, samples):
    call()
    start = time.perf_counter()
    call()
    iterations = max(1, min(1000, int(.03 / max(time.perf_counter()-start, 1e-9))))
    wall, cpu = [], []
    for _ in range(samples):
        start, cpu_start = time.perf_counter(), time.process_time()
        for _ in range(iterations):
            call()
        cpu.append((time.process_time()-cpu_start)/iterations)
        wall.append((time.perf_counter()-start)/iterations)
    return dict(iterations=iterations, seconds=wall, median_seconds=statistics.median(wall),
                cpu_seconds=cpu, median_cpu_seconds=statistics.median(cpu))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--label', required=True)
    parser.add_argument('--blas', required=True)
    parser.add_argument('--lapack', required=True)
    args = parser.parse_args()
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    blas, lapack = C.CDLL(args.blas), C.CDLL(args.lapack)
    gemm = blas.cblas_dgemm
    gemm.argtypes = [C.c_int]*6 + [C.c_double,C.c_void_p,C.c_int,C.c_void_p,C.c_int,C.c_double,C.c_void_p,C.c_int]
    gemm.restype = None
    gesv = lapack.dgesv_
    gesv.argtypes = [C.c_void_p]*8
    gesv.restype = None
    config = 'reference LP64 BLAS/LAPACK'
    if hasattr(blas, 'openblas_get_config'):
        blas.openblas_get_config.restype = C.c_char_p
        config = blas.openblas_get_config().decode()
        blas.openblas_get_num_threads.restype = C.c_int
        assert blas.openblas_get_num_threads() == 1
    library = Path(os.environ['FRUMPY_LIBRARY'])
    # Resolve bindings used by the Frumpy library, not just the raw reference call.
    linkage = subprocess.check_output(['ldd', str(library)], text=True)
    report = dict(label=args.label, backend=config, numpy_build=np.show_config(mode='dicts'),
        compiler_flags='GNU 14 -std=f2018 -O3 -fimplicit-none', blas=str(Path(args.blas).resolve()),
        lapack=str(Path(args.lapack).resolve()), linkage=linkage,
        library_sha256=hashlib.sha256(library.read_bytes()).hexdigest(),
        wrapper_sha256=hashlib.sha256(Path(fp.__file__).with_name('_ffi.py').read_bytes()).hexdigest(),
        affinity=sorted(os.sched_getaffinity(0)), threads=1, numpy=np.__version__,
        method='Seven warmed samples, allocating call/release timed, setup/export excluded. '
               'Raw BLAS uses the same library and thread count; it omits Frumpy metadata and finite checks. '
               'NumPy uses its own wheel backend, recorded as a separate reference. '
               'Wall and process CPU times are recorded for each batch.',
        arithmetic=[], matrices=[], small=[])
    for width in (1,4,8,16,128,1024):
        rows = 1024 if width < 128 else 256
        for layout in ('row', 'column', 'transpose', 'reverse_rows'):
            a = (np.arange(rows*width).reshape(rows,width)%127+1).astype(np.float64)
            if layout == 'transpose': a=np.asfortranarray(a)
            fa = fp.asarray(a, order='K')
            if layout == 'reverse_rows': a,fa=a[::-1],fa[::-1]
            b = np.full((rows,1) if layout == 'column' else (1,width),2.)
            fb = fp.asarray(b)
            with fa+fb as actual: np.testing.assert_array_equal(actual.numpy(), a+b)
            def call(): (fa+fb).close()
            report['arithmetic'].append(dict(shape=a.shape,layout=layout,
                frumpy=timed(call,7),numpy=timed(lambda:a+b,7)))
            fa.close();fb.close()
    for n in (16,128,512):
        for layout in ('C','F','stepped'):
            a=(np.arange(n*n).reshape(n,n)%17).astype(np.float64)/17
            b=np.ones((n,n))
            fa,fb=fp.asarray(a),fp.asarray(b)
            if layout=='F':
                a=np.asfortranarray(a);b=np.asfortranarray(b)
                fa,fb=fp.asarray(a,order='K'),fp.asarray(b,order='K')
            elif layout=='stepped':
                backing=np.zeros((n,n*2));backing[:,::2]=a
                fa=fp.asarray(backing)[:,::2]
            with fa@fb as actual: np.testing.assert_allclose(actual.numpy(),a@b,rtol=2e-12,atol=2e-12)
            # Raw allocating CBLAS baseline on pre-created C inputs; no hidden per-call packing.
            ac,bc=np.ascontiguousarray(a),np.ascontiguousarray(b)
            def raw():
                result=np.empty((n,n))
                gemm(101,111,111,n,n,n,1.,ac.ctypes.data,n,bc.ctypes.data,n,0.,result.ctypes.data,n)
                return result
            np.testing.assert_allclose(raw(),a@b,rtol=2e-12,atol=2e-12)
            def call(): (fa@fb).close()
            report['matrices'].append(dict(operation='matmul',size=n,layout=layout,
                frumpy=timed(call,7),raw_backend=timed(raw,7),numpy=timed(lambda:a@b,7)))
            fa.close();fb.close()
        a=(np.arange(n*n).reshape(n,n)%17).astype(np.float64)/17 + np.eye(n)*n
        b=np.ones((n,n));fa,fb=fp.asarray(a),fp.asarray(b)
        def solve(): fp.linalg.solve(fa,fb).close()
        def raw_solve():
            aa,bb=np.array(a,order='F'),np.array(b,order='F')
            pivots=np.empty(n,dtype=np.int32);nn=C.c_int(n);info=C.c_int()
            gesv(C.byref(nn),C.byref(nn),aa.ctypes.data,C.byref(nn),pivots.ctypes.data,
                 bb.ctypes.data,C.byref(nn),C.byref(info))
            assert info.value==0
            return bb
        with fp.linalg.solve(fa,fb) as actual:
            np.testing.assert_allclose(actual.numpy(),raw_solve(),rtol=2e-12,atol=2e-12)
        report['matrices'].append(dict(operation='solve',size=n,layout='C',frumpy=timed(solve,7),
            raw_backend=timed(raw_solve,7),numpy=timed(lambda:np.linalg.solve(a,b),7)))
        fa.close();fb.close()
    x,y=fp.asarray(np.arange(16.)),fp.asarray(np.ones(16))
    def public(): (x+y).close()
    def checked():
        handle=_ffi.make('binary',1,x._handle,y._handle);_ffi.call('release',handle)
    for name,call in [('public_add',public),('checked_ffi',checked)]:
        report['small'].append(dict(name=name,**timed(call,7)))
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__': main()
