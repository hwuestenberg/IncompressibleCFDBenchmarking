# Channel 3D production startup investigation

Source: `bc9adad6fa33fac1ad9ec9e3ad8019b33272d492`, Release AVX512/MPI on nighthawk. The production sessions used their supplied physics, `TimeStep=0.002`, expansion order 9, and eight ranks. Only `NumSteps=100` and logging frequency were overridden. The generated mesh has 1,078 hexes, spans 6×2×3, and contains the session's periodic, wall, and fluid composites.

## Production failures

- [Legacy log](../channel-3d/legacy/run.log): reached step 26 at physical time 0.052, then was stopped after repeated 5,001-iteration solver warnings and `-nan` residuals. CFL rose from 0.152 at step 10 to 34.72 at step 20. [Kinetic energy](../channel-3d/legacy/channel-3d.eny) was 0.268 at time 0.020, 1.320 at 0.040, and `1.544e167` at 0.052. The step-26 attempt took about 371 seconds.
- [Redesign log](../channel-3d/redesign/run.log): failed before step 1. The pressure solve converged in 2,102 iterations, then another solve exceeded the 5,001-iteration cap. Diagonal is redesign's only supported preconditioner; the legacy session correctly uses `LowEnergyBlock` for velocity. The intended preconditioners differ between solvers.

## Isolated diagnostics

- [Unsupported preconditioner probe](redesign-legacy-precon-step1/run.log): the redesign binary rejects `LowEnergyBlockPreconAVX` as unavailable. This was a compatibility probe; `LowEnergyBlock` is for legacy only, and other redesign preconditioners are future work.
- [Expansion order 7](redesign-order7-step1/run.log): pressure converged in 1,388 iterations, but the next solve still reached the 5,001-iteration cap before step 1. Lower order alone did not remove the failure.
- [Iteration cap 20,000](redesign-maxiter20000-step1/run.log): one step completed with the source mesh, order, time step, and diagonal preconditioner. Its velocity solves required 19,323 and 18,614 iterations. This isolates the immediate redesign abort to the iteration cap and very slow convergence; it does not establish that 100 steps are stable.
- [Legacy half time step](legacy-halfdt-40/run.log): with `TimeStep=0.001`, CFL had grown to 1.411 and enstrophy to 35.155 by step 21, physical time 0.021. The diagnostic was stopped there. Reducing the time step did not prevent early growth.
- [Redesign Serial/StdMat](redesign-serial-stdmat-step1/run.log): manually stopped after five minutes without completing step 1; inconclusive.
- [Legacy laminar control](legacy-laminar-30/run.log): removed the perturbation but retained the original time step and mesh. Completed 30 steps to time 0.06. CFL stayed near 0.094; final kinetic energy was 0.266648 versus 0.266667 initially.
- [Legacy divergence-free perturbation](legacy-solenoidal-30/run.log): replaced the supplied perturbation with a streamfunction-derived perturbation of similar scale while retaining the original time step and mesh. Completed 30 steps to time 0.06. CFL stayed near 0.095; final kinetic energy was 0.267161 versus 0.267172 initially. The supplied perturbation has nonzero analytical divergence: at `(x,y,z)=(0,1,0)`, its divergence is `0.1*(2π/3) ≈ 0.20944`.
- [Redesign divergence-free perturbation](redesign-solenoidal-step1/run.log): pressure converged in 223 iterations, but the following solve still reached the 5,001-iteration cap before step 1. The initial-condition change did not solve redesign's preconditioning problem.

The controls strongly associate legacy's explosive growth with the supplied initial perturbation. They do not prove that its nonzero divergence is the sole cause because the streamfunction control also changes the perturbation's shape and amplitude. Separately, redesign's supported diagonal preconditioner requires about 19,000 iterations for its first velocity solves, while its configured cap is 5,001. Raising the cap completed one diagnostic step but is not a practical production fix. No source-physics channel leg reached the requested 100 steps. Downstream production cases were stopped on request; their status is recorded in the parent [report](../REPORT.md).

## Suggested next tests

1. Measure discrete divergence of the supplied initial state and test a divergence-free projection that retains its kinetic energy. Run legacy with its `LowEnergyBlock` preconditioner through 100 steps at the source time step; compare CFL, energy, and pressure iterations with the existing controls.
2. Keep Diagonal in redesign. Compare one-step AVX `SumFac` and AVX `StdMat` residual histories with identical mesh, initial state, tolerance, and rank count to check whether the operator implementation affects the roughly 19,000 velocity iterations. Use the larger iteration cap only for bounded diagnostics.
3. Repeat paired 100-step validation only after both source-physics legs can complete. Document the intentional `LowEnergyBlock`/Diagonal difference when interpreting runtime.
