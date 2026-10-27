"""Isolate the stepped bool/float32 dot control from other benchmark workloads."""
import argparse
import ctypes as C
import hashlib
import json
import os
from pathlib import Path
from compare_queue import timed
import numpy as np
import frumpy as fp
from frumpy import _ffi

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--metric',choices=['c','python','cast'],required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
library=Path(os.environ['FRUMPY_LIBRARY'])
lib=_ffi.library()
with fp.asarray(np.ones(131072,dtype=np.bool_)) as ao,fp.asarray(np.ones(131072,dtype=np.float32)) as bo:
    with ao[::2] as a,bo[::2] as b:
        with fp.dot(a,b) as result:
            assert result.item()==65536
        out=_ffi.H()
        def call():
            if args.metric=='python':
                fp.dot(a,b).close()
            else:
                if args.metric=='c':
                    code=lib.frumpy_linalg(2,a._handle,b._handle,C.byref(out))
                else:
                    code=lib.frumpy_cast(a._handle,4,4,C.byref(out))
                assert code==0
                assert lib.frumpy_release(out.value)==0
        result=dict(metric=args.metric,library_sha256=hashlib.sha256(library.read_bytes()).hexdigest(),
                    timing=timed(call,21),affinity=sorted(os.sched_getaffinity(0)),threads=1)
args.output.write_text(json.dumps(result,indent=2)+'\n')
