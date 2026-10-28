set -eu
scratch=/home/lynn/Documents/Codex/2026-09-07/so/work
export FRUMPY_LIBRARY="$scratch/norms-matrix/gfortran-14-release/libfrumpy.so"
export PYTHONPATH=python OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
mkdir -p "$scratch/norms-bench"
for run in 1 2; do
 backends='reference openblas'
 reverse=''
 if [ "$run" = 2 ]; then backends='openblas reference'; reverse='--reverse'; fi
 for backend in $backends; do
  if [ "$backend" = reference ]; then
   export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/blas:/usr/lib/x86_64-linux-gnu/lapack
  else
   export LD_LIBRARY_PATH="$scratch/queue-openblas/extracted/usr/lib/x86_64-linux-gnu/openblas-pthread"
  fi
  .venv/bin/python benchmarks/compare_float32_norms.py --output "$scratch/norms-bench/$backend-$run.json" $reverse
  taskset -c 0 "$scratch/norms-matrix/gfortran-14-release/bin/benchmark_norms_precision" > "$scratch/norms-bench/native-$backend-$run.txt"
  echo "$backend run $run complete"
 done
done
