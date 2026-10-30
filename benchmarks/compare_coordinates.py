"""Public-API coordinate extraction baseline, with imports outside timing."""
import argparse
import hashlib
import json
import os
from pathlib import Path
from statistics import median
from time import perf_counter_ns
import numpy as np
import frumpy as fp


def measure(call, loops):
    call()
    samples=[]
    for _ in range(7):
        start=perf_counter_ns()
        for _ in range(loops):call()
        samples.append((perf_counter_ns()-start)/loops/1000)
    return median(samples)


def close_result(result):
    if isinstance(result,tuple):
        for axis in result:axis.close()
    else:result.close()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    report=dict(numpy=np.__version__,cpu=min(os.sched_getaffinity(0)),
                library_sha256=hashlib.sha256(Path(os.environ['FRUMPY_LIBRARY']).read_bytes()).hexdigest(),rows=[])
    for dtype in (np.bool_,np.int32,np.int64,np.float32,np.float64):
        for n in (16,65536):
            for layout in ('C','F','step'):
                side=int(np.sqrt(n))
                data=(np.arange(n*(2 if layout=='step' else 1))%3).astype(dtype)
                if layout=='F':data=np.asfortranarray(data.reshape(side,side))
                with fp.asarray(data,order='K') as owner:
                    source=owner[::2] if layout=='step' else owner
                    oracle=data[::2] if layout=='step' else data
                    try:
                        for op in ('nonzero','argwhere'):
                            def native():close_result(getattr(fp,op)(source))
                            def numpy():getattr(np,op)(oracle)
                            report['rows'].append(dict(dtype=np.dtype(dtype).name,size=n,layout=layout,
                                operation=op,frumpy_us=measure(native,100 if n==16 else 5),
                                numpy_us=measure(numpy,100 if n==16 else 5)))
                    finally:
                        if source is not owner:source.close()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':main()
