import os,subprocess,json,statistics
from pathlib import Path
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
root=Path('/home/lynn/Documents/Codex/2026-09-07/so/work')
script='''import numpy as np,frumpy as fp,time,json
n=1048576
owner=fp.asarray((np.arange(n*2)%127+1).astype(np.float64)/128)
a=owner[::2];b=fp.asarray(np.full(n,2.))
(a+b).close()
t=[]
for sample in range(7):
 start=time.perf_counter()
 for i in range(10): (a+b).close()
 t.append((time.perf_counter()-start)/10)
print(json.dumps(t))
'''
rows=[]
for repeat in range(5):
 for label in (('before','after') if repeat%2==0 else ('after','before')):
  build=root/('sort-matrix' if label=='before' else 'contiguous-matrix')/'gfortran-14-release'
  env=dict(os.environ,FRUMPY_LIBRARY=str(build/'libfrumpy.so'),PYTHONPATH='python',OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1')
  native=[float(x) for x in subprocess.check_output([str(build/'bin/benchmark_driver'),'add_r64','stride2','1048576','10','7'],env=env,text=True).split()][1:]
  python=json.loads(subprocess.check_output(['.venv/bin/python','-c',script],env=env,text=True))
  rows.append(dict(repeat=repeat,label=label,native=native,python=python))
  print(label,statistics.median(native),statistics.median(python),flush=True)
(root/'contiguous-results/stride-control.json').write_text(json.dumps(dict(method='Five alternating pairs, seven warmed samples of ten allocating calls each, one CPU, one thread, same libraries as main comparison',rows=rows),indent=2)+'\n')
