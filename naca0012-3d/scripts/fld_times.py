#!/usr/bin/env python3
"""Print the Time metadata (and field list) of Nektar++ .chk/.fld outputs.

    fld_times.py FILE_OR_DIR...              one line per file: time, fields, path
    fld_times.py --match LEGACY_DIR REDESIGN_DIR [GLOB]
        pair the outputs of two run dirs by Time (default GLOB: chk_*.chk), printing
        "time legacy_path redesign_path" for every common time. Checkpoint and
        statistics *indices* differ between the codes; the Time metadata does not.

Works for parallel outputs (a directory with Info.xml) and single files. Uses
<Time>, else <FinalTime> (legacy ReynoldsStresses/AverageFields files carry only
FinalTime). Times are matched to 6 decimals: the redesign writes its time metadata
with std::to_string, i.e. with 6 decimal places only.
"""
import glob
import os
import re
import sys


def head(path):
    if os.path.isdir(path):
        for name in ("Info.xml", "P0000000.fld"):
            p = os.path.join(path, name)
            if os.path.exists(p):
                with open(p, errors="replace") as f:
                    txt = f.read(65536)
                if name == "Info.xml":
                    # fields live in the partition files
                    q = os.path.join(path, "P0000000.fld")
                    if os.path.exists(q):
                        with open(q, errors="replace") as g:
                            txt += g.read(65536)
                return txt
        return ""
    with open(path, errors="replace") as f:
        return f.read(65536)


def info(path):
    txt = head(path)
    m = re.search(r"<Time>\s*([^<]+)</Time>", txt) or re.search(r"<FinalTime>\s*([^<]+)</FinalTime>", txt)
    t = float(m.group(1)) if m else None
    fields = []
    for fm in re.finditer(r'FIELDS="([^"]+)"', txt):
        for v in fm.group(1).split(","):
            if v not in fields:
                fields.append(v)
    return t, fields


def main():
    a = sys.argv[1:]
    if a and a[0] == "--match":
        pat = a[3] if len(a) > 3 else "chk_*.chk"
        L = {round(info(p)[0], 6): p for p in glob.glob(os.path.join(a[1], pat)) if info(p)[0] is not None}
        R = {round(info(p)[0], 6): p for p in glob.glob(os.path.join(a[2], pat)) if info(p)[0] is not None}
        for t in sorted(set(L) & set(R)):
            print(f"{t:.8g} {L[t]} {R[t]}")
        return
    for p in a:
        t, f = info(p)
        print(f"{t} {','.join(f)} {p}")


if __name__ == "__main__":
    main()
