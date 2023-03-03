#!/usr/bin/env bash

# Initialise our bash functions
TOPDIR=$(dirname $(realpath $0))
source "$TOPDIR"/../../scripts/utils.sh

install_cuda_version=$1

MAXLOOPS=10

# Check if the CUDA compat libraries are installed and compatible with the target CUDA version
# if not find the latest version of the compatibility libraries and install them

# get URL to latest CUDA compat libs, exit if URL is invalid
cuda_compat_urls="$($TOPDIR/get_cuda_compatlibs.sh)"
ret=$?
if [ $ret -ne 0 ]; then
  fatal_error "Couldn't find current URLs of the CUDA compat libraries, instead got:\n $cuda_compat_urls"
fi

# loop over the compat library versions until we get one that works for us
keep_driver_check=1
# Do a maximum of MAXLOOPS attempts
for value in {1..$MAXLOOPS}
do
    latest_cuda_compat_url=$(echo "$cuda_compat_urls" | cut -d " " -f1)
    # Chomp that value out of the list
    cuda_compat_urls=$(echo $cuda_compat_urls | cut -d " " -f2-)
    latest_driver_version="${latest_cuda_compat_url%-*}"
    latest_driver_version="${latest_driver_version##*-}"
    # URLs differ for different OSes; check if we already have a number, if not remove string part that is not needed
    if [[ ! $latest_driver_version =~ ^[0-9]+$ ]]; then
      latest_driver_version="${latest_driver_version##*_}"
    fi

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

    if [ $keep_driver_check -eq 1 ]
    then
      # only keep the driver check for the latest version
      keep_driver_check=0
    else
      eessi_driver_version=0
    fi

    if (( ${latest_driver_version//./} > ${eessi_driver_version//./} )); then
      install_compat_libs=true
    else
      echo "CUDA compat libs are up-to-date, skip installation."
    fi

    if [ "${install_compat_libs}" == true ]; then
      $TOPDIR/install_cuda_compatlibs.sh ${latest_cuda_compat_url} ${install_cuda_version}
    fi

    if [[ "${install_wo_gpu}" != "true" ]]; then
      $TOPDIR/test_cuda.sh "${install_cuda_version}"
      if [ $? -eq 0 ]
      then
        cuda_version_file="${host_injections_dir}/latest/version.txt"
        echo "${install_cuda_version}" > ${cuda_version_file}
        exit 0
      else
        echo_yellow "Your driver does not seem to be not recent enough to work with that release of CUDA compat libs,"
        echo_yellow "consider updating!"
        echo_yellow "I'll try an older release to see if that will work..."
      fi
    else
      echo_yellow "Requested to install CUDA without GPUs present, with no way to verify we skip final tests."
      echo_yellow "Since we have no GPU to test with, we cannot guarantee that it will work with the installed CUDA"
      echo_yellow "drivers on your GPU node(s)."
	    exit 0
    fi
done

echo "Tried to install $MAXLOOPS different generations of compat libraries and none worked,"
echo "this usually means your driver is very out of date (or some other issue)!"
exit 1
