#!/bin/bash

install_cuda_version=$1
save_compiled_test="${SAVE_COMPILED_TEST:=false}"

# Test CUDA
cuda_install_dir="${EESSI_SOFTWARE_PATH/versions/host_injections}"
current_dir=$PWD
if [ -d ${cuda_install_dir}/modules/all ]; then
  module use ${cuda_install_dir}/modules/all/
else
  echo "Cannot test CUDA, modules path does not exist, exiting now..."
  exit 1
fi
module load CUDA/${install_cuda_version}
ret=$?
if [ $ret -ne 0 ]; then
  echo "Could not load CUDA even though modules path exists..."
  exit 1
fi
# if we don't want to save the compiled sample, it means we have a shipped version available
if [ "${save_compiled_test}" != false ]; then
  tmp_dir=$(mktemp -d)
  # convert cuda version to an integer so we can test if the samples are shipped with this version
  # starting from version 11.6 the samples can be found in a github repo
  cuda_version=$(echo ${install_cuda_version} | cut -f1,2 -d'.')
  cuda_version=${cuda_version//./}
  if (( ${cuda_version} < 116 )); then
    cp -r $EBROOTCUDA/samples $tmp_dir
    cd $tmp_dir/samples/1_Utilities/deviceQuery
  else
    git clone https://github.com/NVIDIA/cuda-samples.git ${tmp_dir}
    cd $tmp_dir/Samples/1_Utilities/deviceQuery
  fi
  module load GCCcore
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "Could not load GCC, but it should have been shipped with EESSI?! Exiting..."
    exit 1
  fi
  make HOST_COMPILER=$(which g++) -j
else
  cd ${EESSI_SOFTWARE_PATH}/software/CUDA/${install_cuda_version}
fi
./deviceQuery

if [ $? -eq 0 ] 
then
  # Set the color variable
  green='\033[0;32m'
  # Clear the color after that
  clear='\033[0m'
  echo -e ${green}
  echo "Congratulations, your GPU is working with EESSI!"
  echo "  - To build CUDA enabled modules use ${EESSI_SOFTWARE_PATH/versions/host_injections} as your EasyBuild prefix"
  echo "  - To use these modules:"
  echo "      module use ${EESSI_SOFTWARE_PATH/versions/host_injections}/modules/all/"
  echo -e ${clear}

  if [ "${save_compiled_test}" != false ]; then
    mv deviceQuery ${EESSI_SOFTWARE_PATH}/software/CUDA/${install_cuda_version}
  fi

  # Clean up
  cd $current_dir
  if [ "${save_compiled_test}" != false ]; then
    rm -r $tmp_dir
  fi
else 
  echo "Uff, your GPU doesn't seem to be working with EESSI :(" >&2
  # Clean up
  cd $current_dir
  if [ "${save_compiled_test}" != false ]; then
    rm -r $tmp_dir
  fi
  exit 1
fi

# Test a CUDA-enabled module from EESSI
# TODO: GROMACS?
# TODO: Include a GDR copy test?
###############################################################################################
