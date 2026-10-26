#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
steps=50000; np="${MPI_NP:-1}"; exec_space=Serial; outdir="$(dirname "$here")/results"
while (($#)); do
    case "$1" in
        --steps) steps="$2"; shift 2;;
        --np) np="$2"; shift 2;;
        --exec-space) exec_space="$2"; shift 2;;
        --outdir) outdir="$2"; shift 2;;
        *) echo "Unknown argument: $1" >&2; exit 2;;
    esac
done
for formulation in semiimplicit; do
    "$here/run_case.sh" --solver legacy --formulation "$formulation" --steps "$steps" --np "$np" --outdir "$outdir/legacy-$formulation"
    "$here/run_case.sh" --solver redesign --formulation "$formulation" --exec-space "$exec_space" --steps "$steps" --np "$np" --outdir "$outdir/redesign-$formulation-$exec_space"
done
"$here/compare_forces.py" "$outdir" --exec-space "$exec_space"
