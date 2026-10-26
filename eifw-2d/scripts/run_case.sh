#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case_root="$(dirname "$here")"
solver='' formulation='' exec_space=Serial outdir='' steps=50000 np="${MPI_NP:-1}"
while (($#)); do
    case "$1" in
        --solver) solver="$2"; shift 2;;
        --formulation) formulation="$2"; shift 2;;
        --exec-space) exec_space="$2"; shift 2;;
        --np) np="$2"; shift 2;;
        --steps) steps="$2"; shift 2;;
        --outdir) outdir="$2"; shift 2;;
        *) echo "Unknown argument: $1" >&2; exit 2;;
    esac
done
[[ "$solver" == legacy || "$solver" == redesign ]] || { echo 'Use --solver legacy|redesign' >&2; exit 2; }
[[ "$formulation" == semiimplicit ]] || { echo 'Use --formulation semiimplicit' >&2; exit 2; }
[[ "$steps" =~ ^[1-9][0-9]*$ && "$np" =~ ^[1-9][0-9]*$ ]] || { echo 'Steps and MPI ranks must be positive integers' >&2; exit 2; }
if [[ "$solver" == legacy ]]; then
    : "${NEKTAR_LEGACY_BIN:?Set NEKTAR_LEGACY_BIN}"
    bin="$NEKTAR_LEGACY_BIN"; extra=(); label="legacy-$formulation"
else
    case "$exec_space" in
        Serial) bin="${NEKTAR_REDESIGN_SERIAL_BIN:-${NEKTAR_REDESIGN_BIN:-}}"; impl=StdMat;;
        AVX) bin="${NEKTAR_REDESIGN_AVX_BIN:-${NEKTAR_REDESIGN_BIN:-}}"; impl=StdMat;;
        Device) bin="${NEKTAR_REDESIGN_DEVICE_BIN:-${NEKTAR_REDESIGN_BIN:-}}"; impl=SumFacTOP;;
        *) echo 'Use --exec-space Serial|AVX|Device' >&2; exit 2;;
    esac
    [[ -n "$bin" ]] || { echo 'Set NEKTAR_REDESIGN_BIN or a space-specific binary' >&2; exit 2; }
    extra=("--opExecSpace=$exec_space" "--opImpl=$impl")
    label="redesign-$formulation-$exec_space"
fi
[[ -x "$bin" ]] || { echo "Solver is not executable: $bin" >&2; exit 1; }
[[ -n "$outdir" ]] || outdir="$case_root/results/$label"
mkdir -p "$outdir"
outdir="$(cd "$outdir" && pwd)"
for force in total mainplane flap1 flap2; do
    [[ ! -e "$outdir/$force.fce" ]] || { echo "Existing force history: $outdir/$force.fce; choose a clean output directory" >&2; exit 1; }
done
launcher=()
if ((np > 1)); then
    launcher=("${MPI_LAUNCHER:-mpirun}" -np "$np")
fi
printf 'Running %s, %s ranks, %s steps in %s\n' "$label" "$np" "$steps" "$outdir"
(
    cd "$outdir"
    "${launcher[@]}" "$bin" "$case_root/mesh/eifw-2d.xml" "$case_root/session-$solver.xml" "${extra[@]}" -P "NumSteps=$steps" -v >run.log 2>run.err
)
