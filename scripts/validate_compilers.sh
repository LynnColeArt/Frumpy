#!/usr/bin/env bash
# Run the same suite with strict/debug and optimized builds in separate directories.
set -euo pipefail
build_root=${1:?supply a build directory followed by compiler executables}
shift
if (($# == 0)); then
  echo 'Supply at least one GNU Fortran or LLVM Flang compiler.' >&2
  exit 2
fi
for compiler in "$@"; do
  command -v "$compiler" >/dev/null || { echo "Compiler not found: $compiler" >&2; exit 2; }
done
for compiler in "$@"; do
  name=$(basename "$compiler")
  version=$("$compiler" --version)
  case "$version" in
    *'GNU Fortran'*)
      debug='-std=f2018 -Wall -Wextra -Werror -fimplicit-none -fcheck=all -fbacktrace'
      release='-std=f2018 -O3 -fimplicit-none'
      ;;
    *flang*)
      debug='-O0 -g -Werror'
      release='-O3 -Werror'
      ;;
    *) echo "Unrecognized compiler: $compiler" >&2; exit 2 ;;
  esac
  for mode in debug release; do
    mkdir -p "$build_root/$name"
    directory=$(mktemp -d "$build_root/$name/$mode.XXXXXX")
    flags=$debug
    if [[ $mode == release ]]; then flags=$release; fi
    printf '%s\nFlags: %s\n' "$version" "$flags" > "$directory/validation.log"
    echo "VALIDATE $name $mode"
    if ! make validate FC="$compiler" FFLAGS="$flags" BUILD_DIR="$directory" \
        >> "$directory/validation.log" 2>&1; then
      tail -40 "$directory/validation.log" >&2
      exit 1
    fi
    echo "PASS $name $mode ($directory/validation.log)"
  done
done
