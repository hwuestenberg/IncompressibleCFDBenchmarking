#!/usr/bin/env python3
"""
Compare kinetic-energy dissipation rate -dE/dt for the Taylor-Green vortex
Re=1600 validation benchmark (see ../README.md) across:
  - the legacy IncNavierStokesSolver run, whose ../session-legacy.xml has
    an `Energy` filter producing a `.eny` file (Time, Kinetic energy,
    Enstrophy columns) directly;
  - the redesign solver runs, whose ../session-redesign.xml sessions
    carry the *same* `Energy` filter -- it doesn't exist in the redesign
    yet (checked directly against library/SolverCore/Filters in both this
    checkout and the sibling nektar-redesign checkout), but is kept in
    the session on the assumption it lands before this benchmark is
    executed (see ../README.md); until then the redesign leg simply will
    not run, and there is nothing for this script to fall back to;
  - the DeBonis (NASA/TM-2013-217850) reference dissipation-rate curve at
    ../reference-driakis-re1600.eny (despite the filename's extension,
    this file already contains dissipation rate directly, not energy --
    see read_reference()).

Both legs' `.eny` files have the identical format (see read_eny()), so
both are read the same way -- there is no per-solver post-processing
here, unlike a checkpoint-reconstruction approach would need.

-dE/dt is obtained by central-differencing the Kinetic-energy column, and
cross-checked against the exact identity
-dE/dt = 2*Kinvis*Enstrophy (exact for a periodic domain with no boundary
flux -- see FilterEnergy.cpp and the Kinvis/enstrophy definitions there).
A large discrepancy between the two is a sign of temporal
under-resolution or (more worryingly, given SpectralHPDealiasing is
unimplemented in the redesign -- see ../README.md) aliasing error, not
just numerical noise, so this is reported for every run rather than
silently discarded.

Usage:
    ./dissipation_rate.py --legacy-eny ../legacy-run/tgv-3d.eny \\
        --redesign-eny ../redesign-run/tgv-3d.eny \\
        --redesign-label semiimplicit-Serial --plot dissipation.png

    ./dissipation_rate.py --legacy-eny ../legacy-run/tgv-3d.eny --plot dissipation.png
        (reference + legacy only, no redesign leg)

Requires: numpy. matplotlib only if --plot is given.
"""
import argparse
import sys
from pathlib import Path

import numpy as np

REFERENCE_PATH = Path(__file__).resolve().parent.parent / "reference-driakis-re1600.eny"


def read_eny(path):
    """`Energy` filter output (identical format for legacy and redesign,
    since the redesign session uses the same filter): '# ...' comments,
    whitespace-separated Time / Kinetic energy / Enstrophy columns."""
    rows = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) != 3:
                continue
            rows.append([float(p) for p in parts])
    data = np.array(rows)
    return {"time": data[:, 0], "ke": data[:, 1], "enstrophy": data[:, 2]}


def read_reference(path=REFERENCE_PATH):
    """DeBonis reference curve: comma-decimal (European) 'time
    dissipation_rate' pairs, already -dE/dt directly (not energy)."""
    rows = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = [p.replace(",", ".") for p in line.split()]
            if len(parts) != 2:
                continue
            rows.append([float(p) for p in parts])
    data = np.array(rows)
    return {"time": data[:, 0], "dissipation_rate": data[:, 1]}


def dEdt(time, ke):
    """-dE/dt via central (numpy gradient) finite differences."""
    return -np.gradient(ke, time)


def summarize(label, series, kinvis):
    """-dE/dt vs. the exact 2*Kinvis*Enstrophy identity (periodic domain,
    no boundary flux -- see module docstring)."""
    rate = dEdt(series["time"], series["ke"])
    exact = 2.0 * kinvis * series["enstrophy"]
    peak_idx = int(np.argmax(rate))
    resid = rate - exact
    rel = np.abs(resid) / np.maximum(np.abs(exact), 1e-12)
    print(f"== {label} ==")
    print(f"   {len(series['time'])} samples, t in "
          f"[{series['time'][0]:.4f}, {series['time'][-1]:.4f}]")
    print(f"   peak -dE/dt = {rate[peak_idx]:.6e} at t = {series['time'][peak_idx]:.4f}")
    print(f"   -dE/dt vs. 2*Kinvis*Enstrophy: max rel. discrepancy "
          f"{np.max(rel):.3%}, median {np.median(rel):.3%}")
    return rate


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--legacy-eny", type=Path, default=None,
                    help="Legacy Energy-filter .eny output "
                         "(e.g. results/legacy/tgv-3d.eny)")
    p.add_argument("--redesign-eny", type=Path, default=None,
                    help="Redesign Energy-filter .eny output "
                         "(e.g. results/semiimplicit-Serial/tgv-3d.eny)")
    p.add_argument("--redesign-label", default="redesign",
                    help="Label for the --redesign-eny series in "
                         "output/plot (e.g. 'semiimplicit-Serial')")
    p.add_argument("--reference", type=Path, default=REFERENCE_PATH)
    p.add_argument("--no-reference", action="store_true",
                    help="Skip the DeBonis reference curve")
    p.add_argument("--Re", type=float, default=1600.0, dest="Re")
    p.add_argument("--plot", type=Path, default=None)
    args = p.parse_args()

    kinvis = 1.0 / args.Re

    if not args.legacy_eny and not args.redesign_eny:
        print("Nothing to do: pass --legacy-eny and/or --redesign-eny",
              file=sys.stderr)
        sys.exit(1)

    results = {}

    if args.legacy_eny:
        legacy = read_eny(args.legacy_eny)
        results["legacy"] = (legacy, summarize("legacy", legacy, kinvis))

    if args.redesign_eny:
        redesign = read_eny(args.redesign_eny)
        results[args.redesign_label] = (
            redesign, summarize(args.redesign_label, redesign, kinvis))

    reference = None
    if not args.no_reference:
        reference = read_reference(args.reference)
        peak_idx = int(np.argmax(reference["dissipation_rate"]))
        print(f"== reference (DeBonis, NASA/TM-2013-217850) ==")
        print(f"   peak -dE/dt = {reference['dissipation_rate'][peak_idx]:.6e} "
              f"at t = {reference['time'][peak_idx]:.4f}")

    if args.plot:
        import matplotlib.pyplot as plt
        fig, ax = plt.subplots(figsize=(7, 5))
        if reference is not None:
            ax.plot(reference["time"], reference["dissipation_rate"], "k-",
                    label="DeBonis DNS reference", linewidth=2)
        for label, (series, rate) in results.items():
            ax.plot(series["time"], rate, "o-", markersize=3, label=label)
        ax.set_xlabel("t")
        ax.set_ylabel("-dE/dt")
        ax.set_title(f"Taylor-Green vortex, Re={args.Re:.0f}: "
                      "kinetic-energy dissipation rate")
        ax.legend()
        fig.tight_layout()
        fig.savefig(args.plot, dpi=150)
        print(f"\nWrote plot: {args.plot}")


if __name__ == "__main__":
    main()
