#!/bin/bash

if [[ $# -eq 0 ]] ; then
    echo 'You must provide the CUDA version as an argument, e.g.:'
    echo "  $0 11.3.1"
    exit 1
fi
install_cuda_version=$1
if [[ -z "${EESSI_SOFTWARE_PATH}" ]]; then
  echo "This script cannot be used without having first defined EESSI_SOFTWARE_PATH"
  exit 1
else
  # As an installation location just use $EESSI_SOFTWARE_PATH but replacing `versions` with `host_injections`
  # (CUDA is a binary installation so no need to worry too much about the EasyBuild setup)
  cuda_install_dir=${EESSI_SOFTWARE_PATH/versions/host_injections}
fi

# Only install CUDA if specified version is not found.
# This is only relevant for users, the shipped CUDA installation will
# always be in versions instead of host_injections and have symlinks pointing
# to host_injections for everything we're not allowed to ship
# (existence of easybuild subdir implies a successful install)
if [ -d ${cuda_install_dir}/software/CUDA/${install_cuda_version}/easybuild ]; then
  echo "CUDA software found! No need to install CUDA again, proceed with testing."
else
  # The install is pretty fat, you need lots of space for download/unpack/install (~3*5GB), need to do a space check before we proceed
  avail_space=$(df --output=avail ${cuda_install_dir}/ | tail -n 1 | awk '{print $1}')
  if (( ${avail_space} < 16000000 )); then
    echo "Need more disk space to install CUDA, exiting now..."
    exit 1
  fi
  if [[ ! -z "${EBROOTEASYBUILD}" ]]; then
    echo "Loading EasyBuild module to do actual install"
    module load EasyBuild
  fi
  # we need the --rebuild option and a random dir for the module if the module file is shipped with EESSI
  if [ -f ${EESSI_SOFTWARE_PATH}/modules/all/CUDA/${install_cuda_version}.lua ]; then
    tmpdir=$(mktemp -d)
    extra_args="--rebuild --installpath-modules=${tmpdir}"
  fi
  # We don't want hooks used in this install, we need a vanilla CUDA installation
  touch $tmpdir/none.py
  eb ${extra_args} --hooks=$tmpdir/none.py --installpath=${cuda_install_dir}/ CUDA-${install_cuda_version}.eb
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
