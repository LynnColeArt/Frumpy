set -eu
scratch=/home/lynn/Documents/Codex/2026-09-07/so/work
export PYTHONPATH=python OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
mkdir -p "$scratch/casting-bench"
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
      build="$scratch/promotion-matrix/gfortran-14-release"
      source=0dc8740
      if [ "$phase" = after ]; then build="$scratch/casting-matrix/gfortran-14-release"; source=4d2cabb; fi
      export FRUMPY_LIBRARY="$build/libfrumpy.so"
      .venv/bin/python benchmarks/compare_product_promotion.py --source-commit "$source" --output "$scratch/casting-bench/$phase-$backend-$run.json" $reverse
      taskset -c 0 "$build/bin/benchmark_product_promotion" > "$scratch/casting-bench/native-$phase-$backend-$run.txt"
      echo "$phase $backend run $run complete"
    done
  done
done
