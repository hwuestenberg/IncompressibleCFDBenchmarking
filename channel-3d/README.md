# Channel 3D (Reτ=180)

This case targets mean velocity and Reynolds-stress profiles at Reτ=180 and measures solver cost. Follow the [shared mesh setup](../README.md#mesh-generation). From `channel-3d/`, build the mesh into `mesh/` and run either or both semi-implicit legs:

```sh
./build_mesh.sh
cp scripts/env.sh.example scripts/env.sh  # edit paths, then source it
source scripts/env.sh
scripts/run_case.sh --solver legacy --np 1 --outdir results/legacy
scripts/run_case.sh --solver semiimplicit --exec-space Serial --np 1 --outdir results/redesign
```

Increase `--np` for the DNS run. Use `scripts/profile_stats.py --help` to reduce the resulting `reystress*.fld` field and compare it with DNS; set `DNS_MOSER_DIR` to the reference files if needed. Required filters and a full paired result remain unverified. Time each leg for performance.
