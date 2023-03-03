#!/usr/bin/env bash

# Initialise our bash functions
TOPDIR=$(dirname $(realpath $0))
source "$TOPDIR"/../../scripts/utils.sh

if [[ $# -eq 0 ]] ; then
    fatal_error "You must provide the CUDA version as an argument, e.g.:\n $0 11.3.1"
fi
cuda_version=$1

check_eessi_initialised

# We can figure out the (EasyBuild MNS) CUDA samples version we need since we know the version suffix
cuda_samples_version=$(basename "$(ls -d "${EESSI_SOFTWARE_PATH}"/software/CUDA-Samples/*-CUDA-"${cuda_version}")")

# Test CUDA (making sure to use EasyBuild MNS)
unset MODULEPATH
module use "${EESSI_SOFTWARE_PATH}"/modules/all
module load CUDA-Samples/"${cuda_samples_version}"
ret=$?
if [ $ret -ne 0 ]; then
  fatal_error "Could not load CUDA samples module CUDA-Samples/${cuda_samples_version}\n (MODULEPATH=$MODULEPATH)..."
fi

if deviceQuery;
then
  echo_green "Congratulations, your GPU is working with EESSI!"
else 
  echo_yellow "Uff, your GPU doesn't seem to be working with EESSI :(" >&2
  exit "${ANY_ERROR_EXITCODE}"
fi

# Test another CUDA-enabled module from EESSI
# TODO: GROMACS?
# TODO: Include a GDR copy test?
###############################################################################################
