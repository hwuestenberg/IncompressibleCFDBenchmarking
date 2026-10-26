#!/usr/bin/env bash
#
# Run a single leg of the Taylor-Green vortex validation benchmark (see
# ../README.md). Requires the relevant NEKTAR_*_BIN variable(s) to be
# exported first, e.g.:
#
#   source env.sh   # copied+edited from env.sh.example
#
# Usage:
#   ./run_case.sh --solver legacy|semiimplicit \
#                 [--exec-space Serial|AVX|Device] [--np N] [--outdir DIR]
#
# --exec-space is required for --solver semiimplicit and
# ignored for --solver legacy. Output is written to --outdir (default:
# results/<solver>[-<exec-space>]/ under this scripts/ directory).
#
# This case is expensive (262144 hex elements, P=3, 100000 steps for the
# full FinalTime=20 decay curve -- see ../README.md for a cheaper
# truncated option). Use --np N with N>1 for anything but a
# short smoke test.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASE_ROOT="$(dirname "$HERE")"

solver=""
exec_space=""
outdir=""
np="${MPI_NP:-1}"

while [ $# -gt 0 ]; do
    case "$1" in
        --solver) solver="$2"; shift 2 ;;
        --exec-space) exec_space="$2"; shift 2 ;;
        --np) np="$2"; shift 2 ;;
        --outdir) outdir="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

case "$solver" in
    legacy|semiimplicit) ;;
    *) echo "--solver must be 'legacy' or 'semiimplicit'" >&2; exit 1 ;;
esac

mesh="$CASE_ROOT/mesh/tgv-64.xml"
[ -f "$mesh" ] || {
    echo "Missing $mesh -- build it first with $CASE_ROOT/build_mesh.sh" >&2
    exit 1
}

if [ "$solver" = "legacy" ]; then
    session="$CASE_ROOT/session-legacy.xml"
    : "${NEKTAR_LEGACY_BIN:?Set NEKTAR_LEGACY_BIN (see env.sh.example)}"
    bin="$NEKTAR_LEGACY_BIN"
    extra_args=()
    run_label="legacy"
else
    session="$CASE_ROOT/session-redesign.xml"
    [ -n "$exec_space" ] || {
        echo "--exec-space is required for --solver $solver" >&2; exit 1;
    }
    case "$exec_space" in
        Serial) bin="${NEKTAR_REDESIGN_SERIAL_BIN:-${NEKTAR_REDESIGN_BIN:-}}"; impl=StdMat ;;
        AVX)    bin="${NEKTAR_REDESIGN_AVX_BIN:-${NEKTAR_REDESIGN_BIN:-}}";    impl=StdMat ;;
        Device) bin="${NEKTAR_REDESIGN_DEVICE_BIN:-${NEKTAR_REDESIGN_BIN:-}}"; impl=SumFacTOP ;;
        *) echo "--exec-space must be Serial, AVX, or Device" >&2; exit 1 ;;
    esac
    [[ -n "$bin" ]] || { echo "Set NEKTAR_REDESIGN_BIN or an execution-space-specific binary" >&2; exit 2; }
    extra_args=(--opExecSpace="$exec_space" --opImpl="$impl")
    run_label="$solver-$exec_space"
fi

[ -n "$outdir" ] || outdir="$HERE/results/$run_label"
mkdir -p "$outdir"

echo "== $run_label =="
echo "   mesh:    $mesh"
echo "   session: $session"
echo "   binary:  $bin ${extra_args[*]:-}"
echo "   outdir:  $outdir"

[[ "$np" =~ ^[1-9][0-9]*$ ]] || { echo "--np must be a positive integer" >&2; exit 2; }
launcher=()
if [ "$np" -gt 1 ]; then
    launcher=("${MPI_LAUNCHER:-mpirun}" -np "$np")
fi

(
    cd "$outdir"
    "${launcher[@]}" "$bin" "$mesh" "$session" "${extra_args[@]}" -v \
        > run.log 2> run.err
)

echo "   done -- see $outdir/run.log, run.err"
echo "   tgv-64.eny has the Time/KineticEnergy/Enstrophy series (both legacy"
echo "   and redesign use the Energy filter -- see ../README.md); Nektar"
echo "   names filter output after the first/mesh xml's basename. Compare"
echo "   with ../scripts/dissipation_rate.py."
