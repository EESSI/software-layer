#!/usr/bin/env bash

# Initialise our bash functions
TOPDIR=$(dirname $(realpath $BASH_SOURCE))
source "$TOPDIR"/../../scripts/utils.sh

# Make sure EESSI is initialised
check_eessi_initialised()

if [[ $# -eq 0 ]] ; then
    fatal_error "You must provide the CUDA version as an argument, e.g.:\n $0 11.3.1"
fi
install_cuda_version=$1
if [[ -z "${EESSI_SOFTWARE_PATH}" ]]; then
  fatal_error "This script cannot be used without having first defined EESSI_SOFTWARE_PATH"
else
  # As an installation location just use $EESSI_SOFTWARE_PATH but replacing `versions` with `host_injections`
  # (CUDA is a binary installation so no need to worry too much about the EasyBuild setup)
  cuda_install_parent=${EESSI_SOFTWARE_PATH/versions/host_injections}
fi

# Only install CUDA if specified version is not found.
# This is only relevant for users, the shipped CUDA installation will
# always be in versions instead of host_injections and have symlinks pointing
# to host_injections for everything we're not allowed to ship
# (existence of easybuild subdir implies a successful install)
if [ -d "${cuda_install_parent}"/software/CUDA/"${install_cuda_version}"/easybuild ]; then
  echo_green "CUDA software found! No need to install CUDA again, proceed with testing."
else
  # We need to be able write to the installation space so let's make sure we can
  if ! create_directory_structure "${cuda_install_parent}"/software/CUDA ; then
    fatal_error "No write permissions to directory ${cuda_install_parent}/software/CUDA"
  fi

  # we need a directory we can use for temporary storage
  if [[ -z "${CUDA_TEMP_DIR}" ]]; then
    tmpdir=$(mktemp -d)
  else
    tmpdir="${CUDA_TEMP_DIR}"/temp
    if ! mkdir "$tmpdir" ; then
      fatal_error "Could not create directory ${tmpdir}"
    fi
  fi

  required_space_in_tmpdir=50000
  # Let's see if we have sources and build locations defined if not, we use the temporary space
  if [[ -z "${EASYBUILD_BUILDPATH}" ]]; then
    export EASYBUILD_BUILDPATH=${tmpdir}/build
    required_space_in_tmpdir=$((required_space_in_tmpdir + 5000000))
  fi
  if [[ -z "${EASYBUILD_SOURCEPATH}" ]]; then
    export EASYBUILD_SOURCEPATH=${tmpdir}/sources
    required_space_in_tmpdir=$((required_space_in_tmpdir + 5000000))
  fi

  # The install is pretty fat, you need lots of space for download/unpack/install (~3*5GB),
  # need to do a space check before we proceed
  avail_space=$(df --output=avail "${cuda_install_parent}"/ | tail -n 1 | awk '{print $1}')
  if (( avail_space < 5000000 )); then
    fatal_error "Need at least 5GB disk space to install CUDA under ${cuda_install_parent}, exiting now..."
  fi
  avail_space=$(df --output=avail "${tmpdir}"/ | tail -n 1 | awk '{print $1}')
  if (( avail_space < required_space_in_tmpdir )); then
    error="Need at least ${required_space_in_tmpdir} disk space under ${tmpdir}.\n"
    error="${error}Set the environment variable CUDA_TEMP_DIR to a location with adequate space to pass this check."
    error="${error}You can alternatively set EASYBUILD_BUILDPATH and/or EASYBUILD_SOURCEPATH "
    error="${error}to reduce this requirement. Exiting now..."
    fatal_error "${error}"
  fi

  if [[ -z "${EBROOTEASYBUILD}" ]]; then
    echo_yellow "Loading EasyBuild module to do actual install"
    module load EasyBuild
  fi

  # we need the --rebuild option and a (random) dir for the module since we are
  # fixing the broken links of the EESSI-shipped installation
  extra_args="--rebuild --installpath-modules=${tmpdir}"

  # We don't want hooks used in this install, we need a vanilla CUDA installation
  touch "$tmpdir"/none.py
  # shellcheck disable=SC2086  # Intended splitting of extra_args
  eb --prefix="$tmpdir" ${extra_args} --hooks="$tmpdir"/none.py --installpath="${cuda_install_parent}"/ CUDA-"${install_cuda_version}".eb
  ret=$?
  if [ $ret -ne 0 ]; then
    fatal_error  "CUDA installation failed, please check EasyBuild logs..."
  else
    echo_green "CUDA installation at ${cuda_install_parent}/software/CUDA/${install_cuda_version} succeeded!"
  fi
  # clean up tmpdir
  rm -rf "${tmpdir}"
fi
