#!/bin/bash

install_cuda_version=$1
cuda_install_dir=$2

# TODO: Can we do a trimmed install?
# Only install CUDA if specified version is not found.
# This is only relevant for users, the shipped CUDA installation will
# always be in versions instead of host_injections and have symlinks pointing
# to host_injections for everything we're not allowed to ship
if [ -f ${cuda_install_dir}/software/CUDA/${install_cuda_version}/EULA.txt ]; then
  echo "CUDA software found! No need to install CUDA again, proceeding with tests"
else
  # - as an installation location just use $EESSI_SOFTWARE_PATH but replacing `versions` with `host_injections`
  #   (CUDA is a binary installation so no need to worry too much about this)
  # The install is pretty fat, you need lots of space for download/unpack/install (~3*5GB), need to do a space check before we proceed
  avail_space=$(df --output=avail ${cuda_install_dir}/ | tail -n 1 | awk '{print $1}')
  if (( ${avail_space} < 16000000 )); then
    echo "Need more disk space to install CUDA, exiting now..."
    exit 1
  fi
  # install cuda in host_injections
  module load EasyBuild
  # we need the --rebuild option and a random dir for the module if the module file is shipped with EESSI
  if [ -f ${EESSI_SOFTWARE_PATH}/modules/all/CUDA/${install_cuda_version}.lua ]; then
    tmpdir=$(mktemp -d)
    extra_args="--rebuild --installpath-modules=${tmpdir}"
  fi
  eb ${extra_args} --installpath=${cuda_install_dir}/ CUDA-${install_cuda_version}.eb
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "CUDA installation failed, please check EasyBuild logs..."
    exit 1
  fi
  # clean up tmpdir if it exists
  if [ -f ${EESSI_SOFTWARE_PATH}/modules/all/CUDA/${install_cuda_version}.lua ]; then
    rm -rf ${tmpdir}
  fi
fi
