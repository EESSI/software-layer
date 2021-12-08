#!/bin/bash
#SBATCH --job-name="rfm_GROMACS_EESSI___HECBioSim_hEGFRDimerPair____12073300_0__0_001__cpu___large___10____example_system_cpu____builtin____GROMACS_2021_3_foss_2021a___job"
#SBATCH --ntasks=1280
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH --output=rfm_GROMACS_EESSI___HECBioSim_hEGFRDimerPair____12073300_0__0_001__cpu___large___10____example_system_cpu____builtin____GROMACS_2021_3_foss_2021a___job.out
#SBATCH --error=rfm_GROMACS_EESSI___HECBioSim_hEGFRDimerPair____12073300_0__0_001__cpu___large___10____example_system_cpu____builtin____GROMACS_2021_3_foss_2021a___job.err
#SBATCH -p thin
module load GROMACS/2021.3-foss-2021a
curl -LJO https://github.com/victorusu/GROMACS_Benchmark_Suite/raw/1.0.0/HECBioSim/hEGFRDimerPair/benchmark.tpr
srun gmx_mpi mdrun -nb cpu -s benchmark.tpr
