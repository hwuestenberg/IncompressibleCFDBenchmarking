# NACA0012 2D

At Re=50,000 and 5° angle of attack, compare wing forces and fields between solvers and measure run cost. The mesh is included. Both solvers start from freestream (`u=uInf`, `v=vInf`, `p=0`). Run from this directory:

```sh
cp scripts/env.sh.example scripts/env.sh  # edit paths, then source it
source scripts/env.sh
scripts/run_case.sh --solver legacy --np 1 --steps 50000 --outdir results/semi-legacy
scripts/run_case.sh --solver semiimplicit --exec-space Device --np 1 --steps 50000 --outdir results/semi-redesign
```

Use `--exec-space Serial` or `AVX` with its matching redesign binary if needed. The 50,000-step example covers startup, not developed-flow statistics. No literature acceptance target is supplied. Time each leg for performance.
