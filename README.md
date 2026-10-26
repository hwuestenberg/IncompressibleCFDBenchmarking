# Incompressible solver cases

Run each case with the legacy `IncNavierStokesSolver`, the redesigned `IncNavierStokesSolverRedesign`, or both. The active sessions use semi-implicit time stepping. Use paired runs to check solver agreement; use the supplied literature or DNS reference where available for physical validation. The same runs can measure runtime. Solver agreement alone is not a literature validation.

| Case | Mesh elements by shape type | What it tests |
|---|---:|---|
| [Cylinder 2D](cylinder-2d/README.md) | 2,880 quadrilaterals | Schäfer–Turek drag, lift and shedding; runtime |
| [NACA0012 2D](naca0012-2d/README.md) | 12,521 triangles + 1,974 quadrilaterals | Force and field agreement; runtime |
| [eIFW 2D](eifw-2d/README.md) | 67,946 triangles + 3,015 quadrilaterals | Wing startup forces and runtime |
| [Channel 3D](channel-3d/README.md) | 1,078 hexahedra | Moser channel DNS profiles and runtime |
| [Cylinder 3D](cylinder-3d/README.md) | 115,200 hexahedra | 3D wake agreement and runtime |
| [Taylor–Green vortex 3D](tgv-3d/README.md) | 262,144 hexahedra | Reference dissipation curve and runtime |
| [NACA0012 3D](naca0012-3d/README.md) | 147,224 prisms + 412,934 tetrahedra | Force and field diagnostics; runtime |
| [eIFW 3D](eifw-3d/README.md) | 418,084 prisms + 668,827 tetrahedra | Restarted wing forces and runtime |
| [Full Imperial Front Wing 3D](fifw-3d/README.md) | 1,003,369 prisms + 1,600,112 tetrahedra | Full-wing forces and runtime |

Counts refer to volume elements (area elements for 2D). Generated meshes use the build scripts' default settings; counts for supplied compressed meshes use their recorded inventories.

Each case README gives the input and run commands. Run a single leg when measuring one solver, or both legs under matching physics when comparing outputs. For performance, wrap each run command with `time` and record the solver commit/build, MPI ranks, execution space, time step, step count, wall time and hardware. Compare runs at the same workload and report CPU and GPU resource counts separately. Use compute nodes for large 3D cases. A comparison is a result only after the runs and their post-processing finish.

## Other formulations

The active legacy sessions use `SolverType=VelocityCorrectionScheme`; redesign uses `FORMULATION=semiimplicit`. For a separate linear-implicit study, select legacy `SolverType=VCSImplicit` and redesign `FORMULATION=linearimplicit`. Redesign also provides `PressureFormulation=Strong` and `PressureFormulation=Weak`. Choose the pressure form explicitly and recheck stability and accuracy at the selected time step. Earlier linear-implicit sessions remain in some case directories as reference material; the documented run paths use semi-implicit stepping.
