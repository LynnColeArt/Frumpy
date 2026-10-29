set -eu
scratch=/home/lynn/Documents/Codex/2026-09-07/so/work
export PYTHONPATH=python OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
export LD_LIBRARY_PATH="$scratch/queue-openblas/extracted/usr/lib/x86_64-linux-gnu/openblas-pthread"
index=0
for phase in before after after before; do
 index=$((index+1))
 build="$scratch/promotion-matrix/gfortran-14-release"
 source=0dc8740
 if [ "$phase" = after ]; then build="$scratch/casting-matrix/gfortran-14-release"; source=4d2cabb; fi
 export FRUMPY_LIBRARY="$build/libfrumpy.so"
 .venv/bin/python benchmarks/compare_product_promotion.py --source-commit "$source" --case-filter 'bool/float32/(outer/256|dot/65536|matmul/16)/step|float32/float64/(outer/256/(C|step)|matmul/16/step)' --output "$scratch/casting-bench/recheck-$index-$phase.json"
 echo "recheck $index $phase complete"
done
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/blas:/usr/lib/x86_64-linux-gnu/lapack
index=0
for phase in before after after before; do
 index=$((index+1))
 build="$scratch/promotion-matrix/gfortran-14-release"
 if [ "$phase" = after ]; then build="$scratch/casting-matrix/gfortran-14-release"; fi
 taskset -c 0 "$build/bin/benchmark_product_promotion" > "$scratch/casting-bench/native-recheck-$index-$phase.txt"
done
