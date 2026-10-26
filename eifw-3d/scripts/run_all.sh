#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
np='' steps=200000 exec_space=Serial outdir="$(dirname "$here")/results"
source_args=()
while (($#)); do
    case "$1" in
        --np) np="$2"; shift 2;;
        --steps) steps="$2"; shift 2;;
        --exec-space) exec_space="$2"; shift 2;;
        --outdir) outdir="$2"; shift 2;;
        --source) source_args=(--source "$2"); shift 2;;
        *) echo "Unknown argument: $1" >&2; exit 2;;
    esac
done
[[ "$np" =~ ^[1-9][0-9]*$ ]] || { echo 'Supply --np N' >&2; exit 2; }
for formulation in semiimplicit; do
    "$here/run_case.sh" --solver legacy --formulation "$formulation" --np "$np" --steps "$steps" --outdir "$outdir/legacy-$formulation" "${source_args[@]}"
    "$here/run_case.sh" --solver redesign --formulation "$formulation" --exec-space "$exec_space" --np "$np" --steps "$steps" --outdir "$outdir/redesign-$formulation-$exec_space" "${source_args[@]}"
done
"$here/compare_forces.py" "$outdir" --exec-space "$exec_space"
