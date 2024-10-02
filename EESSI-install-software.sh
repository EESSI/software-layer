#!/bin/bash
#
# Script to install EESSI software stack (version set through init/eessi_defaults)

# see example parsing of command line arguments at
#   https://wiki.bash-hackers.org/scripting/posparams#using_a_while_loop
#   https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

display_help() {
  echo "usage: $0 [OPTIONS]"
  echo "  --build-logs-dir       -  location to copy EasyBuild logs to for failed builds"
  echo "  -g | --generic         -  instructs script to build for generic architecture target"
  echo "  -h | --help            -  display this usage information"
  echo "  -x | --http-proxy URL  -  provides URL for the environment variable http_proxy"
  echo "  -y | --https-proxy URL -  provides URL for the environment variable https_proxy"
  echo "  --shared-fs-path       -  path to directory on shared filesystem that can be used"
  echo "  --skip-cuda-install    -  disable installing a full CUDA SDK in the host_injections prefix (e.g. in CI)"
}

# Function to check if a command exists
function command_exists() {
    command -v "$1" >/dev/null 2>&1
}

function copy_build_log() {
    # copy specified build log to specified directory, with some context added
    build_log=${1}
    build_logs_dir=${2}

    # also copy to build logs directory, if specified
    if [ ! -z "${build_logs_dir}" ]; then
        log_filename="$(basename ${build_log})"
        if [ ! -z "${SLURM_JOB_ID}" ]; then
            # use subdirectory for build log in context of a Slurm job
            build_log_path="${build_logs_dir}/jobs/${SLURM_JOB_ID}/${log_filename}"
        else
            build_log_path="${build_logs_dir}/non-jobs/${log_filename}"
        fi
        mkdir -p $(dirname ${build_log_path})
        cp -a ${build_log} ${build_log_path}
        chmod 0644 ${build_log_path}

        # add context to end of copied log file
        echo >> ${build_log_path}
        echo "Context from which build log was copied:" >> ${build_log_path}
        echo "- original path of build log: ${build_log}" >> ${build_log_path}
        echo "- working directory: ${PWD}" >> ${build_log_path}
        echo "- Slurm job ID: ${SLURM_OUT}" >> ${build_log_path}
        echo "- EasyBuild version: ${eb_version}" >> ${build_log_path}
        echo "- easystack file: ${easystack_file}" >> ${build_log_path}

        echo "EasyBuild log file ${build_log} copied to ${build_log_path} (with context appended)"
    fi
}

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -g|--generic)
      EASYBUILD_OPTARCH="GENERIC"
      shift
      ;;
    -h|--help)
      display_help  # Call your function
      # no shifting needed here, we're done.
      exit 0
      ;;
    -x|--http-proxy)
      export http_proxy="$2"
      shift 2
      ;;
    -y|--https-proxy)
      export https_proxy="$2"
      shift 2
      ;;
    --build-logs-dir)
      export build_logs_dir="${2}"
      shift 2
      ;;
    --shared-fs-path)
      export shared_fs_path="${2}"
      shift 2
      ;;
    --skip-cuda-install)
      export skip_cuda_install=True
      shift 1
      ;;
    -*|--*)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
    *)  # No more options
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"

TOPDIR=$(dirname $(realpath $0))

source $TOPDIR/scripts/utils.sh

# honor $TMPDIR if it is already defined, use /tmp otherwise
if [ -z $TMPDIR ]; then
    export WORKDIR=/tmp/$USER
else
    export WORKDIR=$TMPDIR/$USER
fi

TMPDIR=$(mktemp -d)

echo ">> Setting up environment..."

source $TOPDIR/init/minimal_eessi_env

if [ -d $EESSI_CVMFS_REPO ]; then
    echo_green "$EESSI_CVMFS_REPO available, OK!"
else
    fatal_error "$EESSI_CVMFS_REPO is not available!"
fi

# make sure we're in Prefix environment by checking $SHELL
if [[ ${SHELL} = ${EPREFIX}/bin/bash ]]; then
    echo_green ">> It looks like we're in a Gentoo Prefix environment, good!"
else
    fatal_error "Not running in Gentoo Prefix environment, run '${EPREFIX}/startprefix' first!"
fi

# avoid that pyc files for EasyBuild are stored in EasyBuild installation directory
export PYTHONPYCACHEPREFIX=$TMPDIR/pycache

DETECTION_PARAMETERS=''
GENERIC=0
EB='eb'
if [[ "$EASYBUILD_OPTARCH" == "GENERIC" ]]; then
    echo_yellow ">> GENERIC build requested, taking appropriate measures!"
    DETECTION_PARAMETERS="$DETECTION_PARAMETERS --generic"
    GENERIC=1
    EB='eb --optarch=GENERIC'
fi

echo ">> Determining software subdirectory to use for current build host..."
if [ -z $EESSI_SOFTWARE_SUBDIR_OVERRIDE ]; then
  export EESSI_SOFTWARE_SUBDIR_OVERRIDE=$(python3 $TOPDIR/eessi_software_subdir.py $DETECTION_PARAMETERS)
  echo ">> Determined \$EESSI_SOFTWARE_SUBDIR_OVERRIDE via 'eessi_software_subdir.py $DETECTION_PARAMETERS' script"
else
  echo ">> Picking up pre-defined \$EESSI_SOFTWARE_SUBDIR_OVERRIDE: ${EESSI_SOFTWARE_SUBDIR_OVERRIDE}"
  # make sure directory exists (since it's expected by init/eessi_environment_variables when using archdetect)
  mkdir -p ${EESSI_PREFIX}/software/${EESSI_OS_TYPE}/${EESSI_SOFTWARE_SUBDIR_OVERRIDE}
fi

# if we run the script for the first time, e.g., to start building for a new
#   stack, we need to ensure certain files are present in
#   ${EESSI_PREFIX}/software/${EESSI_OS_TYPE}/${EESSI_SOFTWARE_SUBDIR_OVERRIDE}
# - .lmod/lmodrc.lua
# - .lmod/SitePackage.lua
_eessi_software_path=${EESSI_PREFIX}/software/${EESSI_OS_TYPE}/${EESSI_SOFTWARE_SUBDIR_OVERRIDE}
_lmod_cfg_dir=${_eessi_software_path}/.lmod
_lmod_rc_file=${_lmod_cfg_dir}/lmodrc.lua
if [ ! -f ${_lmod_rc_file} ]; then
    command -V python3
    python3 ${TOPDIR}/create_lmodrc.py ${_eessi_software_path}
fi
_lmod_sitepackage_file=${_lmod_cfg_dir}/SitePackage.lua
if [ ! -f ${_lmod_sitepackage_file} ]; then
    command -V python3
    python3 ${TOPDIR}/create_lmodsitepackage.py ${_eessi_software_path}
fi

# Set all the EESSI environment variables (respecting $EESSI_SOFTWARE_SUBDIR_OVERRIDE)
# $EESSI_SILENT - don't print any messages
# $EESSI_BASIC_ENV - give a basic set of environment variables
EESSI_SILENT=1 EESSI_BASIC_ENV=1 source $TOPDIR/init/eessi_environment_variables

if [[ -z ${EESSI_SOFTWARE_SUBDIR} ]]; then
    fatal_error "Failed to determine software subdirectory?!"
elif [[ "${EESSI_SOFTWARE_SUBDIR}" != "${EESSI_SOFTWARE_SUBDIR_OVERRIDE}" ]]; then
    fatal_error "Values for EESSI_SOFTWARE_SUBDIR_OVERRIDE (${EESSI_SOFTWARE_SUBDIR_OVERRIDE}) and EESSI_SOFTWARE_SUBDIR (${EESSI_SOFTWARE_SUBDIR}) differ!"
else
    echo_green ">> Using ${EESSI_SOFTWARE_SUBDIR} as software subdirectory!"
fi

echo ">> Initializing Lmod..."
source $EPREFIX/usr/share/Lmod/init/bash
ml_version_out=$TMPDIR/ml.out
ml --version &> $ml_version_out
if [[ $? -eq 0 ]]; then
    echo_green ">> Found Lmod ${LMOD_VERSION}"
else
    fatal_error "Failed to initialize Lmod?! (see output in ${ml_version_out}"
fi

echo ">> Configuring EasyBuild..."
source $TOPDIR/configure_easybuild

if [ ! -z "${shared_fs_path}" ]; then
    shared_eb_sourcepath=${shared_fs_path}/easybuild/sources
    echo ">> Using ${shared_eb_sourcepath} as shared EasyBuild source path"
    export EASYBUILD_SOURCEPATH=${shared_eb_sourcepath}:${EASYBUILD_SOURCEPATH}
fi

echo ">> Setting up \$MODULEPATH..."
# make sure no modules are loaded
module --force purge
# ignore current $MODULEPATH entirely
module unuse $MODULEPATH

# if an accelerator target is specified, we need to make sure that the CPU-only modules are also still available
if [ ! -z ${EESSI_ACCELERATOR_TARGET} ]; then
    CPU_ONLY_MODULES_PATH=$(echo $EASYBUILD_INSTALLPATH | sed "s@/accel/${EESSI_ACCELERATOR_TARGET}@@g")/modules/all
    if [ -d ${CPU_ONLY_MODULES_PATH} ]; then
        module use ${CPU_ONLY_MODULES_PATH}
    else
        fatal_error "Derived path to CPU-only modules does not exist: ${CPU_ONLY_MODULES_PATH}"
    fi
fi

# If in dev.eessi.io, allow building on top of softw
if [[ "${EESSI_CVMFS_REPO}" == /cvmfs/dev.eessi.io ]]; then
    module use /cvmfs/software.eessi.io/versions/$EESSI_VERSION/software/${EESSI_OS_TYPE}/${EESSI_SOFTWARE_SUBDIR_OVERRIDE}/modules/all
fi

module use $EASYBUILD_INSTALLPATH/modules/all

if [[ -z ${MODULEPATH} ]]; then
    fatal_error "Failed to set up \$MODULEPATH?!"
else
    echo_green ">> MODULEPATH set up: ${MODULEPATH}"
fi

# assume there's only one diff file that corresponds to the PR patch file
pr_diff=$(ls [0-9]*.diff | head -1)

# install any additional required scripts
# order is important: these are needed to install a full CUDA SDK in host_injections
# for now, this just reinstalls all scripts. Note the most elegant, but works

# Only run install_scripts.sh if not dev.eessi.io for security
if [[ "${EESSI_CVMFS_REPO}" != /cvmfs/dev.eessi.io ]]; then
    ${TOPDIR}/install_scripts.sh --prefix ${EESSI_PREFIX}
fi

# Install full CUDA SDK in host_injections
# Hardcode this for now, see if it works
# TODO: We should make a nice yaml and loop over all CUDA versions in that yaml to figure out what to install
# Allow skipping CUDA SDK install in e.g. CI environments
# The install_cuda... script uses EasyBuild. So, we need to check if we have EB
# or skip this step.
module_avail_out=$TMPDIR/ml.out
module avail 2>&1 | grep EasyBuild &> ${module_avail_out}
if [[ $? -eq 0 ]]; then
    echo_green ">> Found an EasyBuild module"
else
    echo_yellow ">> No EasyBuild module found: skipping step to install CUDA (see output in ${module_avail_out})"
    export skip_cuda_install=True
fi

if [ -z "${skip_cuda_install}" ] || [ ! "${skip_cuda_install}" ]; then
    ${EESSI_PREFIX}/scripts/gpu_support/nvidia/install_cuda_host_injections.sh -c 12.1.1 --accept-cuda-eula
else
    echo "Skipping installation of CUDA SDK in host_injections, since the --skip-cuda-install flag was passed OR no EasyBuild module was found"
fi

# Install NVIDIA drivers in host_injections (if they exist)
if command_exists "nvidia-smi"; then
    echo "Command 'nvidia-smi' found. Installing NVIDIA drivers for use in prefix shell..."
    ${EESSI_PREFIX}/scripts/gpu_support/nvidia/link_nvidia_host_libraries.sh
fi

# use PR patch file to determine in which easystack files stuff was added
changed_easystacks=$(cat ${pr_diff} | grep '^+++' | cut -f2 -d' ' | sed 's@^[a-z]/@@g' | grep 'easystacks/.*yml$' | egrep -v 'known-issues|missing') 
if [ -z "${changed_easystacks}" ]; then
    echo "No missing installations, party time!"  # Ensure the bot report success, as there was nothing to be build here
else

    # first process rebuilds, if any, then easystack files for new installations
    # "|| true" is used to make sure that the grep command always returns success
    rebuild_easystacks=$(echo "${changed_easystacks}" | (grep "/rebuilds/" || true))
    new_easystacks=$(echo "${changed_easystacks}" | (grep -v "/rebuilds/" || true))
    for easystack_file in ${rebuild_easystacks} ${new_easystacks}; do

        echo -e "Processing easystack file ${easystack_file}...\n\n"

        # determine version of EasyBuild module to load based on EasyBuild version included in name of easystack file
        eb_version=$(echo ${easystack_file} | sed 's/.*eb-\([0-9.]*\).*/\1/g')

        # load EasyBuild module (will be installed if it's not available yet)
        source ${TOPDIR}/load_easybuild_module.sh ${eb_version}

        ${EB} --show-config

        echo_green "All set, let's start installing some software with EasyBuild v${eb_version} in ${EASYBUILD_INSTALLPATH}..."

        if [ -f ${easystack_file} ]; then
            echo_green "Feeding easystack file ${easystack_file} to EasyBuild..."

            ${EB} --easystack ${easystack_file} --robot
            ec=$?

            # copy EasyBuild log file if EasyBuild exited with an error
            if [ ${ec} -ne 0 ]; then
                eb_last_log=$(unset EB_VERBOSE; eb --last-log)
                # copy to current working directory
                cp -a ${eb_last_log} .
                echo "Last EasyBuild log file copied from ${eb_last_log} to ${PWD}"
                # copy to build logs dir (with context added)
                copy_build_log "${eb_last_log}" "${build_logs_dir}"
            fi
    
            $TOPDIR/check_missing_installations.sh ${easystack_file} ${pr_diff}
        else
            fatal_error "Easystack file ${easystack_file} not found!"
        fi

    done
fi

echo ">> Creating/updating Lmod RC file..."
export LMOD_CONFIG_DIR="${EASYBUILD_INSTALLPATH}/.lmod"
lmod_rc_file="$LMOD_CONFIG_DIR/lmodrc.lua"
lmodrc_changed=$(cat ${pr_diff} | grep '^+++' | cut -f2 -d' ' | sed 's@^[a-z]/@@g' | grep '^create_lmodrc.py$' > /dev/null; echo $?)
if [ ! -f $lmod_rc_file ] || [ ${lmodrc_changed} == '0' ]; then
    python3 $TOPDIR/create_lmodrc.py ${EASYBUILD_INSTALLPATH}
    check_exit_code $? "$lmod_rc_file created" "Failed to create $lmod_rc_file"
fi

echo ">> Creating/updating Lmod SitePackage.lua ..."
export LMOD_PACKAGE_PATH="${EASYBUILD_INSTALLPATH}/.lmod"
lmod_sitepackage_file="$LMOD_PACKAGE_PATH/SitePackage.lua"
sitepackage_changed=$(cat ${pr_diff} | grep '^+++' | cut -f2 -d' ' | sed 's@^[a-z]/@@g' | grep '^create_lmodsitepackage.py$' > /dev/null; echo $?)
if [ ! -f "$lmod_sitepackage_file" ] || [ "${sitepackage_changed}" == '0' ]; then
    python3 $TOPDIR/create_lmodsitepackage.py ${EASYBUILD_INSTALLPATH}
    check_exit_code $? "$lmod_sitepackage_file created" "Failed to create $lmod_sitepackage_file"
fi

echo ">> Cleaning up ${TMPDIR}..."
rm -r ${TMPDIR}
