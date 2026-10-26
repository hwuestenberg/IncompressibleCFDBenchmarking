#!/usr/bin/env python3
"""Compare complete legacy/redesign AeroForces histories at matching times."""
import argparse
import math
import sys
from pathlib import Path

NAMES = ('total', 'mainplane', 'flap1', 'flap2')
COLUMNS = tuple(f'F{axis}-{term}' for axis in (1, 2, 3) for term in ('press', 'visc', 'total'))


def read_force(path):
    if not path.is_file():
        raise ValueError(f'missing history: {path}')
    header = None
    rows = []
    for number, line in enumerate(path.read_text().splitlines(), 1):
        tokens = line.lstrip('#').split()
        if tokens and tokens[0] == 'Time':
            if header is not None:
                raise ValueError(f'{path}:{number}: repeated header')
            header = tokens
            if len(header) != len(set(header)) or not {'Time', *COLUMNS}.issubset(header):
                raise ValueError(f'{path}:{number}: malformed or incomplete header')
            continue
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        if header is None or len(tokens) != len(header):
            raise ValueError(f'{path}:{number}: wrong number of columns')
        try:
            numbers = [float(value) for value in tokens]
        except ValueError as exc:
            raise ValueError(f'{path}:{number}: nonnumeric value') from exc
        if not all(map(math.isfinite, numbers)):
            raise ValueError(f'{path}:{number}: nonfinite value')
        rows.append(dict(zip(header, numbers)))
    if not rows:
        raise ValueError(f'{path}: empty history')
    times = [row['Time'] for row in rows]
    if any(b <= a for a, b in zip(times, times[1:])):
        raise ValueError(f'{path}: times are not strictly increasing')
    return rows


def compare(left, right, label):
    if len(left) != len(right):
        raise ValueError(f'{label}: sample counts differ ({len(left)} vs {len(right)})')
    for i, (a, b) in enumerate(zip(left, right)):
        if not math.isclose(a['Time'], b['Time'], rel_tol=1e-9, abs_tol=1e-10):
            raise ValueError(f'{label}: time mismatch at sample {i}: {a["Time"]} vs {b["Time"]}')
    print(f'{label}: {len(left)} aligned samples, t={left[0]["Time"]:.9g}..{left[-1]["Time"]:.9g}')
    for col in COLUMNS:
        delta = max(abs(a[col]-b[col]) for a,b in zip(left,right))
        scale = max(abs(a[col]) for a in left)
        relative = delta / scale if scale else (0.0 if delta == 0 else float('inf'))
        print(f'  {col:9s} max |redesign - legacy| = {delta:.9g}; / max |legacy| = {relative:.9g}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('results', type=Path, help='Directory containing per-run output directories')
    parser.add_argument('--exec-space', choices=('Serial', 'AVX', 'Device'), default='Serial')
    args = parser.parse_args()
    try:
        # Load every history first, so a partial report cannot be mistaken for a complete comparison.
        pairs = []
        for formulation in ('semiimplicit',):
            for name in NAMES:
                legacy = read_force(args.results / f'legacy-{formulation}' / f'{name}.fce')
                redesign = read_force(args.results / f'redesign-{formulation}-{args.exec_space}' / f'{name}.fce')
                pairs.append((legacy, redesign, f'{formulation}/{name}'))
        for left, right, label in pairs:
            if len(left) != len(right):
                raise ValueError(f'{label}: sample counts differ ({len(left)} vs {len(right)})')
            for i, (a, b) in enumerate(zip(left, right)):
                if not math.isclose(a['Time'], b['Time'], rel_tol=1e-9, abs_tol=1e-10):
                    raise ValueError(f'{label}: time mismatch at sample {i}: {a["Time"]} vs {b["Time"]}')
        for left, right, label in pairs:
            compare(left, right, label)
    except ValueError as exc:
        parser.exit(1, f'error: {exc}\n')


if __name__ == '__main__':
    main()
