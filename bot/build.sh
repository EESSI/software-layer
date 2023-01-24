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

LOCAL_TMP=$(${YQ} '.site_config.local_tmp // ""' < ${JOB_CFG_FILE})
echo "LOCAL_TMP='${LOCAL_TMP}'"
echo -n "setting \$storage by replacing any var in '${LOCAL_TMP}' -> "
# replace any env variable in ${LOCAL_TMP} with its
#   current value (e.g., a value that is local to the job)
storage=$(envsubst <<< ${LOCAL_TMP})
echo "'${storage}'"


# singularity/apptainer settings: load_modules, HOME, TMPDIR, BIND 
LOAD_MODULES=$(${YQ} '.site_config.load_modules // ""' < ${JOB_CFG_FILE})
echo "LOAD_MODULES='${LOAD_MODULES}'"

export SINGULARITY_HOME="$(pwd):/eessi_bot_job"
export SINGULARITY_TMPDIR="$(pwd)/singularity_tmpdir"
mkdir -p ${SINGULARITY_TMPDIR}

if [[ ${storage} != /tmp* ]] ;
then
    export SINGULARITY_BIND="${storage}:/tmp"
fi
echo "SINGULARITY_BIND='${SINGULARITY_BIND}'"

# load modules LOAD_MODULES is not empty
if [[ ! -z ${LOAD_MODULES} ]]; then
    for mod in $(echo ${LOAD_MODULES} | tr ',' '\n')
    do
        echo "bot/build.sh: loading module '${mod}'"
        module load ${mod}
    done
else
    echo "bot/build.sh: no modules to be loaded"
fi

