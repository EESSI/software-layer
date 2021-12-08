#!/bin/bash
#SBATCH --job-name="rfm_GROMACS_EESSI___HECBioSim_hEGFRtetramerPair____20983100_0__0_001__cpu___small___4____example_system_gpu____builtin____GROMACS_2021_3_foss_2021a___job"
#SBATCH --ntasks=288
#SBATCH --ntasks-per-node=72
#SBATCH --cpus-per-task=1
#SBATCH --output=rfm_GROMACS_EESSI___HECBioSim_hEGFRtetramerPair____20983100_0__0_001__cpu___small___4____example_system_gpu____builtin____GROMACS_2021_3_foss_2021a___job.out
#SBATCH --error=rfm_GROMACS_EESSI___HECBioSim_hEGFRtetramerPair____20983100_0__0_001__cpu___small___4____example_system_gpu____builtin____GROMACS_2021_3_foss_2021a___job.err
#SBATCH -p gpu --gpus-per-node 4 --exclusive
module load GROMACS/2021.3-foss-2021a
curl -LJO https://github.com/victorusu/GROMACS_Benchmark_Suite/raw/1.0.0/HECBioSim/hEGFRtetramerPair/benchmark.tpr
srun gmx_mpi mdrun -nb cpu -s benchmark.tpr
