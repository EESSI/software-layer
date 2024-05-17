#!/usr/bin/env bash

# This script can be used to install cuDNN under the `.../host_injections` directory.
# This provides the parts of the cuDNN installation that cannot be redistributed as
# part of EESSI due to license limitations. While GPU-based software from EESSI will
# _run_ without these, installation of additional software that requires the cuDNN
# installation(s) under `host_injections` to be present.
#
# The `host_injections` directory is a variant symlink that by default points to
# `/opt/eessi`, unless otherwise defined in the local CVMFS configuration (see
# https://cvmfs.readthedocs.io/en/stable/cpt-repo.html#variant-symlinks). For the
# installation to be successful, this directory needs to be writeable by the user
# executing this script.

# Initialise our bash functions
TOPDIR=$(dirname $(realpath $BASH_SOURCE))
source "$TOPDIR"/../../utils.sh

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --help                             Display this help message"
    echo "  -c, --cuda-version CUDA_VERSION    Specify a version of CUDA to be used"
    echo "                                     when installing cuDNN (must"
    echo "                                     have a corresponding easyconfig in the"
    echo "                                     EasyBuild release)"
    echo "  -d, --cudnn-version CUDNN_VERSION  Specify a version of cuDNN to install (must"
    echo "                                     have a corresponding easyconfig in the"
    echo "                                     EasyBuild release)"
    echo "  -t, --temp-dir /path/to/tmpdir     Specify a location to use for temporary"
    echo "                                     storage during the cuDNN install"
    echo "                                     (must have >10GB available)"
}

# Initialize variables
cuda_version=""
cudnn_version=""

# Parse command-line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)
            show_help
            exit 0
            ;;
        -c|--cuda-version)
            if [ -n "$2" ]; then
                cuda_version="$2"
                shift 2
            else
                echo "Error: Argument required for $1"
                show_help
                exit 1
            fi
            ;;
        -d|--cudnn-version)
            if [ -n "$2" ]; then
                cudnn_version="$2"
                shift 2
            else
                echo "Error: Argument required for $1"
                show_help
                exit 1
            fi
            ;;
        -t|--temp-dir)
            if [ -n "$2" ]; then
                CUDA_TEMP_DIR="$2"
                shift 2
            else
                echo "Error: Argument required for $1"
                show_help
                exit 1
            fi
            ;;
        *)
            show_help
            fatal_error "Error: Unknown option: $1"
            ;;
    esac
done

# Make sure EESSI is initialised
check_eessi_initialised

# Make sure the CUDA version supplied is a semantic version
is_semantic_version() {
    local version=$1
    local regex='^[0-9]+\.[0-9]+\.[0-9]+$'

    if [[ $version =~ $regex ]]; then
        return 0  # Return success (0) if it's a semantic version
    else
        return 1  # Return failure (1) if it's not a semantic version
    fi
}
if ! is_semantic_version "$cuda_version"; then
  show_help
  error="\nYou must provide a semantic version for CUDA (e.g., 12.1.1) via the appropriate\n"
  error="${error}command line option. This script is intended for use with EESSI so the 'correct'\n"
  error="${error}version to provide is probably one of those available under\n"
  error="${error}$EESSI_SOFTWARE_PATH/software/cuDNN\n"
  fatal_error "${error}"
fi

# As an installation location just use $EESSI_SOFTWARE_PATH but replacing `versions` with `host_injections`
cudnn_install_parent=${EESSI_SOFTWARE_PATH/versions/host_injections}

# Only install cuDNN if specified version is not found.
# (existence of easybuild subdir implies a successful install)
if [ -d "${cudnn_install_parent}"/software/cuDNN/*-CUDA-"${cuda_version}"/easybuild ]; then
  echo_green "cuDNN software found! No need to install cuDNN again."
else
  # We need to be able write to the installation space so let's make sure we can
  if ! create_directory_structure "${cudnn_install_parent}"/software/cuDNN ; then
    fatal_error "No write permissions to directory ${cudnn_install_parent}/software/cuDNN"
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
  avail_space=$(df --output=avail "${cudnn_install_parent}"/ | tail -n 1 | awk '{print $1}')
  if (( avail_space < 5000000 )); then
    fatal_error "Need at least 5GB disk space to install cuDNN under ${cudnn_install_parent}, exiting now..."
  fi
  avail_space=$(df --output=avail "${tmpdir}"/ | tail -n 1 | awk '{print $1}')
  if (( avail_space < required_space_in_tmpdir )); then
    error="Need at least ${required_space_in_tmpdir} disk space under ${tmpdir}.\n"
    error="${error}Set the environment variable CUDA_TEMP_DIR to a location with adequate space to pass this check."
    error="${error}You can alternatively set EASYBUILD_BUILDPATH and/or EASYBUILD_SOURCEPATH "
    error="${error}to reduce this requirement. Exiting now..."
    fatal_error "${error}"
  fi

  if ! command -v "eb" &>/dev/null; then
    echo_yellow "Attempting to load an EasyBuild module to do actual install"
    module load EasyBuild
    # There are some scenarios where this may fail
    if [ $? -ne 0 ]; then
      error="'eb' command not found in your environment and\n"
      error="${error}  module load EasyBuild\n"
      error="${error}failed for some reason.\n"
      error="${error}Please re-run this script with the 'eb' command available."
      fatal_error "${error}"
    fi
  fi

  cudnn_easyconfig="cuDNN-${cudnn_version}-CUDA-${cuda_version}.eb"

  # Check the easyconfig file is available in the release
  # (eb search always returns 0, so we need a grep to ensure a usable exit code)
  eb --search ^${cudnn_easyconfig}|grep cuDNN > /dev/null 2>&1
  # Check the exit code
  if [ $? -ne 0 ]; then
    eb_version=$(eb --version)
    available_cudnn_easyconfigs=$(eb --search ^cuDNN-*.eb|grep cuDNN)

    error="The easyconfig ${cudnn_easyconfig} was not found in EasyBuild version:\n"
    error="${error}  ${eb_version}\n"
    error="${error}You either need to give a different version of CUDA to install _or_ \n"
    error="${error}use a different version of EasyBuild for the installation.\n"
    error="${error}\nThe versions of available with the current eb command are:\n"
    error="${error}${available_cudnn_easyconfigs}"
    fatal_error "${error}"
  fi

  # We need the --rebuild option, as the cuDNN module may or may not be on the
  # `MODULEPATH` yet. Even if it is, we still want to redo this installation
  # since it will provide the symlinked targets for the parts of the cuDNN
  # installation in the `.../versions/...` prefix
  # We install the module in our `tmpdir` since we do not need the modulefile,
  # we only care about providing the targets for the symlinks.
  extra_args="--rebuild --installpath-modules=${tmpdir}"

  # We don't want hooks used in this install, we need a vanilla cuDNN installation
  touch "$tmpdir"/none.py
  # shellcheck disable=SC2086  # Intended splitting of extra_args
  eb --prefix="$tmpdir" ${extra_args} --hooks="$tmpdir"/none.py --installpath="${cudnn_install_parent}"/ "${cudnn_easyconfig}"
  ret=$?
  if [ $ret -ne 0 ]; then
    eb_last_log=$(unset EB_VERBOSE; eb --last-log)
    cp -a ${eb_last_log} .
    fatal_error "cuDNN installation failed, please check EasyBuild logs $(basename ${eb_last_log})..."
  else
    echo_green "cuDNN installation at ${cudnn_install_parent}/software/cuDNN/${cudnn_version}-CUDA-${cuda_version} succeeded!"
  fi
  # clean up tmpdir
  rm -rf "${tmpdir}"
fi
