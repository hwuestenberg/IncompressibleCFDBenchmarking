# Taylor–Green vortex 3D

At Re=1600, compare kinetic-energy dissipation with the included reference curve and time either solver. Follow the [shared mesh setup](../README.md#mesh-generation); the build writes the mesh into `mesh/`. From this directory:

```sh
./mesh/build_mesh.sh
cp scripts/env.sh.example scripts/env.sh  # edit paths, then source it
source scripts/env.sh
scripts/run_case.sh --solver legacy --np 1 --outdir results/legacy
scripts/run_case.sh --solver semiimplicit --exec-space Serial --np 1 --outdir results/redesign
python3 scripts/dissipation_rate.py --legacy-eny results/legacy/tgv-3d.eny --redesign-eny results/redesign/tgv-3d.eny
```

Increase `--np` for the full mesh. The `Energy` filter must be available in both binaries. The post-processor reports the reference comparison; no completed paired result is stored here. Time each `run_case.sh` command for performance.
