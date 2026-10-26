# Cylinder 3D

At Re=300, compare the 3D wake forces and shedding frequency between solvers, or time either solver. No fixed literature acceptance range is supplied. The included `mesh/cylinder-3d.geo` is built using the [shared mesh setup](../README.md#mesh-generation); the build writes the mesh into `mesh/`. From this directory:

```sh
./build_mesh.sh
cp scripts/env.sh.example scripts/env.sh  # edit paths, then source it
source scripts/env.sh
scripts/run_case.sh --solver legacy --np 1 --outdir results/legacy
scripts/run_case.sh --solver semiimplicit --exec-space Serial --np 1 --outdir results/redesign
python3 scripts/compare_forces.py --span-length 4.0 results/legacy/DragLift.fce results/redesign/DragLift.fce
```

Increase `--np` for the 3D mesh; `AVX` and `Device` are alternate redesign execution spaces. No completed paired result is stored here. Time each `run_case.sh` command for performance.
