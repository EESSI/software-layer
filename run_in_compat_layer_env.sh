#!/bin/bash

base_dir=$(dirname $(realpath $0))
source ${base_dir}/init/eessi_defaults

if [ -z $EESSI_PILOT_VERSION ]; then
    echo "ERROR: \$EESSI_PILOT_VERSION must be set!" >&2
    exit 1
fi
EESSI_COMPAT_LAYER_DIR="${EESSI_CVMFS_REPO}/versions/${EESSI_PILOT_VERSION}/compat/linux/$(uname -m)"
if [ ! -d ${EESSI_COMPAT_LAYER_DIR} ]; then
    echo "ERROR: ${EESSI_COMPAT_LAYER_DIR} does not exist!" >&2
    exit 1
fi

INPUT=$(echo "$@")
if [ ! -z ${EESSI_SOFTWARE_SUBDIR_OVERRIDE} ]; then
    INPUT="export EESSI_SOFTWARE_SUBDIR_OVERRIDE=${EESSI_SOFTWARE_SUBDIR_OVERRIDE}; ${INPUT}"
fi
if [ ! -z ${EESSI_CVMFS_REPO_OVERRIDE} ]; then
    INPUT="export EESSI_CVMFS_REPO_OVERRIDE=${EESSI_CVMFS_REPO_OVERRIDE}; ${INPUT}"
fi
if [ ! -z ${EESSI_PILOT_VERSION_OVERRIDE} ]; then
    INPUT="export EESSI_PILOT_VERSION_OVERRIDE=${EESSI_PILOT_VERSION_OVERRIDE}; ${INPUT}"
fi
if [ ! -z ${http_proxy} ]; then
    INPUT="export http_proxy=${http_proxy}; ${INPUT}"
fi
if [ ! -z ${https_proxy} ]; then
    INPUT="export https_proxy=${https_proxy}; ${INPUT}"
fi

echo "Running '${INPUT}' in EESSI (${EESSI_CVMFS_REPO}) ${EESSI_PILOT_VERSION} compatibility layer environment..."
${EESSI_COMPAT_LAYER_DIR}/startprefix <<< "${INPUT}"
