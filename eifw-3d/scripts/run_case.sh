#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case_root="$(dirname "$here")"
source_root="${IFW_3D_SOURCE:-$case_root}"
solver='' formulation='' exec_space=Serial np='' steps=200000 outdir='' prepare_only=false
while (($#)); do
    case "$1" in
        --solver) solver="$2"; shift 2;;
        --formulation) formulation="$2"; shift 2;;
        --exec-space) exec_space="$2"; shift 2;;
        --np) np="$2"; shift 2;;
        --steps) steps="$2"; shift 2;;
        --outdir) outdir="$2"; shift 2;;
        --source) source_root="$2"; shift 2;;
        --prepare-only) prepare_only=true; shift;;
        *) echo "Unknown argument: $1" >&2; exit 2;;
    esac
done
[[ "$solver" == legacy || "$solver" == redesign ]] || { echo 'Use --solver legacy|redesign' >&2; exit 2; }
[[ "$formulation" == semiimplicit ]] || { echo 'Use --formulation semiimplicit' >&2; exit 2; }
[[ "$np" =~ ^[1-9][0-9]*$ && "$steps" =~ ^[1-9][0-9]*$ ]] || { echo 'Supply positive --np N and --steps N' >&2; exit 2; }
[[ -f "$source_root/mesh/eifw-3d.xml" && -f "$source_root/restart_ctu_306.fld/Info.xml" ]] || {
    echo "Missing mesh or CTU 306 restart under $source_root" >&2; exit 1;
}
if [[ "$solver" == legacy ]]; then
    bin="${NEKTAR_LEGACY_BIN:-}"; extra=(); label="legacy-$formulation"
else
    case "$exec_space" in
        Serial) bin="${NEKTAR_REDESIGN_SERIAL_BIN:-${NEKTAR_REDESIGN_BIN:-}}" ;;
        AVX) bin="${NEKTAR_REDESIGN_AVX_BIN:-${NEKTAR_REDESIGN_BIN:-}}" ;;
        Device) bin="${NEKTAR_REDESIGN_DEVICE_BIN:-${NEKTAR_REDESIGN_BIN:-}}" ;;
        *) echo 'Use --exec-space Serial|AVX|Device' >&2; exit 2;;
    esac
    extra=("--opExecSpace=$exec_space")
    if [[ -n "${NEKTAR_OP_IMPL:-}" ]]; then extra+=("--opImpl=$NEKTAR_OP_IMPL"); fi
    label="redesign-$formulation-$exec_space"
fi
if [[ "$prepare_only" != true ]]; then
    [[ -n "$bin" && -x "$bin" ]] || { echo "Set an executable solver binary for the selected solver and execution space" >&2; exit 1; }
fi
[[ -n "$outdir" ]] || outdir="$case_root/results/$label"
mkdir -p "$outdir"
outdir="$(cd "$outdir" && pwd)"
for file in run.log run.err total.fce mainplane.fce flap1.fce flap2.fce; do
    [[ ! -e "$outdir/$file" ]] || { echo "Existing $outdir/$file; choose a clean output directory" >&2; exit 1; }
done
for item in eifw-3d.xml restart_ctu_306.fld; do
    if [[ "$item" == eifw-3d.xml ]]; then target="$(realpath "$source_root/mesh/eifw-3d.xml")";
    else target="$(realpath "$source_root/restart_ctu_306.fld")"; fi
    if [[ -L "$outdir/$item" ]]; then
        [[ "$(realpath "$outdir/$item")" == "$target" ]] || { echo "Wrong link: $outdir/$item" >&2; exit 1; }
    elif [[ -e "$outdir/$item" ]]; then
        echo "Existing non-link input: $outdir/$item" >&2; exit 1
    else
        ln -s "$target" "$outdir/$item"
    fi
done
if [[ -f "$outdir/session.xml" ]]; then
    cmp -s "$case_root/session-$solver.xml" "$outdir/session.xml" || { echo "Different session.xml already staged" >&2; exit 1; }
else
    cp "$case_root/session-$solver.xml" "$outdir/session.xml"
fi
if [[ "$prepare_only" == true ]]; then
    printf 'Prepared %s in %s\n' "$label" "$outdir"
    exit 0
fi
launcher=()
if [[ "${MPI_LAUNCHER:-mpirun}" == srun ]]; then
    launcher=(srun --ntasks="$np")
else
    launcher=("${MPI_LAUNCHER:-mpirun}" -np "$np")
fi
printf 'Running %s, %s ranks, %s steps in %s\n' "$label" "$np" "$steps" "$outdir"
(
    cd "$outdir"
    "${launcher[@]}" "$bin" eifw-3d.xml session.xml "${extra[@]}" -P "NumSteps=$steps" -v >run.log 2>run.err
)
