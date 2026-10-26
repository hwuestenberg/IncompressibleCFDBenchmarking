#!/usr/bin/env bash
#
# Run a single leg of the 2D NACA0012 validation case (see ../README.md).
# Requires the relevant NEKTAR_*_BIN variable(s) to be exported first:
#
#   source env.sh   # copied+edited from env.sh.example
#
# Usage:
#   ./run_case.sh --solver legacy|semiimplicit
#                 [--exec-space Serial|AVX|Device] [--impl StdMat|SumFac|SumFacTOP]
#                 [--np N] [--steps N] [--outdir DIR]
#
# --exec-space is required for --solver semiimplicit and ignored for
# --solver legacy. --impl defaults to StdMat on Serial/AVX and SumFacTOP on
# Device. --np overrides MPI_NP (or MPI_NP_DEVICE for Device). --steps
# overrides NumSteps for a short smoke/troubleshooting run (-P NumSteps=N).
# Output (run.log, run.err, total.fce, EnergyFile.eny, checkpoints, ...) is
# written to --outdir (default: results/<label>/ under this directory).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASE_ROOT="$(dirname "$HERE")"

solver=""
exec_space=""
impl=""
np=""
steps=""
outdir=""

while [ $# -gt 0 ]; do
    case "$1" in
        --solver) solver="$2"; shift 2 ;;
        --exec-space) exec_space="$2"; shift 2 ;;
        --impl) impl="$2"; shift 2 ;;
        --np) np="$2"; shift 2 ;;
        --steps) steps="$2"; shift 2 ;;
        --outdir) outdir="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

mesh="$CASE_ROOT/mesh/naca0012-2d.xml"
case "$solver" in
    legacy)
        session="$CASE_ROOT/session-legacy.xml"
        bin="${NEKTAR_LEGACY_BIN:?Set NEKTAR_LEGACY_BIN (see env.sh.example)}"
        extra_args=()
        run_label="legacy"
        np="${np:-${MPI_NP:-1}}"
        ;;
    semiimplicit)
        session="$CASE_ROOT/session-redesign.xml"
        case "$exec_space" in
            Serial) bin="${NEKTAR_REDESIGN_SERIAL_BIN:-${NEKTAR_REDESIGN_BIN:-}}"; impl="${impl:-StdMat}" ;;
            AVX)    bin="${NEKTAR_REDESIGN_AVX_BIN:-${NEKTAR_REDESIGN_BIN:-}}";    impl="${impl:-StdMat}" ;;
            Device) bin="${NEKTAR_REDESIGN_DEVICE_BIN:-${NEKTAR_REDESIGN_BIN:-}}"; impl="${impl:-SumFacTOP}" ;;
            *) echo "--exec-space must be Serial, AVX, or Device" >&2; exit 1 ;;
        esac
        [[ -n "$bin" ]] || { echo "Set NEKTAR_REDESIGN_BIN or an execution-space-specific binary" >&2; exit 2; }
        extra_args=(--opExecSpace="$exec_space" --opImpl="$impl")
        run_label="$solver-$exec_space-$impl"
        if [ "$exec_space" = "Device" ]; then
            np="${np:-${MPI_NP_DEVICE:-1}}"
        else
            np="${np:-${MPI_NP:-1}}"
        fi
        ;;
    *) echo "--solver must be 'legacy' or 'semiimplicit'" >&2; exit 1 ;;
esac

[[ "$np" =~ ^[1-9][0-9]*$ ]] || { echo "--np must be a positive integer" >&2; exit 2; }

if [ -n "$steps" ]; then
    extra_args+=(-P "NumSteps=$steps")
    run_label="$run_label-${steps}steps"
fi
run_label="$run_label-np$np"

[ -n "$outdir" ] || outdir="$HERE/results/$run_label"
mkdir -p "$outdir"

echo "== $run_label =="
echo "   session: $session"
echo "   binary:  $bin ${extra_args[*]:-}"
echo "   ranks:   $np"
echo "   outdir:  $outdir"

launcher=()
if [ "$np" -gt 1 ]; then
    launcher=("${MPI_LAUNCHER:-mpirun}" -np "$np")
fi

(
    cd "$outdir"
    ln -sfn "$mesh" "$(basename "$mesh")"
    "${launcher[@]}" "$bin" "$(basename "$mesh")" "$session" \
        "${extra_args[@]}" -v > run.log 2> run.err
)

echo "   done -- see $outdir/run.log, run.err, total.fce"
