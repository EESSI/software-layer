#!/bin/bash

# Test CUDA
cuda_install_dir="${EESSI_SOFTWARE_PATH/versions/host_injections}"
if [ -d ${cuda_install_dir}/modules/all ]; then
  module use ${cuda_install_dir}/modules/all/
else
  echo "Cannot test CUDA, modules path does not exist, exiting now..."
  exit 1
fi
module load CUDA
ret=$?
if [ $ret -ne 0 ]; then
  echo "Could not load CUDA even though modules path exists..."
  exit 1
fi
tmp_dir=$(mktemp -d)
cp -r $EBROOTCUDA/samples $tmp_dir
current_dir=$PWD
cd $tmp_dir/samples/1_Utilities/deviceQuery
make HOST_COMPILER=$(which g++) -j
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

  # Clean up
  cd $current_dir
  rm -r $tmp_dir
else 
  echo "Uff, your GPU doesn't seem to be working with EESSI :(" >&2
  # Clean up
  cd $current_dir
  rm -r $tmp_dir
  exit 1
fi

# Test building something with CUDA and running
# TODO: Use samples from installation directory, `device_query` is a good option

# Test a CUDA-enabled module from EESSI
# TODO: GROMACS?
# TODO: Include a GDR copy test?
###############################################################################################