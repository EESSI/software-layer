#!/bin/bash

# Get arch type from EESSI environment
if [[ -z "${EESSI_CPU_FAMILY}" ]]; then
  # set up basic environment variables, EasyBuild and Lmod
  EESSI_SILENT=1 source /cvmfs/pilot.eessi-hpc.org/latest/init/bash
fi
eessi_cpu_family="${EESSI_CPU_FAMILY:-x86_64}"

# build URL for CUDA libraries
# take rpm file for compat libs from rhel8 folder, deb and rpm files contain the same libraries
cuda_url="https://developer.download.nvidia.com/compute/cuda/repos/rhel8/"${eessi_cpu_family}"/"
# get all versions in decending order
files=$(curl -s "${cuda_url}" | grep 'cuda-compat' | sed 's/<\/\?[^>]\+>//g' | xargs -n1 | /cvmfs/pilot.eessi-hpc.org/latest/compat/linux/${eessi_cpu_family}/bin/sort -r --version-sort )
if [[ -z "${files// }" ]]; then
        echo "Could not find any compat lib files under" ${cuda_url}
        exit 1
fi
for file in $files; do echo "${cuda_url}$file"; done
