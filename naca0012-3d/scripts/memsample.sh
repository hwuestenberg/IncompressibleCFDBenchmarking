#!/bin/bash
# Sample the memory of the solver processes running in one run directory, and the host load.
#
#   scripts/memsample.sh OUTFILE RUNDIR [--gpu N]
#
# Every 2 s appends: epoch load1 nproc total_RSS_GB max_rank_RSS_GB [GPU N VRAM used GB]
# for this user's processes named IncNavierStokes* (the kernel truncates both solver names
# to "IncNavierStokes") whose cwd is RUNDIR. VRAM is the whole device's usage (rocm-smi),
# so it includes anything else running on that GPU. Runs until killed (run_leg.sh does).
out=$1; dir=$(realpath "$2"); gpu=""
[ "${3:-}" = "--gpu" ] && gpu=$4
echo "# epoch load1 nproc total_RSS_GB max_rank_RSS_GB${gpu:+ vram_GB(GPU$gpu)}" > "$out"
while true; do
    tot=0; n=0; mx=0
    for p in $(pgrep -u "$(id -u)" IncNavierStokes); do
        [ "$(readlink /proc/$p/cwd 2>/dev/null)" = "$dir" ] || continue
        r=$(awk '/^VmRSS/{print $2}' /proc/$p/status 2>/dev/null)
        [ -z "$r" ] && continue
        tot=$((tot + r)); n=$((n + 1)); [ "$r" -gt "$mx" ] && mx=$r
    done
    v=""
    if [ -n "$gpu" ]; then
        v=$(rocm-smi -d "$gpu" --showmeminfo vram 2>/dev/null | awk -F': ' '/Total Used Memory/{printf " %.2f", $NF/1073741824}')
    fi
    echo "$(date +%s) $(cut -d' ' -f1 /proc/loadavg) $n $(awk -v t=$tot 'BEGIN{printf "%.2f", t/1048576}') $(awk -v t=$mx 'BEGIN{printf "%.2f", t/1048576}')$v" >> "$out"
    sleep 2
done
