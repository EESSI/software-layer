#!/usr/bin/env bash
#
# Script to inspect result of a build job for the EESSI software layer.
# Intended use is that it is called with a path to a job directory.
#
# This script is part of the EESSI software layer, see
# https://github.com/EESSI/software-layer.git
#
# author: Thomas Roeblitz (@trz42)
#
# license: GPLv2
#

# ASSUMPTIONs:
#  - Script is executed on the same architecture the job was running on.
#    - Initially, we also assume that is run on the same resource with the
#      same (compute) node setup (local disk space, HTTP proxies, etc.)
#  - The job directory being supplied has been prepared by the bot with a
#    checkout of a pull request (OR by some other means)
#  - The job directory contains a directory 'cfg' where the main config
#    file 'job.cfg' has been deposited.
#    - The 'cfg' directory may contain any additional files referenced in
#      'job.cfg' (repos.cfg, etc.).
#  - The job produced some tarballs for its state (tmp disk for overlayfs,
#    CVMFS cache, etc.) under 'previous_tmp/{build,tarball}_step'.

# stop as soon as something fails
set -e

display_help() {
  echo "usage: $0 [OPTIONS]"
  echo "  -h | --help            -  display this usage information"
  echo "  -j | --job-dir DIR     -  inspect job with the given work directory DIR"
  echo "  -x | --http-proxy URL  -  provides URL for the environment variable http_proxy"
  echo "  -y | --https-proxy URL -  provides URL for the environment variable https_proxy"
}

job_dir=
http_proxy=
https_proxy=

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case ${1} in
    -h|--help)
      display_help
      exit 0
      ;;
    -j|--job-dir)
      export job_dir="${2}"
      shift 2
      ;;
    -x|--http-proxy)
      export http_proxy="${2}"
      shift 2
      ;;
    -y|--https-proxy)
      export https_proxy="${2}"
      shift 2
      ;;
    -*|--*)
      echo "Error: Unknown option: ${1}" >&2
      exit 1
      ;;
    *)  # No more options
      POSITIONAL_ARGS+=("${1}") # save positional arg
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"

# source utils.sh and cfg_files.sh
source scripts/utils.sh
source scripts/cfg_files.sh

if [[ -z ${job_dir} ]]; then
    echo_yellow "path to job directory missing"
    display_help
    exit 1
fi

# defaults
export JOB_CFG_FILE="${job_dir}/cfg/job.cfg}"
HOST_ARCH=$(uname -m)

# check if ${JOB_CFG_FILE} exists
if [[ ! -r "${JOB_CFG_FILE}" ]]; then
    fatal_error "job config file (JOB_CFG_FILE=${JOB_CFG_FILE}) does not exist or not readable"
fi
echo "bot/inspect.sh: showing ${JOB_CFG_FILE} from software-layer side"
cat ${JOB_CFG_FILE}

echo "bot/inspect.sh: obtaining configuration settings from '${JOB_CFG_FILE}'"
cfg_load ${JOB_CFG_FILE}

# if http_proxy is defined in ${JOB_CFG_FILE} use it, if not use env var $http_proxy
HTTP_PROXY=$(cfg_get_value "site_config" "http_proxy")
HTTP_PROXY=${HTTP_PROXY:-${http_proxy}}
echo "bot/inspect.sh: HTTP_PROXY='${HTTP_PROXY}'"

# if https_proxy is defined in ${JOB_CFG_FILE} use it, if not use env var $https_proxy
HTTPS_PROXY=$(cfg_get_value "site_config" "https_proxy")
HTTPS_PROXY=${HTTPS_PROXY:-${https_proxy}}
echo "bot/build.sh: HTTPS_PROXY='${HTTPS_PROXY}'"

LOCAL_TMP=$(cfg_get_value "site_config" "local_tmp")
echo "bot/inspect.sh: LOCAL_TMP='${LOCAL_TMP}'"
# TODO should local_tmp be mandatory? --> then we check here and exit if it is not provided

# check if path to copy build logs to is specified, so we can copy build logs for failing builds there
BUILD_LOGS_DIR=$(cfg_get_value "site_config" "build_logs_dir")
echo "bot/inspect.sh: BUILD_LOGS_DIR='${BUILD_LOGS_DIR}'"
# if $BUILD_LOGS_DIR is set, add it to $SINGULARITY_BIND so the path is available in the build container
if [[ ! -z ${BUILD_LOGS_DIR} ]]; then
    mkdir -p ${BUILD_LOGS_DIR}
    if [[ -z ${SINGULARITY_BIND} ]]; then
        export SINGULARITY_BIND="${BUILD_LOGS_DIR}"
    else
        export SINGULARITY_BIND="${SINGULARITY_BIND},${BUILD_LOGS_DIR}"
    fi
fi

SINGULARITY_CACHEDIR=$(cfg_get_value "site_config" "container_cachedir")
echo "bot/inspect.sh: SINGULARITY_CACHEDIR='${SINGULARITY_CACHEDIR}'"
if [[ ! -z ${SINGULARITY_CACHEDIR} ]]; then
    # make sure that separate directories are used for different CPU families
    SINGULARITY_CACHEDIR=${SINGULARITY_CACHEDIR}/${HOST_ARCH}
    export SINGULARITY_CACHEDIR
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
echo "bot/inspect.sh: created unique base tmp storage directory at ${JOB_STORAGE}"

# obtain list of modules to be loaded
LOAD_MODULES=$(cfg_get_value "site_config" "load_modules")
echo "bot/inspect.sh: LOAD_MODULES='${LOAD_MODULES}'"

# singularity/apptainer settings: CONTAINER, HOME, TMPDIR, BIND
CONTAINER=$(cfg_get_value "repository" "container")
export SINGULARITY_HOME="${PWD}:/eessi_bot_job"
export SINGULARITY_TMPDIR="${PWD}/singularity_tmpdir"
mkdir -p ${SINGULARITY_TMPDIR}

# load modules if LOAD_MODULES is not empty
if [[ ! -z ${LOAD_MODULES} ]]; then
    for mod in $(echo ${LOAD_MODULES} | tr ',' '\n')
    do
        echo "bot/inspect.sh: loading module '${mod}'"
        module load ${mod}
    done
else
    echo "bot/inspect.sh: no modules to be loaded"
fi

# determine repository to be used from entry .repository in ${JOB_CFG_FILE}
REPOSITORY=$(cfg_get_value "repository" "repo_id")
EESSI_REPOS_CFG_DIR_OVERRIDE=$(cfg_get_value "repository" "repos_cfg_dir")
export EESSI_REPOS_CFG_DIR_OVERRIDE=${EESSI_REPOS_CFG_DIR_OVERRIDE:-${PWD}/cfg}
echo "bot/inspect.sh: EESSI_REPOS_CFG_DIR_OVERRIDE='${EESSI_REPOS_CFG_DIR_OVERRIDE}'"

# determine pilot version to be used from .repository.repo_version in ${JOB_CFG_FILE}
# here, just set & export EESSI_PILOT_VERSION_OVERRIDE
# next script (eessi_container.sh) makes use of it via sourcing init scripts
# (e.g., init/eessi_defaults or init/minimal_eessi_env)
export EESSI_PILOT_VERSION_OVERRIDE=$(cfg_get_value "repository" "repo_version")
echo "bot/inspect.sh: EESSI_PILOT_VERSION_OVERRIDE='${EESSI_PILOT_VERSION_OVERRIDE}'"

# determine CVMFS repo to be used from .repository.repo_name in ${JOB_CFG_FILE}
# here, just set EESSI_CVMFS_REPO_OVERRIDE, a bit further down
# "source init/eessi_defaults" via sourcing init/minimal_eessi_env
export EESSI_CVMFS_REPO_OVERRIDE=$(cfg_get_value "repository" "repo_name")
echo "bot/inspect.sh: EESSI_CVMFS_REPO_OVERRIDE='${EESSI_CVMFS_REPO_OVERRIDE}'"

# determine architecture to be used from entry .architecture in ${JOB_CFG_FILE}
# fallbacks:
#  - ${CPU_TARGET} handed over from bot
#  - left empty to let downstream script(s) determine subdir to be used
EESSI_SOFTWARE_SUBDIR_OVERRIDE=$(cfg_get_value "architecture" "software_subdir")
EESSI_SOFTWARE_SUBDIR_OVERRIDE=${EESSI_SOFTWARE_SUBDIR_OVERRIDE:-${CPU_TARGET}}
export EESSI_SOFTWARE_SUBDIR_OVERRIDE
echo "bot/inspect.sh: EESSI_SOFTWARE_SUBDIR_OVERRIDE='${EESSI_SOFTWARE_SUBDIR_OVERRIDE}'"

# get EESSI_OS_TYPE from .architecture.os_type in ${JOB_CFG_FILE} (default: linux)
EESSI_OS_TYPE=$(cfg_get_value "architecture" "os_type")
export EESSI_OS_TYPE=${EESSI_OS_TYPE:-linux}
echo "bot/inspect.sh: EESSI_OS_TYPE='${EESSI_OS_TYPE}'"

# prepare arguments to eessi_container.sh common to build and tarball steps
declare -a COMMON_ARGS=()
COMMON_ARGS+=("--verbose")
COMMON_ARGS+=("--access" "rw")
COMMON_ARGS+=("--mode" "run")
[[ ! -z ${CONTAINER} ]] && COMMON_ARGS+=("--container" "${CONTAINER}")
[[ ! -z ${HTTP_PROXY} ]] && COMMON_ARGS+=("--http-proxy" "${HTTP_PROXY}")
[[ ! -z ${HTTPS_PROXY} ]] && COMMON_ARGS+=("--https-proxy" "${HTTPS_PROXY}")
[[ ! -z ${REPOSITORY} ]] && COMMON_ARGS+=("--repository" "${REPOSITORY}")

# make sure to use the same parent dir for storing tarballs of tmp
PREVIOUS_TMP_DIR=${PWD}/previous_tmp

# prepare directory to store tarball of tmp for build step
TARBALL_TMP_BUILD_STEP_DIR=${PREVIOUS_TMP_DIR}/build_step
mkdir -p ${TARBALL_TMP_BUILD_STEP_DIR}

# prepare arguments to eessi_container.sh specific to build step
declare -a BUILD_STEP_ARGS=()
BUILD_STEP_ARGS+=("--save" "${TARBALL_TMP_BUILD_STEP_DIR}")
BUILD_STEP_ARGS+=("--storage" "${STORAGE}")

# prepare arguments to install_software_layer.sh (specific to build step)
declare -a INSTALL_SCRIPT_ARGS=()
if [[ ${EESSI_SOFTWARE_SUBDIR_OVERRIDE} =~ .*/generic$ ]]; then
    INSTALL_SCRIPT_ARGS+=("--generic")
fi
[[ ! -z ${BUILD_LOGS_DIR} ]] && INSTALL_SCRIPT_ARGS+=("--build-logs-dir" "${BUILD_LOGS_DIR}")

# create tmp file for output of build step
build_outerr=$(mktemp build.outerr.XXXX)

echo "Executing command to build software:"
echo "./eessi_container.sh ${COMMON_ARGS[@]} ${BUILD_STEP_ARGS[@]}"
echo "                     -- ./install_software_layer.sh \"${INSTALL_SCRIPT_ARGS[@]}\" \"$@\" 2>&1 | tee -a ${build_outerr}"
#./eessi_container.sh "${COMMON_ARGS[@]}" "${BUILD_STEP_ARGS[@]}" \
#                     -- ./install_software_layer.sh "${INSTALL_SCRIPT_ARGS[@]}" "$@" 2>&1 | tee -a ${build_outerr}


exit 0
