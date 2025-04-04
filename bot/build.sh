#!/usr/bin/env bash
#
# script to build the EESSI software layer. Intended use is that it is called
# by a (batch) job running on a compute node.
#
# This script is part of the EESSI software layer, see
# https://github.com/EESSI/software-layer.git
#
# author: Thomas Roeblitz (@trz42)
#
# license: GPLv2
#

# ASSUMPTIONs:
#  - working directory has been prepared by the bot with a checkout of a
#    pull request (OR by some other means)
#  - the working directory contains a directory 'cfg' where the main config
#    file 'job.cfg' has been deposited
#  - the directory may contain any additional files referenced in job.cfg

# stop as soon as something fails
set -e

# Make sure we are referring to software-layer as working directory
software_layer_dir=$(dirname $(dirname $(realpath $0)))
# source utils.sh and cfg_files.sh
source $software_layer_dir/scripts/utils.sh
source $software_layer_dir/scripts/cfg_files.sh

# defaults
export JOB_CFG_FILE="${JOB_CFG_FILE_OVERRIDE:=cfg/job.cfg}"
HOST_ARCH=$(uname -m)

# check if ${JOB_CFG_FILE} exists
if [[ ! -r "${JOB_CFG_FILE}" ]]; then
    fatal_error "job config file (JOB_CFG_FILE=${JOB_CFG_FILE}) does not exist or not readable"
fi
echo "bot/build.sh: showing ${JOB_CFG_FILE} from software-layer side"
cat ${JOB_CFG_FILE}

echo "bot/build.sh: obtaining configuration settings from '${JOB_CFG_FILE}'"
cfg_load ${JOB_CFG_FILE}

# if http_proxy is defined in ${JOB_CFG_FILE} use it, if not use env var $http_proxy
HTTP_PROXY=$(cfg_get_value "site_config" "http_proxy")
HTTP_PROXY=${HTTP_PROXY:-${http_proxy}}
echo "bot/build.sh: HTTP_PROXY='${HTTP_PROXY}'"

# if https_proxy is defined in ${JOB_CFG_FILE} use it, if not use env var $https_proxy
HTTPS_PROXY=$(cfg_get_value "site_config" "https_proxy")
HTTPS_PROXY=${HTTPS_PROXY:-${https_proxy}}
echo "bot/build.sh: HTTPS_PROXY='${HTTPS_PROXY}'"

LOCAL_TMP=$(cfg_get_value "site_config" "local_tmp")
echo "bot/build.sh: LOCAL_TMP='${LOCAL_TMP}'"
# TODO should local_tmp be mandatory? --> then we check here and exit if it is not provided

# check if path to copy build logs to is specified, so we can copy build logs for failing builds there
BUILD_LOGS_DIR=$(cfg_get_value "site_config" "build_logs_dir")
echo "bot/build.sh: BUILD_LOGS_DIR='${BUILD_LOGS_DIR}'"
# if $BUILD_LOGS_DIR is set, add it to $SINGULARITY_BIND so the path is available in the build container
if [[ ! -z ${BUILD_LOGS_DIR} ]]; then
    mkdir -p ${BUILD_LOGS_DIR}
    if [[ -z ${SINGULARITY_BIND} ]]; then
        export SINGULARITY_BIND="${BUILD_LOGS_DIR}"
    else
        export SINGULARITY_BIND="${SINGULARITY_BIND},${BUILD_LOGS_DIR}"
    fi
fi

# check if path to directory on shared filesystem is specified,
# and use it as location for source tarballs used by EasyBuild if so
SHARED_FS_PATH=$(cfg_get_value "site_config" "shared_fs_path")
echo "bot/build.sh: SHARED_FS_PATH='${SHARED_FS_PATH}'"
# if $SHARED_FS_PATH is set, add it to $SINGULARITY_BIND so the path is available in the build container
if [[ ! -z ${SHARED_FS_PATH} ]]; then
    mkdir -p ${SHARED_FS_PATH}
    if [[ -z ${SINGULARITY_BIND} ]]; then
        export SINGULARITY_BIND="${SHARED_FS_PATH}"
    else
        export SINGULARITY_BIND="${SINGULARITY_BIND},${SHARED_FS_PATH}"
    fi
fi

SINGULARITY_CACHEDIR=$(cfg_get_value "site_config" "container_cachedir")
echo "bot/build.sh: SINGULARITY_CACHEDIR='${SINGULARITY_CACHEDIR}'"
if [[ ! -z ${SINGULARITY_CACHEDIR} ]]; then
    # make sure that separate directories are used for different CPU families
    SINGULARITY_CACHEDIR=${SINGULARITY_CACHEDIR}/${HOST_ARCH}
    export SINGULARITY_CACHEDIR
fi

if [[ -z "${TMPDIR}" ]]; then
    echo -n "setting \$STORAGE by replacing any var in '${LOCAL_TMP}' -> "
    # replace any env variable in ${LOCAL_TMP} with its
    #   current value (e.g., a value that is local to the job)
    STORAGE=$(envsubst <<< ${LOCAL_TMP})
else
    STORAGE=${TMPDIR}
fi
echo "bot/build.sh: STORAGE='${STORAGE}'"

# make sure ${STORAGE} exists
mkdir -p ${STORAGE}

# make sure the base tmp storage is unique
JOB_STORAGE=$(mktemp --directory --tmpdir=${STORAGE} bot_job_tmp_XXX)
echo "bot/build.sh: created unique base tmp storage directory at ${JOB_STORAGE}"

# obtain list of modules to be loaded
LOAD_MODULES=$(cfg_get_value "site_config" "load_modules")
echo "bot/build.sh: LOAD_MODULES='${LOAD_MODULES}'"

# singularity/apptainer settings: CONTAINER, HOME, TMPDIR, BIND
CONTAINER=$(cfg_get_value "repository" "container")
export SINGULARITY_HOME="${PWD}:/eessi_bot_job"
export SINGULARITY_TMPDIR="${JOB_STORAGE}/singularity_tmpdir"
mkdir -p ${SINGULARITY_TMPDIR}

# load modules if LOAD_MODULES is not empty
if [[ ! -z ${LOAD_MODULES} ]]; then
    IFS=',' read -r -a modules <<< "$(echo "${LOAD_MODULES}")"
    for mod in "${modules[@]}";
    do
        echo "bot/build.sh: loading module '${mod}'"
        module load ${mod}
    done
else
    echo "bot/build.sh: no modules to be loaded"
fi

# determine repository to be used from entry .repository in ${JOB_CFG_FILE}
REPOSITORY_ID=$(cfg_get_value "repository" "repo_id")
REPOSITORY_NAME=$(cfg_get_value "repository" "repo_name")
REPOSITORY_VERSION=$(cfg_get_value "repository" "repo_version")
EESSI_REPOS_CFG_DIR_OVERRIDE=$(cfg_get_value "repository" "repos_cfg_dir")
export EESSI_REPOS_CFG_DIR_OVERRIDE=${EESSI_REPOS_CFG_DIR_OVERRIDE:-${PWD}/cfg}
echo "bot/build.sh: EESSI_REPOS_CFG_DIR_OVERRIDE='${EESSI_REPOS_CFG_DIR_OVERRIDE}'"

# determine EESSI version to be used from .repository.repo_version in ${JOB_CFG_FILE}
# here, just set & export EESSI_VERSION_OVERRIDE
# next script (eessi_container.sh) makes use of it via sourcing init scripts
# (e.g., init/eessi_defaults or init/minimal_eessi_env)
export EESSI_VERSION_OVERRIDE=${REPOSITORY_VERSION}
echo "bot/build.sh: EESSI_VERSION_OVERRIDE='${EESSI_VERSION_OVERRIDE}'"

# determine CVMFS repo to be used from .repository.repo_name in ${JOB_CFG_FILE}
# here, just set EESSI_CVMFS_REPO_OVERRIDE, a bit further down
# "source init/eessi_defaults" via sourcing init/minimal_eessi_env
export EESSI_CVMFS_REPO_OVERRIDE=/cvmfs/${REPOSITORY_NAME}
echo "bot/build.sh: EESSI_CVMFS_REPO_OVERRIDE='${EESSI_CVMFS_REPO_OVERRIDE}'"

# determine CPU architecture to be used from entry .architecture in ${JOB_CFG_FILE}
# fallbacks:
#  - ${CPU_TARGET} handed over from bot
#  - left empty to let downstream script(s) determine subdir to be used
EESSI_SOFTWARE_SUBDIR_OVERRIDE=$(cfg_get_value "architecture" "software_subdir")
EESSI_SOFTWARE_SUBDIR_OVERRIDE=${EESSI_SOFTWARE_SUBDIR_OVERRIDE:-${CPU_TARGET}}
export EESSI_SOFTWARE_SUBDIR_OVERRIDE
echo "bot/build.sh: EESSI_SOFTWARE_SUBDIR_OVERRIDE='${EESSI_SOFTWARE_SUBDIR_OVERRIDE}'"

# determine accelerator target (if any) from .architecture in ${JOB_CFG_FILE}
export EESSI_ACCELERATOR_TARGET=$(cfg_get_value "architecture" "accelerator")
echo "bot/build.sh: EESSI_ACCELERATOR_TARGET='${EESSI_ACCELERATOR_TARGET}'"

# get EESSI_OS_TYPE from .architecture.os_type in ${JOB_CFG_FILE} (default: linux)
EESSI_OS_TYPE=$(cfg_get_value "architecture" "os_type")
export EESSI_OS_TYPE=${EESSI_OS_TYPE:-linux}
echo "bot/build.sh: EESSI_OS_TYPE='${EESSI_OS_TYPE}'"

# prepare arguments to eessi_container.sh common to build and tarball steps
declare -a COMMON_ARGS=()
COMMON_ARGS+=("--verbose")
COMMON_ARGS+=("--access" "rw")
COMMON_ARGS+=("--mode" "run")
[[ ! -z ${CONTAINER} ]] && COMMON_ARGS+=("--container" "${CONTAINER}")
[[ ! -z ${HTTP_PROXY} ]] && COMMON_ARGS+=("--http-proxy" "${HTTP_PROXY}")
[[ ! -z ${HTTPS_PROXY} ]] && COMMON_ARGS+=("--https-proxy" "${HTTPS_PROXY}")
[[ ! -z ${REPOSITORY_ID} ]] && COMMON_ARGS+=("--repository" "${REPOSITORY_ID}")

# Also expose software.eessi.io when configured for dev.eessi.io
# Need software.eessi.io for the compat layer
if [[ "${REPOSITORY_NAME}" == "dev.eessi.io" ]]; then
    COMMON_ARGS+=("--repository" "software.eessi.io,access=ro")
fi

# add $software_layer_dir and /dev as extra bind paths
#  - $software_layer_dir is needed because it is used as prefix for running scripts
#  - /dev is needed to access /dev/fuse
COMMON_ARGS+=("--extra-bind-paths" "${software_layer_dir},/dev")

# pass through '--contain' to avoid leaking in scripts into the container session
# note, --pass-through can be used multiple times if needed
COMMON_ARGS+=("--pass-through" "--contain")

# make sure to use the same parent dir for storing tarballs of tmp
PREVIOUS_TMP_DIR=${PWD}/previous_tmp

# prepare arguments to install_software_layer.sh (specific to build step)
declare -a BUILD_STEP_ARGS=()
declare -a INSTALL_SCRIPT_ARGS=()
declare -a REMOVAL_SCRIPT_ARGS=()
if [[ ${EESSI_SOFTWARE_SUBDIR_OVERRIDE} =~ .*/generic$ ]]; then
    INSTALL_SCRIPT_ARGS+=("--generic")
    REMOVAL_SCRIPT_ARGS+=("--generic")
fi
[[ ! -z ${BUILD_LOGS_DIR} ]] && INSTALL_SCRIPT_ARGS+=("--build-logs-dir" "${BUILD_LOGS_DIR}")
[[ ! -z ${SHARED_FS_PATH} ]] && INSTALL_SCRIPT_ARGS+=("--shared-fs-path" "${SHARED_FS_PATH}")

# Skip CUDA installation for riscv.eessi.io
if [[ "${REPOSITORY_NAME}" == "riscv.eessi.io" ]]; then
    echo "bot/build.sh: disabling CUDA installation for RISC-V repository (${REPOSITORY_NAME})"
    INSTALL_SCRIPT_ARGS+=("--skip-cuda-install")
fi

# determine if the removal step has to be run
# assume there's only one diff file that corresponds to the PR patch file
pr_diff=$(ls [0-9]*.diff | head -1)
# the true at the end of the next command is important: grep will expectedly return 1 if there is no easystack file being added under rebuilds,
# but due to "set -e" the entire script would otherwise fail
changed_easystacks_rebuilds=$(cat ${pr_diff} | grep '^+++' | cut -f2 -d' ' | sed 's@^[a-z]/@@g' | grep 'easystacks/.*yml$' | (grep "/rebuilds/" || true))
if [[ -z "${changed_easystacks_rebuilds}" ]]; then
    echo "This PR does not add any easystack files in a rebuilds subdirectory, so let's skip the removal step."
else
    # prepare directory to store tarball of tmp for removal and build steps
    TARBALL_TMP_REMOVAL_STEP_DIR=${PREVIOUS_TMP_DIR}/removal_step
    mkdir -p ${TARBALL_TMP_REMOVAL_STEP_DIR}

    # prepare arguments to eessi_container.sh specific to remove step
    declare -a REMOVAL_STEP_ARGS=()
    REMOVAL_STEP_ARGS+=("--save" "${TARBALL_TMP_REMOVAL_STEP_DIR}")
    REMOVAL_STEP_ARGS+=("--storage" "${STORAGE}")

    # add fakeroot option in order to be able to remove software, see:
    # https://github.com/EESSI/software-layer/issues/312
    REMOVAL_STEP_ARGS+=("--fakeroot")

    # create tmp file for output of removal step
    removal_outerr=$(mktemp remove.outerr.XXXX)

    echo "Executing command to remove software:"
    echo "$software_layer_dir/eessi_container.sh ${COMMON_ARGS[@]} ${REMOVAL_STEP_ARGS[@]}"
    echo "                     -- $software_layer_dir/EESSI-remove-software.sh \"${REMOVAL_SCRIPT_ARGS[@]}\" \"$@\" 2>&1 | tee -a ${removal_outerr}"
    $software_layer_dir/eessi_container.sh "${COMMON_ARGS[@]}" "${REMOVAL_STEP_ARGS[@]}" \
                         -- $software_layer_dir/EESSI-remove-software.sh "${REMOVAL_SCRIPT_ARGS[@]}" "$@" 2>&1 | tee -a ${removal_outerr}

    # make sure that the build step resumes from the same temporary directory
    # this is important, as otherwise the removed software will still be there
    REMOVAL_TMPDIR=$(grep ' as tmp directory ' ${removal_outerr} | cut -d ' ' -f 2)
    BUILD_STEP_ARGS+=("--resume" "${REMOVAL_TMPDIR}")
fi

# prepare directory to store tarball of tmp for build step
TARBALL_TMP_BUILD_STEP_DIR=${PREVIOUS_TMP_DIR}/build_step
mkdir -p ${TARBALL_TMP_BUILD_STEP_DIR}

# prepare arguments to eessi_container.sh specific to build step
BUILD_STEP_ARGS+=("--save" "${TARBALL_TMP_BUILD_STEP_DIR}")
BUILD_STEP_ARGS+=("--storage" "${STORAGE}")

# add options required to handle NVIDIA support
if command_exists "nvidia-smi"; then
    # Accept that this may fail
    set +e
    nvidia-smi --version
    ec=$?
    set -e
    if [ ${ec} -eq 0 ]; then
        echo "Command 'nvidia-smi' found, using available GPU"
        BUILD_STEP_ARGS+=("--nvidia" "all")
    else
        echo "Warning: command 'nvidia-smi' found, but 'nvidia-smi --version' did not run succesfully."
        echo "This script now assumes this is NOT a GPU node."
        echo "If, and only if, the current node actually does contain Nvidia GPUs, this should be considered an error."
        BUILD_STEP_ARGS+=("--nvidia" "install")
    fi
else
    echo "No 'nvidia-smi' found, no available GPU but allowing overriding this check"
    BUILD_STEP_ARGS+=("--nvidia" "install")
fi

# Retain location for host injections so we don't reinstall CUDA
# (Always need to run the driver installation as available driver may change)
if [[ ! -z ${SHARED_FS_PATH} ]]; then
    BUILD_STEP_ARGS+=("--host-injections" "${SHARED_FS_PATH}/host-injections")
fi

# create tmp file for output of build step
build_outerr=$(mktemp build.outerr.XXXX)

echo "Executing command to build software:"
echo "$software_layer_dir/eessi_container.sh ${COMMON_ARGS[@]} ${BUILD_STEP_ARGS[@]}"
echo "                     -- $software_layer_dir/install_software_layer.sh \"${INSTALL_SCRIPT_ARGS[@]}\" \"$@\" 2>&1 | tee -a ${build_outerr}"
$software_layer_dir/eessi_container.sh "${COMMON_ARGS[@]}" "${BUILD_STEP_ARGS[@]}" \
                     -- $software_layer_dir/install_software_layer.sh "${INSTALL_SCRIPT_ARGS[@]}" "$@" 2>&1 | tee -a ${build_outerr}

# prepare directory to store tarball of tmp for tarball step
TARBALL_TMP_TARBALL_STEP_DIR=${PREVIOUS_TMP_DIR}/tarball_step
mkdir -p ${TARBALL_TMP_TARBALL_STEP_DIR}

# create tmp file for output of tarball step
tar_outerr=$(mktemp tar.outerr.XXXX)

# prepare arguments to eessi_container.sh specific to tarball step
declare -a TARBALL_STEP_ARGS=()
TARBALL_STEP_ARGS+=("--save" "${TARBALL_TMP_TARBALL_STEP_DIR}")

# determine temporary directory to resume from
if [[ -z ${REMOVAL_TMPDIR} ]]; then
    # no rebuild step was done, so the tarball step should resume from the build directory
    BUILD_TMPDIR=$(grep ' as tmp directory ' ${build_outerr} | cut -d ' ' -f 2)
    TARBALL_STEP_ARGS+=("--resume" "${BUILD_TMPDIR}")
else
    # a removal step was done, so resume from its temporary directory (which was also used for the build step)
    TARBALL_STEP_ARGS+=("--resume" "${REMOVAL_TMPDIR}")
fi

timestamp=$(date +%s)
# to set EESSI_VERSION we need to source init/eessi_defaults now
source $software_layer_dir/init/eessi_defaults
export TGZ=$(printf "eessi-%s-software-%s-%s-%d.tar.gz" ${EESSI_VERSION} ${EESSI_OS_TYPE} ${EESSI_SOFTWARE_SUBDIR_OVERRIDE//\//-} ${timestamp})

# value of first parameter to create_tarball.sh - TMP_IN_CONTAINER - needs to be
# synchronised with setting of TMP_IN_CONTAINER in eessi_container.sh
# TODO should we make this a configurable parameter of eessi_container.sh using
# /tmp as default?
TMP_IN_CONTAINER=/tmp
echo "Executing command to create tarball:"
echo "$software_layer_dir/eessi_container.sh ${COMMON_ARGS[@]} ${TARBALL_STEP_ARGS[@]}"
echo "                     -- $software_layer_dir/create_tarball.sh ${TMP_IN_CONTAINER} ${EESSI_VERSION} ${EESSI_SOFTWARE_SUBDIR_OVERRIDE} \"${EESSI_ACCELERATOR_TARGET}\" /eessi_bot_job/${TGZ} 2>&1 | tee -a ${tar_outerr}"
$software_layer_dir/eessi_container.sh "${COMMON_ARGS[@]}" "${TARBALL_STEP_ARGS[@]}" \
                     -- $software_layer_dir/create_tarball.sh ${TMP_IN_CONTAINER} ${EESSI_VERSION} ${EESSI_SOFTWARE_SUBDIR_OVERRIDE} "${EESSI_ACCELERATOR_TARGET}" /eessi_bot_job/${TGZ} 2>&1 | tee -a ${tar_outerr}

exit 0
