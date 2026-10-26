#!/usr/bin/env python3
"""
Compute mean-velocity and Reynolds-stress profiles U+(y+), R_ij+(y+) from
a Nektar++ `ReynoldsStresses` filter's time-averaged field output for the
channel-flow validation benchmark, and compare against the Moser, Kim &
Mansour (1999) DNS reference data in DNS_MOSER_DIR/chan180/.

Both session-legacy.xml and session-redesign.xml carry the
`ReynoldsStresses` filter (see ../README.md -- it doesn't exist in the
redesign yet, but is kept on the assumption it lands before this
benchmark is executed there, the same policy as HOPBC/AeroForces
elsewhere in this suite). That filter already does the *temporal*
averaging during the run, accumulating true running covariances
`overline{u_i' u_j'}` (see
solvers/IncNavierStokesSolver/Filters/FilterReynoldsStresses.cpp) into a
single field file with variables u,v,w,p,uu,uv,uw,vv,vw,ww -- the mean
velocity and all 6 independent Reynolds-stress components, all already
time-averaged over the run.

What's NOT done by that filter, and genuinely can't be done by any
filter on this mesh: reducing that full 3D field to a 1D y-profile. This
benchmark's mesh is a genuine 3D unstructured mesh (no homogeneous/
Fourier direction to average over the way a quasi-3D mesh would allow --
see ../README.md), so *some* spatial (x,z) averaging step is
unavoidable. This script does exactly that and nothing more: ONE
`FieldConvert -m interppoints` call samples the filter's single
time-averaged output onto a structured (x,y,z) grid, and the resulting
values are pooled over (x,z) at each wall-normal distance -- no temporal
averaging or per-sample fluctuation computation happens here, since the
filter already provides genuinely time-averaged quantities.

Pipeline:
  1. FieldConvert -m interppoints:box=... samples u,v,w,p,uu,uv,uw,vv,vw,ww
     from the ReynoldsStresses filter's final output file onto a
     structured (x,y,z) grid covering the whole domain.
  2. Points are folded about the channel centreline (y -> min(y, Ly-y))
     to exploit the two-wall statistical symmetry, pooled with all other
     (x,z) samples at that wall-normal distance, and reduced to mean(y)
     and Reynolds-stress(y) profiles by plain spatial averaging.
  3. Profiles are converted to wall units (y+, U+, R_ij+) using the
     session's prescribed Re_tau/utau (exact for this benchmark's
     constant-body-force forcing -- see ../README.md) and compared
     against the Moser DNS profiles.

Usage:
    ./profile_stats.py --xml ../channel3d.xml \\
        --reystress-fld results/legacy/reystress_stress.fld \\
        --box 8,33,8 --plot profile.png

Requires: numpy. matplotlib only if --plot is given. Needs NEKTAR_FIELDCONVERT_BIN
set (see ../scripts/env.sh.example).
"""
import argparse
import csv
import os
import subprocess
import sys
from pathlib import Path

import numpy as np

DNS_DIR = Path(os.environ["DNS_MOSER_DIR"]) / "chan180" / "profiles" if os.environ.get("DNS_MOSER_DIR") else None


def read_dns_profile(path, ncols):
    rows = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) != ncols:
                continue
            rows.append([float(p) for p in parts])
    return np.array(rows)


def load_dns_reference():
    if DNS_DIR is None:
        raise ValueError("Set DNS_MOSER_DIR to the directory containing chan180")
    means = read_dns_profile(DNS_DIR / "chan180.means", 7)
    reystress = read_dns_profile(DNS_DIR / "chan180.reystress", 8)
    return {
        "y": means[:, 0], "yplus": means[:, 1], "Uplus": means[:, 2],
        "Ruu": reystress[:, 2], "Rvv": reystress[:, 3], "Rww": reystress[:, 4],
        "Ruv": reystress[:, 5],
    }


def run_interppoints(fieldconvert_bin, xml, fld, box, out_csv):
    if out_csv.exists():
        return out_csv
    cmd = [
        fieldconvert_bin, "-f", "-e",
        f"-m", f"interppoints:box={box}:fromxml={xml}:fromfld={fld}",
        str(out_csv),
    ]
    subprocess.run(cmd, check=True)
    return out_csv


def read_points_csv(path):
    with open(path) as f:
        reader = csv.reader(f)
        header = next(reader)
        rows = [row for row in reader]
    header = [h.strip().lower() for h in header]
    data = np.array(rows, dtype=float)
    cols = {name: data[:, i] for i, name in enumerate(header)
            if name in ("x", "y", "z", "u", "v", "w", "p",
                        "uu", "uv", "uw", "vv", "vw", "ww")}
    missing = {"x", "y", "z", "u", "uu", "uv", "vv", "ww"} - set(cols)
    if missing:
        raise ValueError(f"{path}: missing expected columns {missing} "
                          f"(found {header}) -- was this file produced by "
                          f"the ReynoldsStresses filter, not a plain "
                          f"checkpoint?")
    return cols


def fold_and_pool(points, Ly):
    """Fold y about the centreline and pool all (x,z) samples by the
    folded y value (grid is structured, so folded y takes only a handful
    of distinct values up to floating-point noise -- round to merge).
    The filter has already time-averaged everything, so this is a plain
    spatial mean, not a fluctuation computation."""
    y_folded = np.minimum(points["y"], Ly - points["y"])
    y_round = np.round(y_folded, 8)
    order = np.argsort(y_round)
    y_sorted = y_round[order]

    fields = {name: points[name][order] for name in ("u", "uu", "uv", "vv", "ww")}

    unique_y, start_idx = np.unique(y_sorted, return_index=True)
    start_idx = list(start_idx) + [len(y_sorted)]

    profile = {"y": unique_y, "U": np.zeros(len(unique_y)),
               "Ruu": np.zeros(len(unique_y)), "Ruv": np.zeros(len(unique_y)),
               "Rvv": np.zeros(len(unique_y)), "Rww": np.zeros(len(unique_y))}

    for i in range(len(unique_y)):
        s, e = start_idx[i], start_idx[i + 1]
        profile["U"][i] = fields["u"][s:e].mean()
        profile["Ruu"][i] = fields["uu"][s:e].mean()
        profile["Ruv"][i] = fields["uv"][s:e].mean()
        profile["Rvv"][i] = fields["vv"][s:e].mean()
        profile["Rww"][i] = fields["ww"][s:e].mean()

    return profile


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--xml", required=True, type=Path,
                    help="Mesh xml (channel3d.xml)")
    p.add_argument("--reystress-fld", required=True, type=Path,
                    help="ReynoldsStresses filter's final time-averaged "
                         "output (e.g. results/legacy/reystress_stress.fld "
                         "-- the '_stress' suffix and final-dump naming "
                         "come from FilterReynoldsStresses::v_GetFileSuffix "
                         "and the OutputFile='reystress' PARAM in the "
                         "session's FILTERS block)")
    p.add_argument("--box", default="8,33,8",
                    help="interppoints structured-grid resolution N1,N2,N3 "
                         "in x,y,z (default 8,33,8 -- N2 should resolve the "
                         "wall-normal grading reasonably, e.g. odd so a "
                         "point falls near the centreline)")
    p.add_argument("--Lx", type=float, default=6.0)
    p.add_argument("--Ly", type=float, default=2.0)
    p.add_argument("--Lz", type=float, default=3.0)
    p.add_argument("--halfheight", type=float, default=1.0)
    p.add_argument("--Re-tau", type=float, default=180.0, dest="Re_tau")
    p.add_argument("--Re-c", type=float, default=4200.0, dest="Re_c")
    p.add_argument("--workdir", type=Path, default=Path("profile_stats_work"),
                    help="Where to write the intermediate interppoints CSV")
    p.add_argument("--plot", type=Path, default=None)
    args = p.parse_args()

    fieldconvert_bin = os.environ.get("NEKTAR_FIELDCONVERT_BIN")
    if not fieldconvert_bin:
        print("Set NEKTAR_FIELDCONVERT_BIN (see scripts/env.sh.example)", file=sys.stderr)
        sys.exit(1)

    if not args.reystress_fld.exists():
        print(f"{args.reystress_fld} not found.", file=sys.stderr)
        sys.exit(1)

    args.workdir.mkdir(parents=True, exist_ok=True)
    box = f"{args.box},0,{args.Lx},0,{args.Ly},0,{args.Lz}"

    out_csv = args.workdir / f"{args.reystress_fld.stem}_sample.csv"
    run_interppoints(fieldconvert_bin, args.xml, args.reystress_fld, box, out_csv)
    points = read_points_csv(out_csv)
    profile = fold_and_pool(points, args.Ly)

    utau = args.Re_tau / args.Re_c
    yplus = profile["y"] / args.halfheight * args.Re_tau
    Uplus = profile["U"] / utau
    Ruu_plus = profile["Ruu"] / utau**2
    Rvv_plus = profile["Rvv"] / utau**2

    dns = load_dns_reference()

    print(f"{'y+':>10} {'U+':>10} {'DNS U+':>10} {'Ruu+':>10} "
          f"{'DNS Ruu+':>10} {'Rvv+':>10} {'DNS Rvv+':>10}")
    for i in range(len(yplus)):
        dns_U = np.interp(yplus[i], dns["yplus"], dns["Uplus"])
        dns_Ruu = np.interp(yplus[i], dns["yplus"], dns["Ruu"])
        dns_Rvv = np.interp(yplus[i], dns["yplus"], dns["Rvv"])
        print(f"{yplus[i]:10.3f} {Uplus[i]:10.3f} {dns_U:10.3f} "
              f"{Ruu_plus[i]:10.4f} {dns_Ruu:10.4f} "
              f"{Rvv_plus[i]:10.4f} {dns_Rvv:10.4f}")

    if args.plot:
        import matplotlib.pyplot as plt
        fig, axes = plt.subplots(1, 2, figsize=(11, 4.5))
        axes[0].semilogx(dns["yplus"], dns["Uplus"], "k-", label="Moser DNS")
        axes[0].semilogx(yplus, Uplus, "o", label="this run")
        axes[0].set_xlabel("y+"); axes[0].set_ylabel("U+"); axes[0].legend()
        axes[0].set_title("Mean velocity")

        axes[1].plot(dns["yplus"], dns["Ruu"], "k-", label="Moser R_uu+")
        axes[1].plot(dns["yplus"], dns["Rvv"], "k--", label="Moser R_vv+")
        axes[1].plot(yplus, Ruu_plus, "o", label="this run R_uu+")
        axes[1].plot(yplus, Rvv_plus, "s", label="this run R_vv+")
        axes[1].set_xlabel("y+"); axes[1].set_ylabel("R_ij+"); axes[1].legend()
        axes[1].set_title("Reynolds stresses")

        fig.tight_layout()
        fig.savefig(args.plot, dpi=150)
        print(f"\nWrote plot: {args.plot}")


if __name__ == "__main__":
    main()
