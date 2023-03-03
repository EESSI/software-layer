#!/bin/bash

# Drop into the prefix shell or pipe this script into a Prefix shell with
#   $EPREFIX/startprefix <<< /path/to/this_script.sh

TOPDIR=$(dirname $(realpath $0))

source $TOPDIR/scripts/utils.sh

install_cuda="${INSTALL_CUDA:=false}"
eessi_version="${EESSI_PILOT_VERSION:=latest}"

# If you want to install CUDA support on login nodes (typically without GPUs),
# set this variable to true. This will skip all GPU-dependent checks
install_wo_gpu=false
[ "$INSTALL_WO_GPU" = true ] && install_wo_gpu=true

# verify existence of nvidia-smi or this is a waste of time
# Check if nvidia-smi exists and can be executed without error
if [[ "${install_wo_gpu}" != "true" ]]; then
  if command -v nvidia-smi > /dev/null 2>&1; then
    nvidia-smi > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      error="nvidia-smi was found but returned error code, exiting now...\n"
      error="${error}If you do not have a GPU on this device but wish to force the installation,\n"
      error="${error}please set the environment variable INSTALL_WO_GPU=true"
      fatal_error "$error"
    fi
    echo "nvidia-smi found, continue setup."
  else
    error="nvidia-smi not found, exiting now...\n"
    error="${error}If you do not have a GPU on this device but wish to force the installation,\n"
    error="${error}please set the environment variable INSTALL_WO_GPU=true\n"
    fatal_error "$error"
  fi
else
  echo_green "You requested to install CUDA without GPUs present."
  echo_green "This means that all GPU-dependent tests/checks will be skipped!"
fi

EESSI_SILENT=1 source /cvmfs/pilot.eessi-hpc.org/"${eessi_version}"/init/bash

##############################################################################################
# Check that the CUDA driver version is adequate
# (
#  needs to be r450 or r470 which are LTS, other production branches are acceptable but not
#  recommended, below r450 is not compatible [with an exception we will not explore,see
#  https://docs.nvidia.com/datacenter/tesla/drivers/#cuda-drivers]
# )
# only check first number in case of multiple GPUs
if [[ "${install_wo_gpu}" != "true" ]]; then
  driver_major_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | tail -n1)
  driver_major_version="${driver_major_version%%.*}"
  # Now check driver_version for compatibility
  # Check driver is at least LTS driver R450, see https://docs.nvidia.com/datacenter/tesla/drivers/#cuda-drivers
  if (( driver_major_version < 450 )); then
    fatal_error "Your NVIDIA driver version ($driver_major_version) is too old, please update first.."
  fi
fi

###############################################################################################
# Install CUDA
###############################################################################################

# Now we have the EESSI context enabled let's grab the version(s) of CUDA we need to install
# (we assume here that CUDA versions are always simple version strings with semantic versions)
cuda_versions=($(ls "$EESSI_SOFTWARE_PATH"/software/CUDA/))
latest_cuda_version="${cuda_versions[0]}"  # EESSI starts with CUDA 11, no need for <10 logic
if [ "${install_cuda}" != false ]; then
  for cuda_version in "${cuda_versions[@]}"
  do
    "$TOPDIR"/cuda_utils/install_cuda_host_injections.sh "${latest_cuda_version}"
  done
fi
###############################################################################################
# Prepare installation of CUDA compat libraries, i.e. install p7zip if it is missing
###############################################################################################
# Try installing different versions of CUDA compat libraries until the test works.
"$TOPDIR"/cuda_utils/install_cuda_compatlibs_loop.sh "${latest_cuda_version}"
