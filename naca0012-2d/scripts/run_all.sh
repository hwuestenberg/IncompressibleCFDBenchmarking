#!/usr/bin/env bash
#
# Drive the validation matrix: legacy (reference) + redesign semiimplicit
# x {Serial, AVX, Device}. See ../README.md for the case and run_case.sh for
# the single-run logic (and its --impl/--np/--steps options).
#
# Skips any leg whose NEKTAR_*_BIN variable is not set, so run whatever
# subset you have builds for on a given machine. Extra arguments (e.g.
# --steps 100) are passed through to every run_case.sh call.
#
# Usage:
#   source env.sh
#   ./run_all.sh [--steps N]

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -n "${NEKTAR_LEGACY_BIN:-}" ]; then
    "$HERE/run_case.sh" --solver legacy "$@"
else
    echo "-- skipping legacy (NEKTAR_LEGACY_BIN not set)"
fi

for exec_space in Serial AVX Device; do
    case "$exec_space" in
        Serial) configured="${NEKTAR_REDESIGN_SERIAL_BIN:-${NEKTAR_REDESIGN_BIN:-}}" ;;
        AVX)    configured="${NEKTAR_REDESIGN_AVX_BIN:-${NEKTAR_REDESIGN_BIN:-}}" ;;
        Device) configured="${NEKTAR_REDESIGN_DEVICE_BIN:-}" ;;
    esac
    if [ -n "$configured" ]; then
        "$HERE/run_case.sh" --solver semiimplicit --exec-space "$exec_space" "$@"
    else
        echo "-- skipping semiimplicit/$exec_space (binary not set)"
    fi
done

echo "########## all requested runs complete ##########"
