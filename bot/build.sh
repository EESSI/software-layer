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
#  - the tool 'yq' for working with json files is available via the PATH or
#    the environment variable BOT_YQ (see https://github.com/mikefarah/yq)

echo "###################################################################"
env
echo "###################################################################"
echo

# defaults
export JOB_CFG_FILE="${JOB_CFG_FILE_OVERRIDE:=./cfg/job.cfg}"

# source utils.sh
source utils.sh

# check setup / define key variables
# get path for 'yq' (if not found, an empty string is returned)
YQ=$(get_path_for_tool "yq" "BOT_YQ")
exit_code=$?
if [[ ${exit_code} -ne 0 ]]; then
    fatal_error "could not find path to 'yq'; exiting"
else
    echo_green "found yq (${YQ})"
fi

# check if './cfg/job.cfg' exists
if [[ ! -r "${JOB_CFG_FILE}" ]]; then
    fatal_error "job config file (JOB_CFG_FILE=${JOB_CFG_FILE}) does not exist or not readable"
fi
echo "obtaining configuration settings from '${JOB_CFG_FILE}'"

# if http_proxy is in cfg/job.cfg use it, if not use env var $http_proxy
HTTP_PROXY=$(${YQ} '.site_config.http_proxy // ""' ${JOB_CFG_FILE})
HTTP_PROXY=${HTTP_PROXY:-${http_proxy}}
echo "HTTP_PROXY='${HTTP_PROXY}'"

# if https_proxy is in cfg/job.cfg use it, if not use env var $https_proxy
HTTPS_PROXY=$(${YQ} '.site_config.https_proxy // ""' ${JOB_CFG_FILE})
HTTPS_PROXY=${HTTPS_PROXY:-${https_proxy}}
echo "HTTPS_PROXY='${HTTPS_PROXY}'"

LOCAL_TMP=$(${YQ} '.site_config.local_tmp // ""' ${JOB_CFG_FILE})
echo "LOCAL_TMP='${LOCAL_TMP}'"
# TODO should local_tmp be mandatory? --> then we check here and exit if it is not provided

echo -n "setting \$STORAGE by replacing any var in '${LOCAL_TMP}' -> "
# replace any env variable in ${LOCAL_TMP} with its
#   current value (e.g., a value that is local to the job)
STORAGE=$(envsubst <<< ${LOCAL_TMP})
echo "'${STORAGE}'"

# obtain list of modules to be loaded
LOAD_MODULES=$(${YQ} '.site_config.load_modules // ""' ${JOB_CFG_FILE})
echo "LOAD_MODULES='${LOAD_MODULES}'"

# singularity/apptainer settings: CONTAINER, HOME, TMPDIR, BIND
CONTAINER=$(${YQ} '.repository.container // ""' ${JOB_CFG_FILE})
export SINGULARITY_HOME="$(pwd):/eessi_bot_job"
export SINGULARITY_TMPDIR="$(pwd)/singularity_tmpdir"
mkdir -p ${SINGULARITY_TMPDIR}

if [[ ${STORAGE} != /tmp* ]] ;
then
    echo "skip setting SINGULARITY_BIND=${STORAGE}:/tmp because another location is bind mounted to /tmp in eessi_container.sh"
    #export SINGULARITY_BIND="${STORAGE}:/tmp"
fi
echo "SINGULARITY_BIND='${SINGULARITY_BIND}'"

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
REPOSITORY=$(${YQ} '.repository.repo_id // ""' ${JOB_CFG_FILE})
EESSI_REPOS_CFG_DIR_OVERRIDE=$(${YQ} '.repository.repos_cfg_dir // ""' ${JOB_CFG_FILE})
export EESSI_REPOS_CFG_DIR_OVERRIDE=${EESSI_REPOS_CFG_DIR_OVERRIDE:-${PWD}/cfg}

# determine architecture to be used from entry .architecture in cfg/job.cfg
# default: leave empty to let downstream script(s) determine subdir to be used
if [[ ! -z "${CPU_TARGET}" ]]; then
    EESSI_SOFTWARE_SUBDIR_OVERRIDE=${CPU_TARGET}
else
    EESSI_SOFTWARE_SUBDIR_OVERRIDE=$(${YQ} '.architecture.software_subdir // ""' ${JOB_CFG_FILE})
fi

#source init/minimal_eessi_env

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
mkdir -p previous_tmp
run_outerr=$(mktemp eessi_container.outerr.XXXXXXXXXX)
CONTAINER_OPT=
if [[ ! -z ${CONTAINER} ]]; then
    CONTAINER_OPT="--container ${CONTAINER}"
fi
HTTP_PROXY_OPT=
if [[ ! -z ${HTTP_PROXY} ]]; then
    HTTP_PROXY_OPT="--http-proxy ${HTTP_PROXY}"
fi
HTTPS_PROXY_OPT=
if [[ ! -z ${HTTPS_PROXY} ]]; then
    HTTPS_PROXY_OPT="--https-proxy ${HTTPS_PROXY}"
fi
REPOSITORY_OPT=
if [[ ! -z ${REPOSITORY} ]]; then
    REPOSITORY_OPT="--repository ${REPOSITORY}"
fi
echo "###################################################################"
env
echo "###################################################################"
echo
echo "Excuting command:"
echo "./eessi_container.sh --access rw"
echo "                     ${CONTAINER_OPT}"
echo "                     ${HTTP_PROXY_OPT}"
echo "                     ${HTTPS_PROXY_OPT}"
echo "                     --info"
echo "                     --mode run"
echo "                     ${REPOSITORY_OPT}"
echo "                     --save $(pwd)/previous_tmp"
echo "                     --storage ${STORAGE}"
echo "                     ./install_software_layer.sh \"$@\" 2>&1 | tee -a ${run_outerr}"
./eessi_container.sh --access rw \
                     ${CONTAINER_OPT} \
                     ${HTTP_PROXY_OPT} \
                     ${HTTPS_PROXY_OPT} \
                     --info \
                     --mode run \
                     ${REPOSITORY_OPT} \
                     --save $(pwd)/previous_tmp \
                     --storage ${STORAGE} \
                     ./install_software_layer.sh \"$@\" 2>&1 | tee -a ${run_outerr}

exit 0
