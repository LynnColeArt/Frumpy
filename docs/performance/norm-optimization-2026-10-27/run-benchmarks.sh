set -eu
scratch=/home/lynn/Documents/Codex/2026-09-07/so/work
export PYTHONPATH=python OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
mkdir -p "$scratch/norm-opt-bench"
for run in 1 2; do
 backends='reference openblas'
 phases='before after'
 reverse=''
 if [ "$run" = 2 ]; then backends='openblas reference'; phases='after before'; reverse='--reverse'; fi
 for backend in $backends; do
  if [ "$backend" = reference ]; then
   export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/blas:/usr/lib/x86_64-linux-gnu/lapack
  else
   export LD_LIBRARY_PATH="$scratch/queue-openblas/extracted/usr/lib/x86_64-linux-gnu/openblas-pthread"
  fi
  for phase in $phases; do
   build="$scratch/norms-matrix/gfortran-14-release"
   source=1e6bc5a
   if [ "$phase" = after ]; then build="$scratch/norm-opt-matrix/gfortran-14-release"; source=5757b61; fi
   export FRUMPY_LIBRARY="$build/libfrumpy.so"
   .venv/bin/python benchmarks/compare_float32_norms.py --source-commit "$source" --output "$scratch/norm-opt-bench/$phase-$backend-$run.json" $reverse
   taskset -c 0 "$build/bin/benchmark_norms_comparison" > "$scratch/norm-opt-bench/native-$phase-$backend-$run.txt"
   # Nonuniform/irregular suite is reference-linked; norms dispatch no BLAS.
   if [ "$backend" = reference ]; then
    .venv/bin/python benchmarks/compare_float32_norms.py --source-commit "$source" --varied --output "$scratch/norm-opt-bench/varied-$phase-$run.json" $reverse
    taskset -c 0 "$build/bin/benchmark_norms_comparison" varied > "$scratch/norm-opt-bench/native-varied-$phase-$run.txt"
   fi
   echo "$phase $backend run $run complete"
  done
 done
done
