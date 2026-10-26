# eIFW 2D

At Re=220,000, compare startup wing forces between solvers and measure run cost. The mesh is included; set both solver paths and run:

```sh
export NEKTAR_LEGACY_BIN=/path/to/IncNavierStokesSolver
export NEKTAR_REDESIGN_BIN=/path/to/IncNavierStokesSolverRedesign
scripts/run_case.sh --solver legacy --formulation semiimplicit --np 1 --steps 50000 --outdir results/legacy-semiimplicit
scripts/run_case.sh --solver redesign --formulation semiimplicit --exec-space Serial --np 1 --steps 50000 --outdir results/redesign-semiimplicit-Serial
python3 scripts/compare_forces.py results --exec-space Serial
```

Run either leg alone for a cost measurement, or use `scripts/run_all.sh` to run both and compare four force histories. The redesign currently stops on the mixed-velocity `H` boundary, so there is no paired result. This short startup run has no literature target. Time individual `run_case.sh` legs for performance.
