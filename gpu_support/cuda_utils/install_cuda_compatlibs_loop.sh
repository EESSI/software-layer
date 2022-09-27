#!/bin/bash

cuda_install_dir=$1
install_cuda_version=$2

# Check if the CUDA compat libraries are installed and compatible with the target CUDA version
# if not find the latest version of the compatibility libraries and install them

# get URL to latest CUDA compat libs, exit if URL is invalid
cuda_compat_urls="$($(dirname "$BASH_SOURCE")/get_cuda_compatlibs.sh)"
ret=$?
if [ $ret -ne 0 ]; then
  echo "Couldn't find current URLs of the CUDA compat libraries, instead got:"
  echo $cuda_compat_urls
  exit 1
fi

# loop over the compat library versions until we get one that works for us
keep_driver_check=1
# Do a maximum of five attempts
for value in {1..5}
do
    latest_cuda_compat_url=$(echo $cuda_compat_urls | cut -d " " -f1)
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
      bash $(dirname "$BASH_SOURCE")/install_cuda_compatlibs.sh ${latest_cuda_compat_url} ${cuda_install_dir}
    fi

    if [[ "${install_wo_gpu}" != "true" ]]; then
      bash $(dirname "$BASH_SOURCE")/test_cuda.sh "${install_cuda_version}"
      if [ $? -eq 0 ]
      then
        exit 0
      else
        echo
        echo "It looks like your driver is not recent enough to work with that release of CUDA, consider updating!"
        echo "I'll try an older release to see if that will work..."
        echo
      fi
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
        echo "  - Please keep in mind that we just installed the latest CUDA compat libs."
        echo "    Since we have no GPU to test with, we cannot guarantee that it will work with the installed CUDA drivers on your GPU node(s)."
	exit 0
      fi
      break
    fi
done

echo "Tried to install 5 different generations of compat libraries and none worked,"
echo "this usually means your driver is very out of date!"
exit 1
