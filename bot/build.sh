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
#  - the directory may contain any additional files references in job.cfg

# defaults
export JOB_CFG_FILE="${JOB_CFG_FILE_OVERRIDE:=./cfg/job.cfg}"

echo "bot/build.sh: Showing job.cfg from software-layer side"
cat cfg/job.cfg

# source utils.sh and cfg_files.sh
source scripts/utils.sh
source scripts/cfg_files.sh

# check if './cfg/job.cfg' exists
if [[ ! -r "${JOB_CFG_FILE}" ]]; then
    fatal_error "job config file (JOB_CFG_FILE=${JOB_CFG_FILE}) does not exist or not readable"
fi
echo "obtaining configuration settings from '${JOB_CFG_FILE}'"
cfg_load ${JOB_CFG_FILE}

# if http_proxy is in cfg/job.cfg use it, if not use env var $http_proxy
HTTP_PROXY=$(cfg_get_value "site_config" "http_proxy")
HTTP_PROXY=${HTTP_PROXY:-${http_proxy}}
echo "HTTP_PROXY='${HTTP_PROXY}'"

# if https_proxy is in cfg/job.cfg use it, if not use env var $https_proxy
HTTPS_PROXY=$(cfg_get_value "site_config" "https_proxy")
HTTPS_PROXY=${HTTPS_PROXY:-${https_proxy}}
echo "HTTPS_PROXY='${HTTPS_PROXY}'"

LOCAL_TMP=$(cfg_get_value "site_config" "local_tmp")
echo "LOCAL_TMP='${LOCAL_TMP}'"
# TODO should local_tmp be mandatory? --> then we check here and exit if it is not provided

SINGULARITY_CACHEDIR=$(cfg_get_value "site_config" "container_cachedir")
echo "SINGULARITY_CACHEDIR='${SINGULARITY_CACHEDIR}'"
if [[ ! -z ${SINGULARITY_CACHEDIR} ]]; then
    export SINGULARITY_CACHEDIR
fi

echo -n "setting \$STORAGE by replacing any var in '${LOCAL_TMP}' -> "
# replace any env variable in ${LOCAL_TMP} with its
#   current value (e.g., a value that is local to the job)
STORAGE=$(envsubst <<< ${LOCAL_TMP})
echo "'${STORAGE}'"

# obtain list of modules to be loaded
LOAD_MODULES=$(cfg_get_value "site_config" "load_modules")
echo "LOAD_MODULES='${LOAD_MODULES}'"

# singularity/apptainer settings: CONTAINER, HOME, TMPDIR, BIND
CONTAINER=$(cfg_get_value "repository" "container")
export SINGULARITY_HOME="$(pwd):/eessi_bot_job"
export SINGULARITY_TMPDIR="$(pwd)/singularity_tmpdir"
mkdir -p ${SINGULARITY_TMPDIR}

# load modules if LOAD_MODULES is not empty
if [[ ! -z ${LOAD_MODULES} ]]; then
    for mod in $(echo ${LOAD_MODULES} | tr ',' '\n')
    do
        echo "bot/build.sh: loading module '${mod}'"
        module load ${mod}
    done
else
    echo "bot/build.sh: no modules to be loaded"
fi

# determine repository to be used from entry .repository in cfg/job.cfg
REPOSITORY=$(cfg_get_value "repository" "repo_id")
EESSI_REPOS_CFG_DIR_OVERRIDE=$(cfg_get_value "repository" "repos_cfg_dir")
export EESSI_REPOS_CFG_DIR_OVERRIDE=${EESSI_REPOS_CFG_DIR_OVERRIDE:-${PWD}/cfg}

# determine pilot version to be used from .repository.repo_version in cfg/job.cfg
# here, just set & export EESSI_PILOT_VERSION_OVERRIDE
# next script (eessi_container.sh) makes use of it via sourcing init scripts
# (e.g., init/eessi_defaults or init/minimal_eessi_env)
export EESSI_PILOT_VERSION_OVERRIDE=$(cfg_get_value "repository" "repo_version")

# determine CVMFS repo to be used from .repository.repo_name in cfg/job.cfg
# here, just set EESSI_CVMFS_REPO_OVERRIDE, a bit further down
# "source init/eessi_defaults" via sourcing init/minimal_eessi_env
export EESSI_CVMFS_REPO_OVERRIDE=$(cfg_get_value "repository" "repo_name")


# determine architecture to be used from entry .architecture in cfg/job.cfg
# default: leave empty to let downstream script(s) determine subdir to be used
if [[ ! -z "${CPU_TARGET}" ]]; then
    EESSI_SOFTWARE_SUBDIR_OVERRIDE=${CPU_TARGET}
else
    EESSI_SOFTWARE_SUBDIR_OVERRIDE=$(cfg_get_value "architecture" "software_subdir")
fi
export EESSI_SOFTWARE_SUBDIR_OVERRIDE

# get EESSI_OS_TYPE from .architecture.os_type in cfg/job.cfg (default: linux)
EESSI_OS_TYPE=$(cfg_get_value "architecture" "os_type")
export EESSI_OS_TYPE=${EESSI_OS_TYPE:-linux}

# TODO
#   - CODED add handling of EESSI_SOFTWARE_SUBDIR_OVERRIDE to eessi_container.sh
#     TODO ensure that the bot makes use of that. (currently sets env var
#     CPU_TARGET & adds --export=ALL,CPU_TARGET=val to sbatch command ... also
#     add it to cfg/job.cfg - .architecture.software_subdir)
#   - CODED add handling of http(s)_proxy to eessi_container.sh, in there needs the
#     CVMFS_HTTP_PROXY added to /etc/cvmfs/default.local (this needs a robust
#     way to determine the IP address of a proxy)
#   - bot needs to make repos.cfg and cfg_bundle available to job (likely, by copying
#     files into './cfg/.' and defining '.repository.repos_cfg_dir' in './cfg/job.cfg')

# prepare options and directories for calling eessi_container.sh
declare -a BUILD_STEP_ARGS=()
BUILD_STEP_ARGS+=("--access" "rw")
BUILD_STEP_ARGS+=("--mode" "run")
BUILD_STEP_ARGS+=("--save" "${PWD}/previous_tmp/build_step")
BUILD_STEP_ARGS+=("--storage" "${STORAGE}")
CONTAINER_OPT=
if [[ ! -z ${CONTAINER} ]]; then
    CONTAINER_OPT="--container ${CONTAINER}"
    BUILD_STEP_ARGS+=("--container" "${CONTAINER}")
fi
HTTP_PROXY_OPT=
if [[ ! -z ${HTTP_PROXY} ]]; then
    HTTP_PROXY_OPT="--http-proxy ${HTTP_PROXY}"
    BUILD_STEP_ARGS+=("--http-proxy" "${HTTP_PROXY}")
fi
HTTPS_PROXY_OPT=
if [[ ! -z ${HTTPS_PROXY} ]]; then
    HTTPS_PROXY_OPT="--https-proxy ${HTTPS_PROXY}"
    BUILD_STEP_ARGS+=("--https-proxy" "${HTTPS_PROXY}")
fi
REPOSITORY_OPT=
if [[ ! -z ${REPOSITORY} ]]; then
    REPOSITORY_OPT="--repository ${REPOSITORY}"
    BUILD_STEP_ARGS+=("--repository" "${REPOSITORY}")
fi
GENERIC_OPT=
if [[ ${EESSI_SOFTWARE_SUBDIR_OVERRIDE} =~ .*/generic$ ]]; then
    GENERIC_OPT="--generic"
fi

mkdir -p previous_tmp/{build_step,tarball_step}
build_outerr=$(mktemp build.outerr.XXXX)
echo "Executing command to build software:"
echo "./eessi_container.sh ${BUILD_STEP_ARGS[@]}"
echo "                     --verbose"
echo "                     -- ./install_software_layer.sh ${GENERIC_OPT} \"$@\" 2>&1 | tee -a ${build_outerr}"
# set EESSI_REPOS_CFG_DIR_OVERRIDE to ./cfg
export EESSI_REPOS_CFG_DIR_OVERRIDE=${PWD}/cfg
./eessi_container.sh "${BUILD_STEP_ARGS[@]}" \
                     --verbose \
                     -- ./install_software_layer.sh ${GENERIC_OPT} "$@" 2>&1 | tee -a ${build_outerr}

# determine temporary directory to resume from
BUILD_TMPDIR=$(grep ' as tmp directory ' ${build_outerr} | cut -d ' ' -f 2)

tar_outerr=$(mktemp tar.outerr.XXXX)
timestamp=$(date +%s)
# to set EESSI_PILOT_VERSION we need to source init/eessi_defaults now
source init/eessi_defaults
export TGZ=$(printf "eessi-%s-software-%s-%s-%d.tar.gz" ${EESSI_PILOT_VERSION} ${EESSI_OS_TYPE} ${EESSI_SOFTWARE_SUBDIR_OVERRIDE//\//-} ${timestamp})

# value of first parameter to create_tarball.sh - TMP_IN_CONTAINER - needs to be
# synchronised with setting of TMP_IN_CONTAINER in eessi_container.sh
# TODO should we make this a configurable parameter of eessi_container.sh using
# /tmp as default?
TMP_IN_CONTAINER=/tmp
echo "Executing command to create tarball:"
echo "./eessi_container.sh --access rw"
echo "                     ${CONTAINER_OPT}"
echo "                     ${HTTP_PROXY_OPT}"
echo "                     ${HTTPS_PROXY_OPT}"
echo "                     --verbose"
echo "                     --mode run"
echo "                     ${REPOSITORY_OPT}"
echo "                     --resume ${BUILD_TMPDIR}"
echo "                     --save ${PWD}/previous_tmp/tarball_step"
echo "                     ./create_tarball.sh ${TMP_IN_CONTAINER} ${EESSI_PILOT_VERSION} ${EESSI_SOFTWARE_SUBDIR_OVERRIDE} /eessi_bot_job/${TGZ} 2>&1 | tee -a ${tar_outerr}"
./eessi_container.sh --access rw \
                     ${CONTAINER_OPT} \
                     ${HTTP_PROXY_OPT} \
                     ${HTTPS_PROXY_OPT} \
                     --verbose \
                     --mode run \
                     ${REPOSITORY_OPT} \
                     --resume ${BUILD_TMPDIR} \
                     --save ${PWD}/previous_tmp/tarball_step \
                     ./create_tarball.sh ${TMP_IN_CONTAINER} ${EESSI_PILOT_VERSION} ${EESSI_SOFTWARE_SUBDIR_OVERRIDE} /eessi_bot_job/${TGZ} 2>&1 | tee -a ${tar_outerr}

# if two tarballs have been generated, only keep the one from tarball step
NUM_TARBALLS=$(find ${PWD}/previous_tmp -type f -name "*tgz" | wc -l)
if [[ ${NUM_TARBALLS} -eq 2 ]]; then
    rm -f previous_tmp/build_step/*.tgz
fi

exit 0
