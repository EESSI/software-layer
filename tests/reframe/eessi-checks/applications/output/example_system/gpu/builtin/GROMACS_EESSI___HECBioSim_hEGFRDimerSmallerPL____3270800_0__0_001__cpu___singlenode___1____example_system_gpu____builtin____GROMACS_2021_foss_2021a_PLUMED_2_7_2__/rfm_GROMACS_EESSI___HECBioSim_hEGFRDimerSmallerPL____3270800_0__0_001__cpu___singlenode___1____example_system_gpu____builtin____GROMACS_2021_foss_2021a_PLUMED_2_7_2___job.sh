#!/bin/bash
#SBATCH --job-name="rfm_GROMACS_EESSI___HECBioSim_hEGFRDimerSmallerPL____3270800_0__0_001__cpu___singlenode___1____example_system_gpu____builtin____GROMACS_2021_foss_2021a_PLUMED_2_7_2___job"
#SBATCH --ntasks=72
#SBATCH --ntasks-per-node=72
#SBATCH --cpus-per-task=1
#SBATCH --output=rfm_GROMACS_EESSI___HECBioSim_hEGFRDimerSmallerPL____3270800_0__0_001__cpu___singlenode___1____example_system_gpu____builtin____GROMACS_2021_foss_2021a_PLUMED_2_7_2___job.out
#SBATCH --error=rfm_GROMACS_EESSI___HECBioSim_hEGFRDimerSmallerPL____3270800_0__0_001__cpu___singlenode___1____example_system_gpu____builtin____GROMACS_2021_foss_2021a_PLUMED_2_7_2___job.err
#SBATCH -p gpu --gpus-per-node 4 --exclusive
module load GROMACS/2021-foss-2021a-PLUMED-2.7.2
curl -LJO https://github.com/victorusu/GROMACS_Benchmark_Suite/raw/1.0.0/HECBioSim/hEGFRDimerSmallerPL/benchmark.tpr
srun gmx_mpi mdrun -nb cpu -s benchmark.tpr
