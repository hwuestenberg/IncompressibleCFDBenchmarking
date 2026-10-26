#!/usr/bin/env bash
#
# Drive the full validation matrix: legacy (reference) + redesign x
# semiimplicit x {Serial, AVX, Device}. See ../README.md
# for the overall benchmark and run_case.sh for the underlying single-run
# logic.
#
# Skips redesign spaces without a configured binary, rather than failing -- run whatever subset of the matrix you
# have builds for on a given machine (e.g. AVX-only on a workstation,
# Device-only on a GPU node).
#
# Usage:
#   source env.sh
#   ./run_all.sh

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
np="${MPI_NP:-1}"
while (($#)); do
    case "$1" in
        --np) np="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
done
[[ "$np" =~ ^[1-9][0-9]*$ ]] || { echo "--np must be a positive integer" >&2; exit 2; }

if [ -n "${NEKTAR_LEGACY_BIN:-}" ]; then
    "$HERE/run_case.sh" --solver legacy --np "$np"
else
    echo "-- skipping legacy (NEKTAR_LEGACY_BIN not set)"
fi

for formulation in semiimplicit; do
    for exec_space in Serial AVX Device; do
        case "$exec_space" in
            Serial) configured="${NEKTAR_REDESIGN_SERIAL_BIN:-${NEKTAR_REDESIGN_BIN:-}}" ;;
            AVX)    configured="${NEKTAR_REDESIGN_AVX_BIN:-${NEKTAR_REDESIGN_BIN:-}}" ;;
            Device) configured="${NEKTAR_REDESIGN_DEVICE_BIN:-}" ;;
        esac
        if [ -n "$configured" ]; then
            "$HERE/run_case.sh" --solver "$formulation" --exec-space "$exec_space" --np "$np"
        else
            echo "-- skipping $formulation/$exec_space (binary not set)"
        fi
    done
done

echo "########## all requested runs complete ##########"
echo "Post-process with: ./compare_forces.py results/*/DragLift.fce --span-length 4.0"
