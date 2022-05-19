#!/bin/bash

# Drop into the prefix shell or pipe this script into a Prefix shell with
#   $EPREFIX/startprefix <<< /path/to/this_script.sh

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
      echo "nvidia-smi was found but returned error code, exiting now..." >&2
      exit 1
    fi
    echo "nvidia-smi found, continue setup."
  else
    echo "nvidia-smi not found, exiting now..." >&2
    echo "If you do not have a GPU on this device but wish to force the installation,"
    echo "please set the environment variable INSTALL_WO_GPU=true"
    exit 1
  fi
else
  echo "You requested to install CUDA without GPUs present."
  echo "This means that all GPU-dependent tests/checks will be skipped!"
fi

# set up basic environment variables, EasyBuild and Lmod
EESSI_SILENT=1 source /cvmfs/pilot.eessi-hpc.org/versions/2021.12/init/bash

current_dir=$(dirname $(realpath $0))

# Get arch type from EESSI environment
eessi_cpu_family="${EESSI_CPU_FAMILY:-x86_64}"

# Get OS family
# TODO: needs more thorough testing
os_family=$(uname | tr '[:upper:]' '[:lower:]')

# Get OS version
# TODO: needs more thorough testing, taken from https://unix.stackexchange.com/a/6348
if [ -f /etc/os-release ]; then
  # freedesktop.org and systemd
  . /etc/os-release
  os=$NAME
  ver=$VERSION_ID
  if [[ "$os" == *"Rocky"* ]]; then
    os="rhel"
  fi
  if [[ "$os" == *"Debian"* ]]; then
    os="debian"
  fi
elif type lsb_release >/dev/null 2>&1; then
  # linuxbase.org
  os=$(lsb_release -si)
  ver=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
  # For some versions of Debian/Ubuntu without lsb_release command
  . /etc/lsb-release
  os=$DISTRIB_ID
  ver=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
  # Older Debian/Ubuntu/etc.
  os=Debian
  ver=$(cat /etc/debian_version)
else
  # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
  os=$(uname -s)
  ver=$(uname -r)
fi
# Convert OS version to major versions, e.g. rhel8.5 -> rhel8
# TODO: needs testing for e.g. Ubuntu 20.04
ver=${ver%.*}

##############################################################################################
# Check that the CUDA driver version is adequate
# (
#  needs to be r450 or r470 which are LTS, other production branches are acceptable but not
#  recommended, below r450 is not compatible [with an exception we will not explore,see
#  https://docs.nvidia.com/datacenter/tesla/drivers/#cuda-drivers]
# )
# only check first number in case of multiple GPUs
if [[ "${install_wo_gpu}" != "true" ]]; then
  driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | tail -n1)
  driver_version="${driver_version%%.*}"
  # Now check driver_version for compatability
  # Check driver is at least LTS driver R450, see https://docs.nvidia.com/datacenter/tesla/drivers/#cuda-drivers
  if (( $driver_version < 450 )); then
    echo "Your NVIDIA driver version is too old, please update first.."
    exit 1
  fi
fi


# Check if the CUDA compat libraries are installed and compatible with the target CUDA version
# if not find the latest version of the compatibility libraries and install them

# get URL to latest CUDA compat libs, exit if URL is invalid
latest_cuda_compat_url="$($(dirname "$BASH_SOURCE")/get_latest_cuda_compatlibs.sh ${os} ${ver} ${eessi_cpu_family})"
ret=$?
if [ $ret -ne 0 ]; then
  echo $latest_cuda_compat_url
  exit 1
fi
latest_driver_version="${latest_cuda_compat_url%-*}"
latest_driver_version="${latest_driver_version##*_}"

install_compat_libs=false
host_injections_dir="/cvmfs/pilot.eessi-hpc.org/host_injections/nvidia"
# libcuda.so points to actual cuda compat lib with driver version in its name
# if this file exists, cuda compat libs are installed and we can compare the version
if [ -e $host_injections_dir/latest/compat/libcuda.so ]; then
  eessi_driver_version=$( realpath $host_injections_dir/latest/compat/libcuda.so)
  eessi_driver_version="${eessi_driver_version##*so.}"
else
  eessi_driver_version=0
fi

if [ ${latest_driver_version//./} -gt ${eessi_driver_version//./} ]; then
  install_compat_libs=true
else
  echo "CUDA compat libs are up-to-date, skip installation."
fi

if [ "${install_compat_libs}" == true ]; then
  source $(dirname "$BASH_SOURCE")/install_cuda_compatlibs.sh $latest_cuda_compat_url
fi

###############################################################################################
###############################################################################################
# Install CUDA
# TODO: Can we do a trimmed install?
# if modules dir exists, load it for usage within Lmod
cuda_install_dir="${EESSI_SOFTWARE_PATH/versions/host_injections}"
mkdir -p ${cuda_install_dir}
if [ -d ${cuda_install_dir}/modules/all ]; then
  module use ${cuda_install_dir}/modules/all
fi
# only install CUDA if specified version is not found
install_cuda_version="11.3.1"
module avail 2>&1 | grep -i CUDA/${install_cuda_version} &> /dev/null
if [[ $? -eq 0 ]]; then
    echo "CUDA module found! No need to install CUDA again, proceeding with tests"
else
  # - as an installation location just use $EESSI_SOFTWARE_PATH but replacing `versions` with `host_injections`
  #   (CUDA is a binary installation so no need to worry too much about this)
  # TODO: The install is pretty fat, you need lots of space for download/unpack/install (~3*5GB), need to do a space check before we proceed
  avail_space=$(df --output=avail ${cuda_install_dir}/ | tail -n 1 | awk '{print $1}')
  if (( ${avail_space} < 16000000 )); then
    echo "Need more disk space to install CUDA, exiting now..."
    exit 1
  fi
  # install cuda in host_injections
  module load EasyBuild
  eb --installpath=${cuda_install_dir}/ CUDA-${install_cuda_version}.eb
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "CUDA installation failed, please check EasyBuild logs..."
    exit 1
  fi
fi

cd $current_dir
if [[ "${install_wo_gpu}" != "true" ]]; then
  source $(dirname "$BASH_SOURCE")/test_cuda
else
  echo "Requested to install CUDA without GPUs present, so we skip final tests."
  echo "Instead we test if module load CUDA works as expected..."
  if [ -d ${cuda_install_dir}/modules/all ]; then
    module use ${cuda_install_dir}/modules/all/
  else
    echo "Cannot load CUDA, modules path does not exist, exiting now..."
    exit 1
  fi
  module load CUDA
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "Could not load CUDA even though modules path exists..."
    exit 1
  else
    echo "Successfully loaded CUDA, you are good to go! :)"
    echo "  - To build CUDA enabled modules use ${EESSI_SOFTWARE_PATH/versions/host_injections} as your EasyBuild prefix"
    echo "  - To use these modules:"
    echo "      module use ${EESSI_SOFTWARE_PATH/versions/host_injections}/modules/all/"
  fi
fi
