#!/bin/bash
# Run one leg (one code, one configuration) of the 3D NACA0012 comparison.
#
#   scripts/run_leg.sh CODE PAIR OUTDIR [options] [-- extra solver args]
#
#   CODE    legacy | redesign
#   PAIR    semi                 -> session-<CODE>.xml
#   OUTDIR  run directory (created; mesh is symlinked into it, so the
#           legacy mesh partition dir <mesh>_xml lands there, not in the case dir)
#
# Options:
#   --np N          MPI ranks (default: 1 for redesign Device, 16 otherwise)
#   --exec-space SPACE  redesign execution space: Device (default) | AVX | Serial
#   --impl IMPL     redesign operator implementation (default: SumFacTOP on Device, SumFac otherwise)
#                   Both are passed explicitly (--opExecSpace, --opImpl).
#   --steps N       -P NumSteps=N
#   -P k=v          extra parameter override (leaf parameters only, see README.md)
#   --ic FILE       optional restart field; without it, start from freestream.
#
# Binaries come from scripts/env.sh (NEKTAR_LEGACY_BIN, NEKTAR_REDESIGN_BIN, NEKTAR_REDESIGN_DEVICE_BIN).
# Output: OUTDIR/run.log (solver stdout+stderr, every line prefixed with the wall-clock
# epoch time in seconds, so per-step wall time = difference of consecutive "Steps:" lines),
# OUTDIR/mem.log (scripts/memsample.sh: host load, solver RSS, GPU0 VRAM on Device runs, every 2 s),
# OUTDIR/run.meta (host, binary, command, load before/after, exit code, wall time, peak memory).
set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CASE=$(dirname "$HERE")
source "$HERE/env.sh"

code=$1; pair=$2; out=$3; shift 3
[ "$pair" = semi ] || { echo "PAIR must be semi" >&2; exit 2; }
np=""; exec_space=Device; impl=""; extra=(); ic=""
while [ $# -gt 0 ]; do
    case "$1" in
        --np) np=$2; shift 2 ;;
        --exec-space|--exec) exec_space=$2; shift 2 ;;
        --impl) impl=$2; shift 2 ;;
        --steps) extra+=(-P "NumSteps=$2"); shift 2 ;;
        --ic) ic=$(realpath "$2") || exit 2; shift 2 ;;
        -P) extra+=(-P "$2"); shift 2 ;;
        --) shift; extra+=("$@"); break ;;
        *) echo "unknown option $1" >&2; exit 2 ;;
    esac
done

mesh=naca0012-3d
[ -f "$CASE/mesh/$mesh.xml" ] || { echo "missing mesh: $CASE/mesh/$mesh.xml" >&2; exit 2; }
cond=$CASE/session-$code.xml
[ -f "$cond" ] || { echo "no conditions file $cond" >&2; exit 2; }

case $code in
    legacy)
        bin=$NEKTAR_LEGACY_BIN
        np=${np:-16}
        solver=("$MPIRUN" $MPIRUN_ARGS -np "$np" "$bin")
        ;;
    redesign)
        case $exec_space in
            Device) bin=$NEKTAR_REDESIGN_DEVICE_BIN; impl=${impl:-SumFacTOP}; np=${np:-1}
                    export HIP_VISIBLE_DEVICES=0 ROCR_VISIBLE_DEVICES=0 ;;
            AVX|Serial) bin=$NEKTAR_REDESIGN_BIN; impl=${impl:-SumFac}; np=${np:-16} ;;
            *) echo "bad --exec $exec_space" >&2; exit 2 ;;
        esac
        if [ "$np" -gt 1 ]; then
            solver=("$MPIRUN" $MPIRUN_ARGS -np "$np" "$bin")
        else
            solver=("$bin")
        fi
        extra+=(--opExecSpace="$exec_space" --opImpl="$impl")
        ;;
    *) echo "CODE must be legacy or redesign" >&2; exit 2 ;;
esac
[[ "$np" =~ ^[1-9][0-9]*$ ]] || { echo "--np must be a positive integer" >&2; exit 2; }

mkdir -p "$out"; cd "$out" || exit 2
ln -sfn "$CASE/mesh/$mesh.xml" "$mesh.xml"
if [ -n "$ic" ]; then
    ln -sfn "$ic" "${mesh}_ini.fld"
    python3 - "$cond" "${mesh}_ini.fld" > conditions.xml <<'PY' || exit 2
import sys
import xml.etree.ElementTree as ET

tree = ET.parse(sys.argv[1])
initial = tree.getroot().find("./CONDITIONS/FUNCTION[@NAME='InitialConditions']")
if initial is None:
    raise SystemExit('Missing InitialConditions function')
for child in list(initial):
    initial.remove(child)
ET.SubElement(initial, 'F', {'VAR': 'u,v,w,p', 'FILE': sys.argv[2]})
tree.write(sys.stdout.buffer, encoding='utf-8', xml_declaration=True)
PY
    cond="$PWD/conditions.xml"
fi

cmd=("${solver[@]}" -v "$mesh.xml" "$cond" "${extra[@]}")
{
    echo "host $(hostname)"
    echo "start $(date -Is)"
    echo "load_before $(cut -d' ' -f1-3 /proc/loadavg)"
    echo "bin $bin"
    echo "legacy_build ${LEGACY_BUILD:-}"
    echo "ic ${ic:-freestream}"
    echo "cmd ${cmd[*]}"
} > run.meta

gpuopt=()
[ "$code" = redesign ] && [ "$exec_space" = Device ] && gpuopt=(--gpu 0)
"$HERE/memsample.sh" mem.log . "${gpuopt[@]}" &
mon=$!
start=$EPOCHREALTIME
"${cmd[@]}" 2>&1 | while IFS= read -r line; do
    printf '%s %s\n' "$EPOCHREALTIME" "$line"
done > run.log
rc=${PIPESTATUS[0]}
end=$EPOCHREALTIME
kill "$mon" 2> /dev/null
{
    echo "end $(date -Is)"
    echo "load_after $(cut -d' ' -f1-3 /proc/loadavg)"
    echo "exit $rc"
    echo "wall $(awk -v a="$start" -v b="$end" 'BEGIN{printf "%.1f", b-a}')"
    # peak over the 2 s samples: total RSS, largest rank, GPU VRAM; host load1 mean/max
    awk '!/^#/ && $3 > 0 {n++; l += $2; if ($2 > lm) lm = $2; if ($4 > t) t = $4; if ($5 > r) r = $5;
         if (NF > 5 && $6 > v) v = $6}
         END {printf "peak_rss_total_GB %.2f\npeak_rss_rank_GB %.2f\n", t, r;
              if (v > 0) printf "peak_vram_GB %.2f\n", v;
              if (n) printf "load1_during mean %.1f max %.1f (%d samples)\n", l / n, lm, n}' mem.log
} >> run.meta
exit "$rc"
