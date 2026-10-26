# Cylinder 2D

At Re=100, compare mean drag, lift amplitude and Strouhal number with the Schäfer–Turek benchmark, or time either solver at the same workload. The geometry is included in `mesh/`. Follow the [shared mesh setup](../README.md#mesh-generation), then build from `cylinder-2d/`:

```sh
./build_mesh_2d.sh
```

The generated `mesh/cylinder-2d.xml` is the input for both sessions. Set solver paths and run:

```sh
cp scripts/env.sh.example scripts/env.sh  # edit paths, then source it
source scripts/env.sh
scripts/run_case.sh --solver legacy --np 1 --outdir results/legacy
scripts/run_case.sh --solver semiimplicit --exec-space Serial --np 1 --outdir results/redesign
python3 scripts/compare_forces.py results/legacy/DragLift.fce results/redesign/DragLift.fce
```

Increase `--np` for multiple ranks; set `NEKTAR_REDESIGN_BIN` for Serial/AVX or `NEKTAR_REDESIGN_DEVICE_BIN` for a separate Device build. The case needs HOPBC and `AeroForces`. Use `compare_forces.py` to report drag, lift and shedding frequency; time each `run_case.sh` command for performance.
