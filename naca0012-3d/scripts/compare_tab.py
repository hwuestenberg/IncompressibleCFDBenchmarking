#!/usr/bin/env python3
"""Tabulate legacy vs redesign diagnostics of one 3D NACA0012 comparison.

    compare_tab.py LEGACY_RUN_DIR REDESIGN_RUN_DIR [--windows a:b,c:d] [--steps 0,1,2,...]

Reads both run directories written by scripts/run_leg.sh and matches every
record by its *time* (never by file index):
  forces-{all,wing,nose,te}.fce   AeroForces, freestream frame (F1 drag, F2 lift, F3 span)
  energy.eny                      volume-averaged kinetic energy and enstrophy
  mean.avg                        domain averages of u, v, w, p
  history.his                     36 configured history points
  run.log                         per-step wall time (run_leg.sh timestamps), CFL, CG/GMRES iterations
Both codes' table formats are accepted (legacy: '#'-commented header and no Point
column in .his; redesign: plain 'Time ...' header row and a Point column).

"""
import glob
import math
import os
import re
import sys
from statistics import mean, pstdev

# ----------------------------------------------------------------------------- parsing


def is_float(tok):
    try:
        float(tok)
        return True
    except ValueError:
        return False


def read_table(path):
    """Numeric rows of a whitespace table; header and comment lines skipped."""
    rows = []
    if not os.path.exists(path):
        return rows
    with open(path, errors="replace") as f:
        for line in f:
            tok = line.split()
            if not tok or not is_float(tok[0]):
                continue
            rows.append([float(x) for x in tok])
    return rows


def key(t):
    """Time key for matching records of the two codes."""
    return round(t, 8)


def by_time(rows):
    return {key(r[0]): r[1:] for r in rows}


FCE_COLS = ["F1-press", "F1-visc", "F1-total", "F2-press", "F2-visc", "F2-total",
            "F3-press", "F3-visc", "F3-total", "M1-press", "M1-visc", "M1-total",
            "M2-press", "M2-visc", "M2-total", "M3-press", "M3-visc", "M3-total"]


def read_history(path):
    """{time key: [[values of point 0], [point 1], ...]} and the variable names."""
    data, names, npts = {}, [], 0
    if not os.path.exists(path):
        return data, names
    with open(path, errors="replace") as f:
        lines = f.readlines()
    has_point_col = False
    for line in lines:
        s = line.strip()
        m = re.match(r"#\s*History data for variables:?\s*\(?:?\s*(.*)", s)
        if m:
            txt = m.group(1).replace(") at points:", "")
            names = [n for n in re.split(r"[\s,]+", txt) if n]
        elif s.startswith("Time Point"):
            has_point_col = True
            names = s.split()[2:]
        elif re.match(r"#\s*(Point\s+)?\d+\s+\S+\s+\S+\s+\S+$", s):
            npts += 1
    for line in lines:
        tok = line.split()
        if not tok or not is_float(tok[0]):
            continue
        t = key(float(tok[0]))
        if has_point_col:
            p, vals = int(float(tok[1])), [float(x) for x in tok[2:]]
        else:
            p, vals = None, [float(x) for x in tok[1:]]
        lst = data.setdefault(t, [])
        if p is None:
            lst.append(vals)
        else:
            while len(lst) <= p:
                lst.append(None)
            lst[p] = vals
    return data, names


def read_log(path):
    """Per-step records from run.log: wall time stamp, CFL, linear-solver iterations."""
    steps, cur = [], {"solves": []}
    pre = None
    if not os.path.exists(path):
        return steps, pre
    with open(path, errors="replace") as f:
        for line in f:
            tok = line.split(None, 1)
            if len(tok) < 2 or not is_float(tok[0]):
                continue
            stamp, text = float(tok[0]), tok[1]
            m = re.match(r"Steps:\s*(\d+)\s+Time:\s*(\S+)(?:.*CPU Time:\s*([0-9.eE+-]+)s)?", text)
            if m:
                # legacy prints no variable name: one pressure solve, then u, v, w
                sv = cur["solves"]
                if len(sv) == 4 and all("[" not in n for n, _ in sv):
                    cur["solves"] = [(f"{n}[{v}]", i) for (n, i), v in zip(sv, "puvw")]
                cur.update(step=int(m.group(1)), time=float(m.group(2)), stamp=stamp,
                           cpu=float(m.group(3)) if m.group(3) else None)
                steps.append(cur)
                cur = {"solves": []}
                continue
            m = re.match(r'Writing: "[^"]*" \(([0-9.eE+-]+)s', text)
            if m:  # file output (checkpoints, statistics) is excluded from the step cost
                cur["io"] = cur.get("io", 0.0) + float(m.group(1))
                continue
            m = re.match(r"CFL:\s*([0-9.eE+-]+)", text)
            if m and steps:
                steps[-1]["cfl"] = float(m.group(1))
                continue
            m = re.search(r"(?:(\S+)\s+components = \[([^\]]*)\]|(Flexible )?(GMRES|CG))\s*iterations made = (\d+)", text)
            if m:
                if m.group(1):
                    name = m.group(1) + "[" + m.group(2).replace(" ", "") + "]"
                else:
                    name = m.group(4)
                cur["solves"].append((name, int(m.group(5))))
                continue
            if pre is None and ("Initial Conditions" in text or "Steps:" in text):
                pre = stamp
    return steps, pre


# ----------------------------------------------------------------------------- output helpers


def fmt(x, w=12, p=5):
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return " " * (w - 3) + "n/a"
    return f"{x:{w}.{p}e}"


def rel(a, b):
    return (b - a) / abs(a) if a not in (0.0, None) else float("nan")


def stats_table(title, L, R, cols, windows):
    """L, R: {time: [values]}. Window stats over common times, by step index."""
    common = sorted(set(L) & set(R))
    print(f"\n### {title}: legacy {len(L)} records, redesign {len(R)} records, {len(common)} common")
    if not common:
        return
    for (a, b) in windows:
        ts = common[a:b]
        if len(ts) < 1:
            continue
        print(f"  window records {a}..{a + len(ts) - 1}  (t = {ts[0]:.6g} .. {ts[-1]:.6g})")
        print(f"    {'quantity':10s} {'legacy mean':>13s} {'redesign mean':>13s} {'rel.diff':>10s}"
              f" {'std L':>11s} {'std R':>11s} {'max|R-L|':>11s}")
        for c, name in cols:
            l = [L[t][c] for t in ts]
            r = [R[t][c] for t in ts]
            ml, mr = mean(l), mean(r)
            md = max(abs(x - y) for x, y in zip(l, r))
            print(f"    {name:10s} {ml:13.6e} {mr:13.6e} {rel(ml, mr):+10.2e}"
                  f" {pstdev(l):11.3e} {pstdev(r):11.3e} {md:11.3e}")


def pointwise(title, L, R, cols, steps):
    common = sorted(set(L) & set(R))
    if not common:
        return
    print(f"\n### {title}: values at selected records (legacy | redesign)")
    print("   rec          t | " + " ".join(f"{n:>11s}" for _, n in cols) + " | " +
          " ".join(f"{n:>11s}" for _, n in cols))
    for i in steps:
        if i < len(common):
            t = common[i]
            print(f"  {i:4d} {t:10.4e} | " + " ".join(fmt(L[t][c], 11, 4) for c, _ in cols) +
                  " | " + " ".join(fmt(R[t][c], 11, 4) for c, _ in cols))


def perf(label, steps, skip):
    st = [s for s in steps if s["step"] > skip]
    print(f"  {label}: {len(steps)} steps logged", end="")
    if len(steps) < 2:
        print()
        return
    # wall time between consecutive "Steps:" lines minus the file output written in between
    dt = [b["stamp"] - a["stamp"] - b.get("io", 0.0) for a, b in zip(steps, steps[1:]) if b["step"] > skip]
    io = sum(s.get("io", 0.0) for s in steps[1:])
    cfl = [s["cfl"] for s in steps if "cfl" in s]
    print(f"; wall/step (steps>{skip}) mean {mean(dt) if dt else float('nan'):.3f} s"
          f" min {min(dt) if dt else float('nan'):.3f} max {max(dt) if dt else float('nan'):.3f}"
          f" (file output {io:.1f} s excluded)")
    if cfl:
        print(f"    CFL first {cfl[0]:.4g} last {cfl[-1]:.4g} max {max(cfl):.4g}")
    names = []
    for s in st:
        for n, _ in s["solves"]:
            if n not in names:
                names.append(n)
    for n in names:
        its = [sum(i for m, i in s["solves"] if m == n) for s in st]
        cnt = [sum(1 for m, _ in s["solves"] if m == n) for s in st]
        if its:
            print(f"    {n:28s} solves/step {mean(cnt):4.1f}  iterations/step mean {mean(its):8.1f}"
                  f" min {min(its)} max {max(its)}")


def default_windows(n):
    """Record windows: the start-up (records 0-4, where the IMEXdirk and Euler start-up
    kicks differ), everything from record 5 on, and for long runs the second half."""
    w = [(0, min(n, 5))]
    if n > 5:
        w.append((5, n))
    if n > 40:
        w.append((n // 2, n))
    return w


def outputs(ldir, rdir):
    """Checkpoints and statistics files of both legs, paired by their Time metadata."""
    try:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import fld_times
    except ImportError:
        return
    print("\n### output files paired by Time metadata (indices differ between the codes)")
    for pat in ("chk_*.chk", "stats_*_stress.fld"):
        tl = {}
        for lab, d in (("L", ldir), ("R", rdir)):
            for p in sorted(glob.glob(os.path.join(d, pat))):
                t, f = fld_times.info(p)
                if t is not None:
                    tl.setdefault(round(t, 6), {})[lab] = (os.path.basename(p), ",".join(f))
        for t in sorted(tl):
            l, r = tl[t].get("L", ("-", "")), tl[t].get("R", ("-", ""))
            print(f"  t={t:<10.6g} legacy {l[0]:22s} [{l[1]}]  redesign {r[0]:22s} [{r[1]}]")


# ----------------------------------------------------------------------------- main


def main():
    args = sys.argv[1:]
    windows = None
    sel = [0, 1, 2, 3, 5, 10, 20, 50, 100, 200, 500, 1000]
    if "--windows" in args:
        i = args.index("--windows")
        windows = [tuple(int(x) for x in w.split(":")) for w in args[i + 1].split(",")]
        del args[i:i + 2]
    if "--steps" in args:
        i = args.index("--steps")
        sel = [int(x) for x in args[i + 1].split(",")]
        del args[i:i + 2]
    ldir, rdir = args[0], args[1]
    print(f"legacy:   {ldir}\nredesign: {rdir}")

    for d in (ldir, rdir):
        meta = os.path.join(d, "run.meta")
        if os.path.exists(meta):
            m = dict(l.rstrip("\n").split(" ", 1) for l in open(meta) if " " in l)
            print(f"  {os.path.basename(d)}: host {m.get('host')} exit {m.get('exit')} wall {m.get('wall')} s"
                  f" load before [{m.get('load_before')}] after [{m.get('load_after')}]")
            mem = [f"{k} {m[k]}" for k in ("peak_rss_total_GB", "peak_rss_rank_GB", "peak_vram_GB",
                                            "load1_during") if k in m]
            if mem:
                print("    " + "; ".join(mem))
            if "bin" in m:
                print(f"    bin {m['bin']}")

    # Forces
    for name in ("all", "wing", "nose", "te"):
        L = by_time(read_table(os.path.join(ldir, f"forces-{name}.fce")))
        R = by_time(read_table(os.path.join(rdir, f"forces-{name}.fce")))
        n = len(set(L) & set(R))
        win = windows or default_windows(n)
        if name == "all":
            pointwise("forces-all (F1=drag, F2=lift, F3=span; total)", L, R,
                      [(2, "drag"), (5, "lift"), (8, "side"), (17, "M3")], sel)
        if name == "all":  # every component; the per-surface files: totals only
            cols = [(i, c) for i, c in enumerate(FCE_COLS) if c.startswith(("F1", "F2", "F3")) or c == "M3-total"]
        else:
            cols = [(i, c) for i, c in enumerate(FCE_COLS) if c in ("F1-total", "F2-total", "F3-total", "M3-total")]
        stats_table(f"forces-{name}", L, R, cols, win)

    # Energy and means
    L = by_time(read_table(os.path.join(ldir, "energy.eny")))
    R = by_time(read_table(os.path.join(rdir, "energy.eny")))
    n = len(set(L) & set(R))
    stats_table("energy", L, R, [(0, "kinetic"), (1, "enstrophy")], windows or default_windows(n))
    L = by_time(read_table(os.path.join(ldir, "mean.avg")))
    R = by_time(read_table(os.path.join(rdir, "mean.avg")))
    n = len(set(L) & set(R))
    stats_table("mean (domain averages)", L, R, [(0, "u"), (1, "v"), (2, "w"), (3, "p")],
                windows or default_windows(n))

    # History points
    HL, nl = read_history(os.path.join(ldir, "history.his"))
    HR, nr = read_history(os.path.join(rdir, "history.his"))
    common = sorted(set(HL) & set(HR))
    print(f"\n### history.his: variables legacy {nl} redesign {nr}; {len(common)} common times")
    if common:
        npts = min(len(HL[common[0]]), len(HR[common[0]]))
        nv = min(len(nl), len(nr)) if nl and nr else len(HL[common[0]][0])
        vn = (nl or nr or ["v%d" % i for i in range(nv)])[:nv]
        print("   pt  max|R-L| over common times (" + ",".join(vn) + ")  |  final legacy  |  final redesign")
        for p in range(npts):
            md = [max(abs(HR[t][p][v] - HL[t][p][v]) for t in common) for v in range(nv)]
            fl = HL[common[-1]][p][:nv]
            fr = HR[common[-1]][p][:nv]
            print(f"   {p:2d} " + " ".join(f"{x:9.2e}" for x in md) + "  | " +
                  " ".join(f"{x:9.5f}" for x in fl) + " | " + " ".join(f"{x:9.5f}" for x in fr))
        if npts > 17:
            for lab, H in (("legacy", HL), ("redesign", HR)):
                d = max(abs(H[t][14][v] - H[t][17][v]) for t in common for v in range(nv))
                print(f"   periodicity check ({lab}): max |pt14(z=1e-6) - pt17(z=0.2-1e-6)| = {d:.2e}")

    outputs(ldir, rdir)

    # Performance
    print("\n### performance (run.log timestamps; steps 1-2 excluded when more than 5 steps;"
          " SMOKE data unless the run is long)")
    for lab, d in (("legacy", ldir), ("redesign", rdir)):
        steps, _ = read_log(os.path.join(d, "run.log"))
        perf(lab, steps, 2 if len(steps) > 5 else 0)


if __name__ == "__main__":
    main()
