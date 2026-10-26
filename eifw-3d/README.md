# eIFW 3D

Compare semi-implicit continuation forces and run cost. The mesh is not stored in this repository. Download it from the [Imperial College London Helix record](https://helix.imperial.ac.uk/records/tpapv-twz85) and save it as `mesh/eifw-3d.xml`. Place `restart_ctu_386.fld` in this case directory, then run on compute nodes:

```sh
export NEKTAR_LEGACY_BIN=/path/to/IncNavierStokesSolver
export NEKTAR_REDESIGN_BIN=/path/to/IncNavierStokesSolverRedesign
scripts/validate_inputs.py
scripts/run_case.sh --solver legacy --formulation semiimplicit --np 128 --steps 200000 --outdir results/legacy-semiimplicit
scripts/run_case.sh --solver redesign --formulation semiimplicit --exec-space Serial --np 128 --steps 200000 --outdir results/redesign-semiimplicit-Serial
python3 scripts/compare_forces.py results --exec-space Serial
```

Set `MPI_LAUNCHER=srun` inside a Slurm allocation. Use `--source DIR` if the mesh and restart are kept together in another input directory. Run either leg alone for cost, or use `scripts/run_all.sh` to run both and compare four force histories. The redesign's mixed-velocity `H` boundary is a known execution blocker; no paired result exists. No literature target is supplied.

Note this mesh is the baseline for the study in "Implicit Velocity Correction Schemes for Scale-Resolving Simulations of Incompressible Flow: Stability, Accuracy, and Performance", Henrik Wüstenberg, Alexandra Liosi, Spencer J. Sherwin, Joaquim Peiró, David Moxey, 2026.
