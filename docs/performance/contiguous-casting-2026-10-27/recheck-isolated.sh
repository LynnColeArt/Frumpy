set -eu
scratch=/home/lynn/Documents/Codex/2026-09-07/so/work
export PYTHONPATH=python OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
export LD_LIBRARY_PATH="$scratch/queue-openblas/extracted/usr/lib/x86_64-linux-gnu/openblas-pthread"
for metric in c python cast; do
 index=0
 for phase in before after after before; do
  index=$((index+1))
  build="$scratch/promotion-matrix/gfortran-14-release"
  if [ "$phase" = after ]; then build="$scratch/casting-matrix/gfortran-14-release"; fi
  export FRUMPY_LIBRARY="$build/libfrumpy.so"
  .venv/bin/python benchmarks/recheck_stepped_casting.py --metric "$metric" --output "$scratch/casting-bench/isolated-$metric-$index-$phase.json"
 done
done
