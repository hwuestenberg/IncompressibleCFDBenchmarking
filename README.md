# Incompressible solver cases

Run each case with the legacy `IncNavierStokesSolver`, the redesigned `IncNavierStokesSolverRedesign`, or both. The active sessions use semi-implicit time stepping. Use paired runs to check solver agreement; use the supplied literature or DNS reference where available for physical validation. The same runs can measure runtime. Solver agreement alone is not a literature validation.

| Case | Mesh elements by shape type | What it tests |
|---|---:|---|
| [Cylinder 2D](cylinder-2d/README.md) | 2,880 quadrilaterals | Schäfer–Turek drag, lift and shedding; runtime |
| [NACA0012 2D](naca0012-2d/README.md) | 12,521 triangles + 1,974 quadrilaterals | Startup force and field agreement; runtime |
| [eIFW 2D](eifw-2d/README.md) | 67,946 triangles + 3,015 quadrilaterals | Wing startup forces and runtime |
| [Channel 3D, Reτ=180](channel-3d/README.md) | 1,078 hexahedra | Mean velocity and Reynolds-stress profiles; runtime |
| [Cylinder 3D](cylinder-3d/README.md) | 115,200 hexahedra | 3D wake agreement and runtime |
| [Taylor–Green vortex 3D](tgv-3d/README.md) | 262,144 hexahedra | Reference dissipation curve and runtime |
| [NACA0012 3D](naca0012-3d/README.md) | 147,224 prisms + 412,934 tetrahedra | Startup force and field diagnostics; runtime |
| [eIFW 3D](eifw-3d/README.md) | 418,084 prisms + 668,827 tetrahedra | Restarted wing forces and runtime |

Counts refer to volume elements (area elements for 2D). Generated meshes use the build scripts' default settings.

## Mesh generation

The cylinder 2D, cylinder 3D, channel 3D and Taylor–Green vortex 3D cases include Gmsh geometry and build scripts. Install Gmsh and Docker, then run this setup from the repository root. The helper runs NekMesh with the official [Nektar++ `latest` image](https://hub.docker.com/r/nektarpp/nektar/tags), mounting this repository so generated files remain in each case's `mesh/` directory.

```sh
docker pull nektarpp/nektar:latest
export GMSH_BIN="$(command -v gmsh)"
export NEKMESH_BIN="$PWD/scripts/nekmesh-docker.sh"
```

Run the build script in the desired case directory; each script supplies its own Gmsh dimension and any NekMesh periodic alignment:

```sh
(cd cylinder-2d && ./build_mesh_2d.sh)
(cd cylinder-3d && ./build_mesh.sh)
(cd channel-3d && ./build_mesh.sh)
(cd tgv-3d && ./build_mesh.sh)
```

For a local NekMesh installation, set `NEKMESH_BIN` to its executable path instead. Other cases use an included mesh or require one to be placed in `mesh/`, as stated in their case READMEs.

Each case stores its primary geometry and final mesh in `mesh/` with the case directory name as the filename stem (for example, `cylinder-3d/mesh/cylinder-3d.geo` and `cylinder-3d/mesh/cylinder-3d.xml`). Each case README gives the input and run commands. Case runners accept `--np` for MPI ranks and use `NEKTAR_LEGACY_BIN` and `NEKTAR_REDESIGN_BIN` for solver paths; set `NEKTAR_REDESIGN_DEVICE_BIN` when Device needs a separate build. Run a single leg when measuring one solver, or both legs under matching physics when comparing outputs. For performance, wrap each run command with `time` and record the solver commit/build, MPI ranks, execution space, time step, step count, wall time and hardware. Compare runs at the same workload and report CPU and GPU resource counts separately. Use compute nodes for large 3D cases. A comparison is a result only after the runs and their post-processing finish.

## Other formulations

Each case contains `session-legacy.xml` and `session-redesign.xml` for the semi-implicit comparison. Velocity and pressure use equal expansion order, and each solver pair uses matching reporting intervals. The legacy sessions use `SolverType=VelocityCorrectionScheme`; redesign uses `FORMULATION=semiimplicit`. For a separate linear-implicit study, select legacy `SolverType=VCSImplicit` and redesign `FORMULATION=linearimplicit`. Redesign also provides `PressureFormulation=Strong` and `PressureFormulation=Weak`. Choose the pressure form explicitly and recheck stability and accuracy at the selected time step.
