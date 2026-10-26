# NACA0012 3D

At Re=50,000 and 5° angle of attack, compare startup force and field diagnostics between solvers and measure run cost. Place `naca0012-3d.xml` in `mesh/`.

A [NACA0012 mesh-generation pipeline](https://github.com/hwuestenberg/nektar-star-pipeline) documents how to generate a 3D mesh. It produces `naca0012_periodic_full_p4_bl8.xml`; check its composite and boundary mappings, then name a compatible mesh `mesh/naca0012-3d.xml` for these sessions.

Both solvers start from freestream (`u=uInf`, `v=vInf`, `w=0`, `p=0`). Configure `scripts/env.sh` from `scripts/env.sh.example` with `NEKTAR_LEGACY_BIN`, `NEKTAR_REDESIGN_BIN` and, for Device, `NEKTAR_REDESIGN_DEVICE_BIN`. Then run one or both semi-implicit legs:

```sh
cp scripts/env.sh.example scripts/env.sh  # edit solver paths
scripts/run_leg.sh legacy semi runs/semi-legacy --np 16 --steps 10
scripts/run_leg.sh redesign semi runs/semi-redesign --exec-space Device --np 1 --steps 10
python3 scripts/compare_tab.py runs/semi-legacy runs/semi-redesign
```

Pass `--ic FILE` to `run_leg.sh` for an explicit restart; its default is freestream. Each leg records cost in `run.meta`. Earlier long spin-ups failed in both solvers; a full comparison from freestream has not been completed. No literature acceptance target is supplied.
