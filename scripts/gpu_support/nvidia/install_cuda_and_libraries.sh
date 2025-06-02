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
    echo "  --accept-cudnn-eula              You _must_ accept the cuDNN EULA to install"
    echo "                                   cuDNN, see the EULA at"
    echo "                                   https://docs.nvidia.com/deeplearning/cudnn/latest/reference/eula.html"
    echo "  -t, --temp-dir /path/to/tmpdir   Specify a location to use for temporary"
    echo "                                   storage during the installation of CUDA"
    echo "                                   and/or other libraries (must have"
    echo "                                   several GB available; depends on the number of installations)"
}

# Initialize variables
cuda_eula_accepted=0
cudnn_eula_accepted=0
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
            cuda_eula_accepted=1
            shift 1
            ;;
        --accept-cudnn-eula)
            cudnn_eula_accepted=1
            shift 1
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

# Make sure EESSI is initialised
check_eessi_initialised

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

# Store MODULEPATH so it can be restored at the end of each loop iteration
SAVE_MODULEPATH=${MODULEPATH}

for EASYSTACK_FILE in ${TOPDIR}/easystacks/eessi-*CUDA*.yml; do
    echo -e "Processing easystack file ${easystack_file}...\n\n"

    # determine version of EasyBuild module to load based on EasyBuild version included in name of easystack file
    eb_version=$(echo ${EASYSTACK_FILE} | sed 's/.*eb-\([0-9.]*\).*.yml/\1/g')

    # Load EasyBuild version for this easystack file _before_ loading EESSI-extend
    module_avail_out=${tmpdir}/ml.out
    module avail 2>&1 | grep EasyBuild/${eb_version} &> ${module_avail_out}
    if [[ $? -eq 0 ]]; then
        echo_green ">> Found an EasyBuild/${eb_version} module"
    else
        echo_yellow ">> No EasyBuild/${eb_version} module found: skipping step to install easystack file ${easystack_file} (see output in ${module_avail_out})"
        continue
    fi
    module load EasyBuild/${eb_version}

    # Make sure EESSI-extend does a site install here
    # We need to reload it with the current environment variables set
    unset EESSI_CVMFS_INSTALL
    unset EESSI_PROJECT_INSTALL
    unset EESSI_USER_INSTALL
    export EESSI_SITE_INSTALL=1
    module unload EESSI-extend
    ml_av_eessi_extend_out=${tmpdir}/ml_av_eessi_extend.out
    # need to use --ignore_cache to avoid the case that the module was removed (to be
    # rebuilt) but it is still in the cache and the rebuild failed
    EESSI_EXTEND_VERSION=${EESSI_VERSION}-easybuild
    module --ignore_cache avail 2>&1 | grep -i EESSI-extend/${EESSI_EXTEND_VERSION} &> ${ml_av_eessi_extend_out}
    if [[ $? -eq 0 ]]; then
        echo_green ">> Module for EESSI-extend/${EESSI_EXTEND_VERSION} found!"
    else
        error="\nNo module for EESSI-extend/${EESSI_EXTEND_VERSION} found\nwhile EESSI has been initialised to use software under ${EESSI_SOFTWARE_PATH}\n"
        fatal_error "${error}"
    fi
    module --ignore_cache load EESSI-extend/${EESSI_EXTEND_VERSION}
    unset EESSI_EXTEND_VERSION

    # Install modules in hidden .modules dir to keep track of what was installed before
    # (this action is temporary, and we do not call Lmod again within the current shell context, but in EasyBuild
    # subshells, so loaded modules are not automatically unloaded)
    MODULEPATH=${EESSI_SITE_SOFTWARE_PATH}/.modules/all
    echo "set MODULEPATH=${MODULEPATH}"

    # We don't want hooks used in this install, we need vanilla installations
    touch "${tmpdir}"/none.py
    export EASYBUILD_HOOKS="${tmpdir}/none.py"
    
    # show EasyBuild configuration
    echo "Show EasyBuild configuration"
    eb --show-config

    # do a 'eb --dry-run-short' with the EASYSTACK_FILE and determine list of packages
    # to be installed
    echo ">> Determining if packages specified in ${EASYSTACK_FILE} are missing under ${EESSI_SITE_SOFTWARE_PATH}"
    eb_dry_run_short_out=${tmpdir}/eb_dry_run_short.out
    eb --dry-run-short --easystack ${EASYSTACK_FILE} 2>&1 | tee ${eb_dry_run_short_out}
    ret=$?

    # Check if CUDA shall be installed
    cuda_install_needed=0
    cat ${eb_dry_run_short_out} | grep "^ \* \[[ ]\]" | grep "module: CUDA/" > /dev/null
    ret=$?
    if [ "${ret}" -eq 0 ]; then
        cuda_install_needed=1
    fi

    # Make sure the CUDA EULA is accepted if it shall be installed
    if [ "${cuda_install_needed}" -eq 1 ] && [ "${cuda_eula_accepted}" -ne 1 ]; then
      show_help
      error="\nCUDA shall be installed. However, the CUDA EULA has not been accepted\nYou _must_ accept the CUDA EULA via the appropriate command line option.\n"
      fatal_error "${error}"
    fi

    # Check if cdDNN shall be installed
    cudnn_install_needed=0
    cat ${eb_dry_run_short_out} | grep "^ \* \[[ ]\]" | grep "module: cuDNN/" > /dev/null
    ret=$?
    if [ "${ret}" -eq 0 ]; then
        cudnn_install_needed=1
    fi

    # Make sure the cuDNN EULA is accepted if it shall be installed
    if [ "${cudnn_install_needed}" -eq 1 ] && [ "${cudnn_eula_accepted}" -ne 1 ]; then
      show_help
      error="\ncuDNN shall be installed. However, the cuDNN EULA has not been accepted\nYou _must_ accept the cuDNN EULA via the appropriate command line option.\n"
      fatal_error "${error}"
    fi

    # determine the number of packages to be installed (assume 5 GB + num_packages *
    # 3GB space needed). Both CUDA and cuDNN are about this size
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
    avail_space=$(df --output=avail "${EESSI_SITE_SOFTWARE_PATH}"/ | tail -n 1 | awk '{print $1}')
    min_disk_storage=$((3 * ${base_storage_space}))
    if (( avail_space < ${min_disk_storage} )); then
      fatal_error "Need at least $(echo "${min_disk_storage} / 1000000" | bc) GB disk space to install CUDA and other libraries under ${EESSI_SITE_SOFTWARE_PATH}, exiting now..."
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
    #  - installpath-modules: We install the module in a hidden .modules, so that next time this script
    #        is run, it is not reinstalled.
    #  - ${accept_eula_opt}: We only set the --accept-eula-for=CUDA option if CUDA will be installed and if
    #        this script was called with the argument --accept-cuda-eula.
    #  - hooks: We don't want hooks used in this install, we need vanilla
    #        installations of CUDA and/or other libraries
    #  - easystack: Path to easystack file that defines which packages shall be
    #        installed
    accept_eula_opt=
    if [[ ${cuda_eula_accepted} -eq 1 ]]; then
        accept_eula_opt="CUDA"
    fi
    if [[ ${cudnn_eula_accepted} -eq 1 ]]; then
        if [[ -z ${accept_eula_opt} ]]; then
            accept_eula_opt="cuDNN"
        else
            accept_eula_opt="${accept_eula_opt},cuDNN"
        fi
    fi
    touch "$tmpdir"/none.py
    eb_args="--prefix=$tmpdir"
    eb_args="$eb_args --installpath-modules=${EASYBUILD_INSTALLPATH}/.modules"
    eb_args="$eb_args --hooks="$tmpdir"/none.py"
    eb_args="$eb_args --easystack ${EASYSTACK_FILE}"
    if [[ ! -z ${accept_eula_opt} ]]; then
        eb_args="$eb_args --accept-eula-for=$accept_eula_opt"
    fi
    echo "Running eb $eb_args"
    eb $eb_args
    ret=$?
    if [ $ret -ne 0 ]; then
      eb_last_log=$(unset EB_VERBOSE; eb --last-log)
      cp -a ${eb_last_log} .
      fatal_error "some installation failed, please check EasyBuild logs ${PWD}/$(basename ${eb_last_log})..."
    else
      echo_green "all installations at ${EESSI_SITE_SOFTWARE_PATH}/software/... succeeded!"
    fi

    # clean up tmpdir content
    rm -rf "${tmpdir}"/*

    # Restore MODULEPATH for next loop iteration
    MODULEPATH=${SAVE_MODULEPATH}
done
# Remove the temporary directory
rm -rf "${tmpdir}"
