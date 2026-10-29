#!/usr/bin/env python3
"""
Post-process AeroForces filter output (.fce files) from the 3D cylinder
mode-B wake-instability validation benchmark: compute mean Cd, Cl
statistics, and the Strouhal number (via FFT of the lift signal), for one
or more runs, and compare them against each other.

Column layout is read from each file's own header rather than assumed,
since the 3D case has extra spanwise force/moment columns that the 2D
case does not.

Usage:
    ./compare_forces.py results/*/DragLift.fce --span-length 4.0
    ./compare_forces.py results/*/DragLift.fce --span-length 4.0 --plot comparison.png

See ../README.md for the Re=300 caveats -- no single precise Cd/St target
was pinned down for this case when it was prepared (unlike the 2D case,
see ../../cylinder-2d/README.md), so this script has no literature table
to compare against; treat that as "no target available", not as "target
is unknown/wrong".
"""
import argparse
import sys
from pathlib import Path

import numpy as np


def read_fce(path):
    """Parse a Nektar++ AeroForces .fce file into (columns, data)."""
    header_cols = None
    rows = []
    with open(path) as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            if line.startswith("#"):
                stripped = line.lstrip("#").split()
                if stripped and stripped[0] == "Time":
                    header_cols = stripped
                continue
            rows.append([float(x) for x in line.split()])
    if header_cols is None:
        raise ValueError(f"{path}: could not find column header row")
    data = np.array(rows)
    if data.shape[1] != len(header_cols):
        raise ValueError(
            f"{path}: {data.shape[1]} data columns but "
            f"{len(header_cols)} header columns ({header_cols})"
        )
    return header_cols, data


def strouhal_from_fft(time, signal):
    """Dominant frequency of `signal` sampled at (assumed uniform) `time`."""
    dt = np.median(np.diff(time))
    n = len(signal)
    windowed = (signal - signal.mean()) * np.hanning(n)
    spectrum = np.abs(np.fft.rfft(windowed))
    freqs = np.fft.rfftfreq(n, d=dt)
    # Ignore the zero-frequency bin.
    peak = np.argmax(spectrum[1:]) + 1
    return freqs[peak]


def analyse(path, transient_time, span_length, rho, U, D):
    cols, data = read_fce(path)
    time = data[:, cols.index("Time")]
    f1 = data[:, cols.index("F1-total")]
    f2 = data[:, cols.index("F2-total")]

    if transient_time is None:
        transient_time = 0.5 * (time[-1] - time[0]) + time[0]
    mask = time >= transient_time
    if mask.sum() < 10:
        raise ValueError(
            f"{path}: fewer than 10 samples after transient_time="
            f"{transient_time} (total range {time[0]}..{time[-1]})"
        )

    t, fx, fy = time[mask], f1[mask], f2[mask]
    fx = fx / span_length
    fy = fy / span_length

    coeff = 2.0 / (rho * U**2 * D)
    cd = fx * coeff
    cl = fy * coeff
    st = strouhal_from_fft(t, cl) * D / U

    return {
        "file": str(path),
        "n_samples": int(mask.sum()),
        "sample_window": (float(t[0]), float(t[-1])),
        "Cd_mean": float(cd.mean()),
        "Cd_std": float(cd.std()),
        "Cl_mean": float(cl.mean()),
        "Cl_amp": float((cl.max() - cl.min()) / 2.0),
        "St": float(st),
    }


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("files", nargs="+", type=Path, help=".fce files to analyse")
    p.add_argument("--transient-time", type=float, default=None,
                    help="Discard samples before this time (default: "
                         "second half of each file's own time range)")
    p.add_argument("--span-length", type=float, required=True,
                    help="Spanwise length Lz -- divides forces by span to "
                         "get per-unit-span coefficients (match the Lz "
                         "PARAMETER in session-legacy.xml / "
                         "session-redesign.xml, or ../mesh/build_mesh.sh's "
                         "LZ override if you changed it)")
    p.add_argument("--rho", type=float, default=1.0)
    p.add_argument("--U", type=float, default=1.0)
    p.add_argument("--D", type=float, default=1.0)
    p.add_argument("--plot", type=Path, default=None,
                    help="Save a Cl(t) comparison plot to this path")
    args = p.parse_args()

    results = []
    for f in args.files:
        try:
            results.append(analyse(f, args.transient_time, args.span_length,
                                    args.rho, args.U, args.D))
        except Exception as exc:  # noqa: BLE001
            print(f"SKIP {f}: {exc}", file=sys.stderr)

    if not results:
        print("No files could be analysed.", file=sys.stderr)
        sys.exit(1)

    name_w = max(len(r["file"]) for r in results)
    header = f"{'file':<{name_w}}  {'Cd_mean':>8}  {'Cl_amp':>8}  {'St':>8}  n_samples"
    print(header)
    print("-" * len(header))
    for r in results:
        print(f"{r['file']:<{name_w}}  {r['Cd_mean']:8.4f}  "
              f"{r['Cl_amp']:8.4f}  {r['St']:8.4f}  {r['n_samples']}")

    print("\nNo literature target on file for this Re=300 3D case -- "
          "compare runs against each other / the legacy reference, and "
          "against whatever DNS reference you pin down (see ../README.md).")

    if args.plot:
        import matplotlib.pyplot as plt
        fig, ax = plt.subplots(figsize=(9, 4))
        for f in args.files:
            try:
                cols, data = read_fce(f)
            except Exception:
                continue
            time = data[:, cols.index("Time")]
            f2 = data[:, cols.index("F2-total")]
            ax.plot(time, f2, label=str(f), lw=0.8)
        ax.set_xlabel("Time")
        ax.set_ylabel("F2-total (lift)")
        ax.legend(fontsize="small")
        fig.tight_layout()
        fig.savefig(args.plot, dpi=150)
        print(f"\nWrote plot: {args.plot}")


if __name__ == "__main__":
    main()
