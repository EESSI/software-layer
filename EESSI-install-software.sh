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

function safe_module_use {
    # add a given non-empty directory to $MODULEPATH if and only if it is not yet in
    directory=${1}

    if [[ -z ${directory+x} ]]; then
        echo "safe_module_use: given directory unset or empty; not adding it to \$MODULEPATH (${MODULEPATH})"
        return
    fi
    if [[ ":${MODULEPATH}:" == *":${directory}:"* ]]; then
        echo "safe_module_use: directory '${directory}' is already in \$MODULEPATH (${MODULEPATH}); not adding it again"
        return
    else
        echo "safe_module_use: directory '${directory}' is not yet in \$MODULEPATH (${MODULEPATH}); adding it"
        module use ${directory}
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


# Get override subdir
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
  # Run in a subshell, so that minimal_eessi_env doesn't change the shell environment for the rest of this script
  (
      # Make sure EESSI_PREFIX and EESSI_OS_TYPE are set
      source $TOPDIR/init/minimal_eessi_env

      # make sure the the software and modules directory exist
      # (since it's expected by init/eessi_environment_variables when using archdetect and by the EESSI module)
      mkdir -p ${EESSI_PREFIX}/software/${EESSI_OS_TYPE}/${EESSI_SOFTWARE_SUBDIR_OVERRIDE}/{modules,software}
  )
fi

echo ">> Setting up environment..."

# If EESSI_VERSION is not set, source the defaults script to set it
if [ -z ${EESSI_VERSION} ]; then
    source $TOPDIR/init/eessi_defaults
fi

# If module command does not exist, use the one from the compat layer
command -v module
module_cmd_exists=$?
if [[ "$module_cmd_exists" -ne 0 ]]; then
    echo_green "No module command found, initializing lmod from the compatibility layer"
    # Minimal initalization of the lmod from the compat layer
    source $TOPDIR/init/lmod/bash
else
    echo_green "Module command found"
fi
ml_version_out=$TMPDIR/ml.out
ml --version &> $ml_version_out
if [[ $? -eq 0 ]]; then
    echo_green ">> Found Lmod ${LMOD_VERSION}"
else
    fatal_error "Failed to initialize Lmod?! (see output in ${ml_version_out}"
fi

# Make sure we start with no modules and clean $MODULEPATH
echo ">> Setting up \$MODULEPATH..."
module --force purge
module unuse $MODULEPATH

# Initialize the EESSI environment
module use $TOPDIR/init/modules
module load EESSI/$EESSI_VERSION

# make sure we're in Prefix environment by checking $SHELL
# We can only do this after loading the EESSI module, as we need ${EPREFIX}
if [[ ${SHELL} = ${EPREFIX}/bin/bash ]]; then
    echo_green ">> It looks like we're in a Gentoo Prefix environment, good!"
else
    fatal_error "Not running in Gentoo Prefix environment, run '${EPREFIX}/startprefix' first!"
fi

if [ -d $EESSI_CVMFS_REPO ]; then
    echo_green "$EESSI_CVMFS_REPO available, OK!"
else
    fatal_error "$EESSI_CVMFS_REPO is not available!"
fi

# Check that EESSI_SOFTWARE_SUBDIR now matches EESSI_SOFTWARE_SUBDIR_OVERRIDE
if [[ -z ${EESSI_SOFTWARE_SUBDIR} ]]; then
    fatal_error "Failed to determine software subdirectory?!"
elif [[ "${EESSI_SOFTWARE_SUBDIR}" != "${EESSI_SOFTWARE_SUBDIR_OVERRIDE}" ]]; then
    fatal_error "Values for EESSI_SOFTWARE_SUBDIR_OVERRIDE (${EESSI_SOFTWARE_SUBDIR_OVERRIDE}) and EESSI_SOFTWARE_SUBDIR (${EESSI_SOFTWARE_SUBDIR}) differ!"
else
    echo_green ">> Using ${EESSI_SOFTWARE_SUBDIR} as software subdirectory!"
fi

# avoid that pyc files for EasyBuild are stored in EasyBuild installation directory
export PYTHONPYCACHEPREFIX=$TMPDIR/pycache

# if we run the script for the first time, e.g., to start building for a new
#   stack, we need to ensure certain files are present in
#   ${EESSI_PREFIX}/software/${EESSI_OS_TYPE}/${EESSI_SOFTWARE_SUBDIR_OVERRIDE}
# - .lmod/lmodrc.lua
# - .lmod/SitePackage.lua
_eessi_software_path=${EESSI_PREFIX}/software/${EESSI_OS_TYPE}/${EESSI_SOFTWARE_SUBDIR_OVERRIDE}
_lmod_cfg_dir=${_eessi_software_path}/.lmod
_lmod_rc_file=${_lmod_cfg_dir}/lmodrc.lua
if [ ! -f ${_lmod_rc_file} ]; then
    echo "Lmod file '${_lmod_rc_file}' does not exist yet; creating it..."
    command -V python3
    python3 ${TOPDIR}/create_lmodrc.py ${_eessi_software_path}
fi
_lmod_sitepackage_file=${_lmod_cfg_dir}/SitePackage.lua
if [ ! -f ${_lmod_sitepackage_file} ]; then
    echo "Lmod file '${_lmod_sitepackage_file}' does not exist yet; creating it..."
    command -V python3
    python3 ${TOPDIR}/create_lmodsitepackage.py ${_eessi_software_path}
fi

# install any additional required scripts
# order is important: these are needed to install a full CUDA SDK in host_injections
# for now, this just reinstalls all scripts. Note the most elegant, but works

# Only run install_scripts.sh if not dev.eessi.io for security
if [[ "${EESSI_CVMFS_REPO}" != /cvmfs/dev.eessi.io ]]; then
    ${TOPDIR}/install_scripts.sh --prefix ${EESSI_PREFIX}
fi

echo ">> Configuring EasyBuild..."

# Make sure EESSI-extend is not loaded, and configure location variables for a
#   CVMFS installation
module unload EESSI-extend
unset EESSI_USER_INSTALL
unset EESSI_PROJECT_INSTALL
unset EESSI_SITE_INSTALL
export EESSI_CVMFS_INSTALL=1

# We now run 'source load_eessi_extend_module.sh' to load or install and load the
#   EESSI-extend module which sets up all build environment settings.
# The script requires the EESSI_VERSION given as argument, a couple of
#   environment variables set (TMPDIR, EB and EASYBUILD_INSTALLPATH) and the
#   function check_exit_code defined.
# NOTE 1, the script exits if those variables/functions are undefined.
# NOTE 2, loading the EESSI-extend module may adjust the value of EASYBUILD_INSTALLPATH,
#   e.g., to point to the installation directory for accelerators.
# NOTE 3, we have to set a default for EASYBUILD_INSTALLPATH here in cases the
#   EESSI-extend module itself needs to be installed.
export EASYBUILD_INSTALLPATH=${EESSI_PREFIX}/software/${EESSI_OS_TYPE}/${EESSI_SOFTWARE_SUBDIR_OVERRIDE}
echo "DEBUG: before loading EESSI-extend // EASYBUILD_INSTALLPATH='${EASYBUILD_INSTALLPATH}'"
source load_eessi_extend_module.sh ${EESSI_VERSION}
echo "DEBUG: after loading EESSI-extend //  EASYBUILD_INSTALLPATH='${EASYBUILD_INSTALLPATH}'"

# Install full CUDA SDK and cu* libraries in host_injections
# Hardcode this for now, see if it works
# TODO: We should make a nice yaml and loop over all CUDA versions in that yaml to figure out what to install
# Allow skipping CUDA SDK install in e.g. CI environments
echo "Going to install full CUDA SDK and cu* libraries under host_injections if necessary"
temp_install_storage=${TMPDIR}/temp_install_storage
mkdir -p ${temp_install_storage}
if [ -z "${skip_cuda_install}" ] || [ ! "${skip_cuda_install}" ]; then
    ${EESSI_PREFIX}/scripts/gpu_support/nvidia/install_cuda_and_libraries.sh \
        -t ${temp_install_storage} \
        --accept-cuda-eula \
        --accept-cudnn-eula
else
    echo "Skipping installation of CUDA SDK and cu* libraries in host_injections, since the --skip-cuda-install flag was passed"
fi

# Install NVIDIA drivers in host_injections (if they exist)
if command_exists "nvidia-smi"; then
    export LD_LIBRARY_PATH="/.singularity.d/libs:${LD_LIBRARY_PATH}"
    nvidia-smi --version
    ec=$?
    if [ ${ec} -eq 0 ]; then 
        echo "Command 'nvidia-smi' found. Installing NVIDIA drivers for use in prefix shell..."
        ${EESSI_PREFIX}/scripts/gpu_support/nvidia/link_nvidia_host_libraries.sh
    else
        echo "Warning: command 'nvidia-smi' found, but 'nvidia-smi --version' did not run succesfully."
        echo "This script now assumes this is NOT a GPU node."
        echo "If, and only if, the current node actually does contain Nvidia GPUs, this should be considered an error."
    fi
fi

if [ ! -z "${shared_fs_path}" ]; then
    shared_eb_sourcepath=${shared_fs_path}/easybuild/sources
    echo ">> Using ${shared_eb_sourcepath} as shared EasyBuild source path"
    export EASYBUILD_SOURCEPATH=${shared_eb_sourcepath}:${EASYBUILD_SOURCEPATH}
fi

# if an accelerator target is specified, we need to make sure that the CPU-only modules are also still available
if [ ! -z ${EESSI_ACCELERATOR_TARGET} ]; then
    CPU_ONLY_MODULES_PATH=$(echo $EASYBUILD_INSTALLPATH | sed "s@/accel/${EESSI_ACCELERATOR_TARGET}@@g")/modules/all
    if [ -d ${CPU_ONLY_MODULES_PATH} ]; then
        module use ${CPU_ONLY_MODULES_PATH}
    else
        fatal_error "Derived path to CPU-only modules does not exist: ${CPU_ONLY_MODULES_PATH}"
    fi
fi

# If in dev.eessi.io, allow building on top of software.eessi.io
if [[ "${EESSI_CVMFS_REPO}" == /cvmfs/dev.eessi.io ]]; then
    module use /cvmfs/software.eessi.io/versions/$EESSI_VERSION/software/${EESSI_OS_TYPE}/${EESSI_SOFTWARE_SUBDIR_OVERRIDE}/modules/all
fi

echo "DEBUG: adding path '$EASYBUILD_INSTALLPATH/modules/all' to MODULEPATH='${MODULEPATH}'"
#module use $EASYBUILD_INSTALLPATH/modules/all
safe_module_use $EASYBUILD_INSTALLPATH/modules/all
echo "DEBUG: after adding module path // MODULEPATH='${MODULEPATH}'"

if [[ -z ${MODULEPATH} ]]; then
    fatal_error "Failed to set up \$MODULEPATH?!"
else
    echo_green ">> MODULEPATH set up: ${MODULEPATH}"
fi

# assume there's only one diff file that corresponds to the PR patch file
pr_diff=$(ls [0-9]*.diff | head -1)


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
        eb_version=$(echo ${easystack_file} | sed 's/.*eb-\([0-9.]*\).*.yml/\1/g')

        # load EasyBuild module (will be installed if it's not available yet)
        source ${TOPDIR}/load_easybuild_module.sh ${eb_version}

        ${EB} --show-config

        echo_green "All set, let's start installing some software with EasyBuild v${eb_version} in ${EASYBUILD_INSTALLPATH}..."

        if [ -f ${easystack_file} ]; then
            echo_green "Feeding easystack file ${easystack_file} to EasyBuild..."

            if [[ ${easystack_file} == *"/rebuilds/"* ]]; then
                # the removal script should have removed the original directory and created a new and empty one
                # to work around permission issues:
                # https://github.com/EESSI/software-layer/issues/556
                echo_yellow "This is a rebuild, so using --try-amend=keeppreviousinstall=True to reuse the already created directory"
                ${EB} --easystack ${easystack_file} --robot --try-amend=keeppreviousinstall=True
            else
                ${EB} --easystack ${easystack_file} --robot
            fi
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

echo "DEBUG: before creating/updating lmod config files // EASYBUILD_INSTALLPATH='${EASYBUILD_INSTALLPATH}'"
export LMOD_CONFIG_DIR="${EASYBUILD_INSTALLPATH}/.lmod"
lmod_rc_file="$LMOD_CONFIG_DIR/lmodrc.lua"
echo "DEBUG: lmod_rc_file='${lmod_rc_file}'"
if [[ ! -z ${EESSI_ACCELERATOR_TARGET} ]]; then
    # EESSI_ACCELERATOR_TARGET is set, so let's remove the accelerator path from $lmod_rc_file
    lmod_rc_file=$(echo ${lmod_rc_file} | sed "s@/accel/${EESSI_ACCELERATOR_TARGET}@@")
    echo "Path to lmodrc.lua changed to '${lmod_rc_file}'"
fi
lmodrc_changed=$(cat ${pr_diff} | grep '^+++' | cut -f2 -d' ' | sed 's@^[a-z]/@@g' | grep '^create_lmodrc.py$' > /dev/null; echo $?)
if [ ! -f $lmod_rc_file ] || [ ${lmodrc_changed} == '0' ]; then
    echo ">> Creating/updating Lmod RC file (${lmod_rc_file})..."
    python3 $TOPDIR/create_lmodrc.py ${EASYBUILD_INSTALLPATH}
    check_exit_code $? "$lmod_rc_file created" "Failed to create $lmod_rc_file"
fi

export LMOD_PACKAGE_PATH="${EASYBUILD_INSTALLPATH}/.lmod"
lmod_sitepackage_file="$LMOD_PACKAGE_PATH/SitePackage.lua"
if [[ ! -z ${EESSI_ACCELERATOR_TARGET} ]]; then
    # EESSI_ACCELERATOR_TARGET is set, so let's remove the accelerator path from $lmod_sitepackage_file
    lmod_sitepackage_file=$(echo ${lmod_sitepackage_file} | sed "s@/accel/${EESSI_ACCELERATOR_TARGET}@@")
    echo "Path to SitePackage.lua changed to '${lmod_sitepackage_file}'"
fi
sitepackage_changed=$(cat ${pr_diff} | grep '^+++' | cut -f2 -d' ' | sed 's@^[a-z]/@@g' | grep '^create_lmodsitepackage.py$' > /dev/null; echo $?)
if [ ! -f "$lmod_sitepackage_file" ] || [ "${sitepackage_changed}" == '0' ]; then
    echo ">> Creating/updating Lmod SitePackage.lua (${lmod_sitepackage_file})..."
    python3 $TOPDIR/create_lmodsitepackage.py ${EASYBUILD_INSTALLPATH}
    check_exit_code $? "$lmod_sitepackage_file created" "Failed to create $lmod_sitepackage_file"
fi

echo ">> Cleaning up ${TMPDIR}..."
rm -r ${TMPDIR}
