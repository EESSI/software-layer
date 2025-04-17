#!/usr/bin/env bash
#
# script to run tests or the test suite for the whole EESSI software layer or
# just what has been built in a job. Intended use is that it is called
# at the end of a (batch) job running on a compute node.
#
# This script is part of the EESSI software layer, see
# https://github.com/EESSI/software-layer.git
#
# author: Thomas Roeblitz (@trz42)
# author: Caspar van Leeuwen (@casparvl)
#
# license: GPLv2
#

# ASSUMPTIONs:
# + assumption for the build step (as run through bot/build.sh which is provided
#   in this repository too)
#  - working directory has been prepared by the bot with a checkout of a
#    pull request (OR by some other means)
#  - the working directory contains a directory 'cfg' where the main config
#    file 'job.cfg' has been deposited
#  - the directory may contain any additional files referenced in job.cfg
# + assumptions for the test step
#  - temporary storage is still available
#    example
#    Using /localscratch/9640860/NESSI/eessi.x765Dd8mFh as tmp directory (to resume session add '--resume /localscratch/9640860/NESSI/eessi.x765Dd8mFh').
#  - run test-suite.sh inside build container using tmp storage from build step
#    plus possibly additional settings (repo, etc.)
#  - needed setup steps may be similar to bot/inspect.sh (PR#317)

# stop as soon as something fails
set -e

# source utils.sh and cfg_files.sh
source scripts/utils.sh
source scripts/cfg_files.sh

# defaults
export JOB_CFG_FILE="${JOB_CFG_FILE_OVERRIDE:=./cfg/job.cfg}"
HOST_ARCH=$(uname -m)

# check if ${JOB_CFG_FILE} exists
if [[ ! -r "${JOB_CFG_FILE}" ]]; then
    fatal_error "job config file (JOB_CFG_FILE=${JOB_CFG_FILE}) does not exist or not readable"
fi
echo "bot/test.sh: showing ${JOB_CFG_FILE} from software-layer side"
cat ${JOB_CFG_FILE}

echo "bot/test.sh: obtaining configuration settings from '${JOB_CFG_FILE}'"
cfg_load ${JOB_CFG_FILE}

# if http_proxy is defined in ${JOB_CFG_FILE} use it, if not use env var $http_proxy
HTTP_PROXY=$(cfg_get_value "site_config" "http_proxy")
HTTP_PROXY=${HTTP_PROXY:-${http_proxy}}
echo "bot/test.sh: HTTP_PROXY='${HTTP_PROXY}'"

# if https_proxy is defined in ${JOB_CFG_FILE} use it, if not use env var $https_proxy
HTTPS_PROXY=$(cfg_get_value "site_config" "https_proxy")
HTTPS_PROXY=${HTTPS_PROXY:-${https_proxy}}
echo "bot/test.sh: HTTPS_PROXY='${HTTPS_PROXY}'"

LOCAL_TMP=$(cfg_get_value "site_config" "local_tmp")
echo "bot/test.sh: LOCAL_TMP='${LOCAL_TMP}'"
# TODO should local_tmp be mandatory? --> then we check here and exit if it is not provided

# check if path to copy build logs to is specified, so we can copy build logs for failing builds there
BUILD_LOGS_DIR=$(cfg_get_value "site_config" "build_logs_dir")
echo "bot/test.sh: BUILD_LOGS_DIR='${BUILD_LOGS_DIR}'"
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
echo "bot/test.sh: SHARED_FS_PATH='${SHARED_FS_PATH}'"
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
echo "bot/test.sh: SINGULARITY_CACHEDIR='${SINGULARITY_CACHEDIR}'"
if [[ ! -z ${SINGULARITY_CACHEDIR} ]]; then
    # make sure that separate directories are used for different CPU families
    SINGULARITY_CACHEDIR=${SINGULARITY_CACHEDIR}/${HOST_ARCH}
    export SINGULARITY_CACHEDIR
fi

# try to determine tmp directory from build job
RESUME_DIR=$(grep 'Using .* as tmp directory' slurm-${SLURM_JOBID}.out | head -1 | awk '{print $2}')

if [[ -z ${RESUME_DIR} ]]; then
  RESUME_TGZ=${PWD}/previous_tmp/build_step/$(ls previous_tmp/build_step)
  if [[ -z ${RESUME_TGZ} ]]; then
    echo "bot/test.sh: no information about tmp directory and tarball of build step; --> giving up"
    exit 2
  fi
fi

echo -n "setting \$STORAGE by replacing any var in '${LOCAL_TMP}' -> "
# replace any env variable in ${LOCAL_TMP} with its
#   current value (e.g., a value that is local to the job)
STORAGE=$(envsubst <<< ${LOCAL_TMP})
echo "'${STORAGE}'"

# make sure ${STORAGE} exists
mkdir -p ${STORAGE}

# make sure the base tmp storage is unique
JOB_STORAGE=$(mktemp --directory --tmpdir=${STORAGE} bot_job_tmp_XXX)
echo "bot/test.sh: created unique base tmp storage directory at ${JOB_STORAGE}"

# obtain list of modules to be loaded
LOAD_MODULES=$(cfg_get_value "site_config" "load_modules")
echo "bot/test.sh: LOAD_MODULES='${LOAD_MODULES}'"

# singularity/apptainer settings: CONTAINER, HOME, TMPDIR, BIND
CONTAINER=$(cfg_get_value "repository" "container")
export SINGULARITY_HOME="${PWD}:/eessi_bot_job"
export SINGULARITY_TMPDIR="${JOB_STORAGE:-${PWD}}/singularity_tmpdir"
mkdir -p ${SINGULARITY_TMPDIR}

# load modules if LOAD_MODULES is not empty
if [[ ! -z ${LOAD_MODULES} ]]; then
    IFS=',' read -r -a modules <<< "$(echo "${LOAD_MODULES}")"
    for mod in "${modules[@]}";
    do
        echo "bot/test.sh: loading module '${mod}'"
        module load ${mod}
    done
else
    echo "bot/test.sh: no modules to be loaded"
fi

# determine repository to be used from entry .repository in ${JOB_CFG_FILE}
REPOSITORY=$(cfg_get_value "repository" "repo_id")
EESSI_REPOS_CFG_DIR_OVERRIDE=$(cfg_get_value "repository" "repos_cfg_dir")
export EESSI_REPOS_CFG_DIR_OVERRIDE=${EESSI_REPOS_CFG_DIR_OVERRIDE:-${PWD}/cfg}
echo "bot/test.sh: EESSI_REPOS_CFG_DIR_OVERRIDE='${EESSI_REPOS_CFG_DIR_OVERRIDE}'"

# determine pilot version to be used from .repository.repo_version in ${JOB_CFG_FILE}
# here, just set & export EESSI_PILOT_VERSION_OVERRIDE
# next script (eessi_container.sh) makes use of it via sourcing init scripts
# (e.g., init/eessi_defaults or init/minimal_eessi_env)
export EESSI_PILOT_VERSION_OVERRIDE=$(cfg_get_value "repository" "repo_version")
echo "bot/test.sh: EESSI_PILOT_VERSION_OVERRIDE='${EESSI_PILOT_VERSION_OVERRIDE}'"

# determine CVMFS repo to be used from .repository.repo_name in ${JOB_CFG_FILE}
# here, just set EESSI_CVMFS_REPO_OVERRIDE, a bit further down
# "source init/eessi_defaults" via sourcing init/minimal_eessi_env
export EESSI_CVMFS_REPO_OVERRIDE=/cvmfs/$(cfg_get_value "repository" "repo_name")
echo "bot/test.sh: EESSI_CVMFS_REPO_OVERRIDE='${EESSI_CVMFS_REPO_OVERRIDE}'"

# determine architecture to be used from entry .architecture in ${JOB_CFG_FILE}
# fallbacks:
#  - ${CPU_TARGET} handed over from bot
#  - left empty to let downstream script(s) determine subdir to be used
EESSI_SOFTWARE_SUBDIR_OVERRIDE=$(cfg_get_value "architecture" "software_subdir")
EESSI_SOFTWARE_SUBDIR_OVERRIDE=${EESSI_SOFTWARE_SUBDIR_OVERRIDE:-${CPU_TARGET}}
export EESSI_SOFTWARE_SUBDIR_OVERRIDE
echo "bot/test.sh: EESSI_SOFTWARE_SUBDIR_OVERRIDE='${EESSI_SOFTWARE_SUBDIR_OVERRIDE}'"

# determine accelerator target (if any) from .architecture in ${JOB_CFG_FILE}
export EESSI_ACCELERATOR_TARGET=$(cfg_get_value "architecture" "accelerator")
echo "bot/test.sh: EESSI_ACCELERATOR_TARGET='${EESSI_ACCELERATOR_TARGET}'"

# get EESSI_OS_TYPE from .architecture.os_type in ${JOB_CFG_FILE} (default: linux)
EESSI_OS_TYPE=$(cfg_get_value "architecture" "os_type")
export EESSI_OS_TYPE=${EESSI_OS_TYPE:-linux}
echo "bot/test.sh: EESSI_OS_TYPE='${EESSI_OS_TYPE}'"

# prepare arguments to eessi_container.sh common to build and tarball steps
declare -a COMMON_ARGS=()
COMMON_ARGS+=("--verbose")
COMMON_ARGS+=("--access" "ro")
COMMON_ARGS+=("--mode" "run")
[[ ! -z ${CONTAINER} ]] && COMMON_ARGS+=("--container" "${CONTAINER}")
[[ ! -z ${HTTP_PROXY} ]] && COMMON_ARGS+=("--http-proxy" "${HTTP_PROXY}")
[[ ! -z ${HTTPS_PROXY} ]] && COMMON_ARGS+=("--https-proxy" "${HTTPS_PROXY}")
[[ ! -z ${REPOSITORY} ]] && COMMON_ARGS+=("--repository" "${REPOSITORY}")

# pass through '--contain' to avoid leaking in scripts into the container session
# note, --pass-through can be used multiple times if needed
COMMON_ARGS+=("--pass-through" "--contain")

# make sure to use the same parent dir for storing tarballs of tmp
PREVIOUS_TMP_DIR=${PWD}/previous_tmp

# prepare directory to store tarball of tmp for test step
TARBALL_TMP_TEST_STEP_DIR=${PREVIOUS_TMP_DIR}/test_step
mkdir -p ${TARBALL_TMP_TEST_STEP_DIR}

# prepare arguments to eessi_container.sh specific to test step
declare -a TEST_STEP_ARGS=()
TEST_STEP_ARGS+=("--save" "${TARBALL_TMP_TEST_STEP_DIR}")

if [[ -z ${RESUME_DIR} ]]; then
  TEST_STEP_ARGS+=("--storage" "${STORAGE}")
  TEST_STEP_ARGS+=("--resume" "${RESUME_TGZ}")
else
  TEST_STEP_ARGS+=("--resume" "${RESUME_DIR}")
fi
# Bind mount /sys/fs/cgroup so that we can determine the amount of memory available in our cgroup for
# Reframe configuration
TEST_STEP_ARGS+=("--extra-bind-paths" "/sys/fs/cgroup:/hostsys/fs/cgroup:ro")

# add options required to handle NVIDIA support
if command_exists "nvidia-smi"; then
    # Accept that this may fail
    set +e
    nvidia-smi --version
    ec=$?
    set -e
    if [ ${ec} -eq 0 ]; then
        echo "Command 'nvidia-smi' found, using available GPU"
        TEST_STEP_ARGS+=("--nvidia" "run")
    else
        echo "Warning: command 'nvidia-smi' found, but 'nvidia-smi --version' did not run succesfully."
        echo "This script now assumes this is NOT a GPU node."
        echo "If, and only if, the current node actually does contain Nvidia GPUs, this should be considered an error."
    fi
fi

# prepare arguments to test_suite.sh (specific to test step)
declare -a TEST_SUITE_ARGS=()
if [[ ${EESSI_SOFTWARE_SUBDIR_OVERRIDE} =~ .*/generic$ ]]; then
    TEST_SUITE_ARGS+=("--generic")
fi
if [[ ${SHARED_FS_PATH} ]]; then
    TEST_SUITE_ARGS+=("--shared-fs-path" "${SHARED_FS_PATH}")
fi
# [[ ! -z ${BUILD_LOGS_DIR} ]] && TEST_SUITE_ARGS+=("--build-logs-dir" "${BUILD_LOGS_DIR}")
# [[ ! -z ${SHARED_FS_PATH} ]] && TEST_SUITE_ARGS+=("--shared-fs-path" "${SHARED_FS_PATH}")

# create tmp file for output of build step
test_outerr=$(mktemp test.outerr.XXXX)

echo "Executing command to test software:"
echo "./eessi_container.sh ${COMMON_ARGS[@]} ${TEST_STEP_ARGS[@]}"
echo "                     -- ./run_tests.sh \"${TEST_SUITE_ARGS[@]}\" \"$@\" 2>&1 | tee -a ${test_outerr}"
./eessi_container.sh "${COMMON_ARGS[@]}" "${TEST_STEP_ARGS[@]}" \
                     -- ./run_tests.sh "${TEST_SUITE_ARGS[@]}" "$@" 2>&1 | tee -a ${test_outerr}

exit 0
