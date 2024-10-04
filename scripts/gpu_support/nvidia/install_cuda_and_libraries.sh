#!/usr/bin/env bash

# This script can be used to install CUDA and other libraries by NVIDIA under
# the `.../host_injections` directory.
#
# This provides the parts of the CUDA installation and other libriaries that
# cannot be redistributed as part of EESSI due to license limitations. While
# GPU-based software from EESSI will _run_ without these, installation of
# additional software that builds upon CUDA or other libraries requires that
# these installation are present under `host_injections`.
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
    echo "  --help                           Display this help message"
    echo "  --accept-cuda-eula               You _must_ accept the CUDA EULA to install"
    echo "                                   CUDA, see the EULA at"
    echo "                                   https://docs.nvidia.com/cuda/eula/index.html"
    echo "  -e, --easystack EASYSTACK_FILE   Path to easystack file that defines which"
    echo "                                   packages shall be installed"
    echo "  -t, --temp-dir /path/to/tmpdir   Specify a location to use for temporary"
    echo "                                   storage during the installation of CUDA"
    echo "                                   and/or other libraries (must have"
    echo "                                   several GB available; depends on the number of installations)"
}

# Initialize variables
eula_accepted=0
EASYSTACK_FILE=
TEMP_DIR=

# Parse command-line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)
            show_help
            exit 0
            ;;
        --accept-cuda-eula)
            eula_accepted=1
            shift 1
            ;;
        -e|--easystack)
            if [ -n "$2" ]; then
                EASYSTACK_FILE="$2"
                shift 2
            else
                echo "Error: Argument required for $1"
                show_help
                exit 1
            fi
            ;;
        -t|--temp-dir)
            if [ -n "$2" ]; then
                TEMP_DIR="$2"
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

if [[ -z "${EASYSTACK_FILE}" ]]; then
    fatal_error "Need the name/path to an easystack file. See command line options\n"
fi

# Make sure EESSI is initialised
check_eessi_initialised

# As an installation location just use $EESSI_SOFTWARE_PATH but replacing `versions` with `host_injections`
# (CUDA is a binary installation so no need to worry too much about the EasyBuild setup)
export EESSI_SITE_INSTALL=${EESSI_SOFTWARE_PATH/versions/host_injections}

# we need a directory we can use for temporary storage
if [[ -z "${TEMP_DIR}" ]]; then
    tmpdir=$(mktemp -d)
else
    mkdir -p ${TEMP_DIR}
    tmpdir=$(mktemp -d --tmpdir=${TEMP_DIR} cuda_n_co.XXX)
    if [[ ! -d "$tmpdir" ]] ; then
        fatal_error "Could not create directory ${tmpdir}"
    fi
fi
echo "Created temporary directory '${tmpdir}'"

echo "MODULEPATH=${MODULEPATH}"
echo "List available *CUDA* modules before loading EESSI-extend/${EESSI_VERSION}-easybuild"
module avail CUDA

# load EESSI-extend/2023.06-easybuild module && verify that it is loaded
EESSI_EXTEND_MODULE="EESSI-extend/${EESSI_VERSION}-easybuild"
module load ${EESSI_EXTEND_MODULE}
ret=$?
if [ "${ret}" -ne 0 ]; then
    fatal_error "An error occured while trying to load ${EESSI_EXTEND_MODULE}\n"
fi

echo "MODULEPATH=${MODULEPATH}"
echo "List available *CUDA* modules after loading EESSI-extend/${EESSI_VERSION}-easybuild"
module avail CUDA

# use install_path/modules/all as MODULEPATH
SAVE_MODULEPATH=${MODULEPATH}
MODULEPATH=${EASYBUILD_INSTALLPATH}/.modules/all
echo "set MODULEPATH=${MODULEPATH}"

# show EasyBuild configuration
echo "Show EasyBuild configuration"
eb --show-config

# do a 'eb --dry-run-short' with the EASYSTACK_FILE and determine list of packages
# to be installed
echo ">> Determining if packages specified in ${EASYSTACK_FILE} are missing under ${EESSI_SITE_INSTALL}"
eb_dry_run_short_out=${tmpdir}/eb_dry_run_short.out
eb --dry-run-short --rebuild --easystack ${EASYSTACK_FILE} 2>&1 | tee ${eb_dry_run_short_out}
ret=$?

# Check if CUDA shall be installed
cuda_install_needed=0
cat ${eb_dry_run_short_out} | grep "^ \* \[[xR]\]" | grep "module: CUDA/"
ret=$?
if [ "${ret}" -eq 0 ]; then
    cuda_install_needed=1
fi

# Make sure the CUDA EULA is accepted if it shall be installed
if [ "${cuda_install_needed}" -eq 1 ] && [ "${eula_accepted}" -ne 1 ]; then
  show_help
  error="\nCUDA shall be installed. However, the CUDA EULA has not been accepted\nYou _must_ accept the CUDA EULA via the appropriate command line option.\n"
  fatal_error "${error}"
fi

# determine the number of packages to be installed (assume 5 GB + num_packages *
# 3GB space needed)
number_of_packages=$(cat ${eb_dry_run_short_out} | grep "^ \* \[[ ]\]" | sed -e 's/^.*module: //' | sort -u | wc -l)
echo "number of packages to be (re-)installed: '${number_of_packages}'"
base_storage_space=$((5000000 + ${number_of_packages} * 3000000))

required_space_in_tmpdir=${base_storage_space}
# Let's see if we have sources and build locations defined if not, we use the temporary space
if [[ -z "${EASYBUILD_BUILDPATH}" ]]; then
  export EASYBUILD_BUILDPATH=${tmpdir}/build
  required_space_in_tmpdir=$((required_space_in_tmpdir + ${base_storage_space}))
fi
if [[ -z "${EASYBUILD_SOURCEPATH}" ]]; then
  export EASYBUILD_SOURCEPATH=${tmpdir}/sources
  required_space_in_tmpdir=$((required_space_in_tmpdir + ${base_storage_space}))
fi

# The install is pretty fat, you need lots of space for download/unpack/install
# (~3*${base_storage_space}*1000 Bytes),
# need to do a space check before we proceed
avail_space=$(df --output=avail "${EESSI_SITE_INSTALL}"/ | tail -n 1 | awk '{print $1}')
min_disk_storage=$((3 * ${base_storage_space}))
if (( avail_space < ${min_disk_storage} )); then
  fatal_error "Need at least $(echo "${min_disk_storage} / 1000000" | bc) GB disk space to install CUDA and other libraries under ${EESSI_SITE_INSTALL}, exiting now..."
fi
avail_space=$(df --output=avail "${tmpdir}"/ | tail -n 1 | awk '{print $1}')
if (( avail_space < required_space_in_tmpdir )); then
  error="Need at least $(echo "${required_space_in_tmpdir} / 1000000" | bc) temporary disk space under ${tmpdir}.\n"
  error="${error}Set the environment variable TEMP_DIR to a location with adequate space to pass this check."
  error="${error}You can alternatively set EASYBUILD_BUILDPATH and/or EASYBUILD_SOURCEPATH"
  error="${error}to reduce this requirement. Exiting now..."
  fatal_error "${error}"
fi

# Brief explanation of parameters:
#  - prefix: using $tmpdir as default base directory for several EB settings
#  - rebuild: we need the --rebuild option, as the CUDA module may or may not be on the
#        `MODULEPATH` yet. Even if it is, we still want to redo this installation
#        since it will provide the symlinked targets for the parts of the CUDA
#        and/or other installation in the `.../versions/...` prefix
#  - installpath-modules: We install the module in our `tmpdir` since we do not need the modulefile,
#        we only care about providing the targets for the symlinks.
#  - ${accept_eula_opt}: We only set the --accept-eula-for=CUDA option if CUDA will be installed and if
#        this script was called with the argument --accept-cuda-eula.
#  - hooks: We don't want hooks used in this install, we need vanilla
#        installations of CUDA and/or other libraries
#  - easystack: Path to easystack file that defines which packages shall be
#        installed
accept_eula_opt=
if [[ ${eula_accepted} -eq 1 ]]; then
    accept_eula_opt="--accept-eula-for=CUDA"
fi
touch "$tmpdir"/none.py
eb --prefix="$tmpdir" \
   --rebuild \
   --installpath-modules=${EASYBUILD_INSTALLPATH}/.modules \
   "${accept_eula_opt}" \
   --hooks="$tmpdir"/none.py \
   --easystack ${EASYSTACK_FILE}
ret=$?
if [ $ret -ne 0 ]; then
  eb_last_log=$(unset EB_VERBOSE; eb --last-log)
  cp -a ${eb_last_log} .
  fatal_error "some installation failed, please check EasyBuild logs ${PWD}/$(basename ${eb_last_log})..."
else
  echo_green "all installations at ${EESSI_SITE_INSTALL}/software/... succeeded!"
fi
# clean up tmpdir
rm -rf "${tmpdir}"
