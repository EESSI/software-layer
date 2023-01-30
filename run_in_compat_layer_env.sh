#!/bin/bash

base_dir=$(dirname $(realpath $0))
echo "script '$0' before sourcing '${base_dir}/init/eessi_defaults'"
env | grep EESSI_
source ${base_dir}/init/eessi_defaults

echo "script '$0' after sourcing '${base_dir}/init/eessi_defaults'"
env | grep EESSI_

BUILD_CONTAINER="docker://ghcr.io/eessi/build-node:debian11"
if [ -z $EESSI_PILOT_VERSION ]; then
    echo "ERROR: \$EESSI_PILOT_VERSION must be set!" >&2
    exit 1
fi
EESSI_COMPAT_LAYER_DIR="${EESSI_CVMFS_REPO}/versions/${EESSI_PILOT_VERSION}/compat/linux/$(uname -m)"
echo "script '$0' compat layer '${EESSI_COMPAT_LAYER_DIR}'"
if [ ! -d ${EESSI_COMPAT_LAYER_DIR} ]; then
    echo "ERROR: ${EESSI_COMPAT_LAYER_DIR} does not exist!" >&2
    exit 1
fi

INPUT=$(echo "$@")
if [ ! -z ${EESSI_SOFTWARE_SUBDIR_OVERRIDE} ]; then
    INPUT="export EESSI_SOFTWARE_SUBDIR_OVERRIDE=${EESSI_SOFTWARE_SUBDIR_OVERRIDE}; ${INPUT}"
fi

echo "Running '${INPUT}' in EESSI (${EESSI_CVMFS_REPO}) ${EESSI_PILOT_VERSION} compatibility layer environment..."
${EESSI_COMPAT_LAYER_DIR}/startprefix <<< "${INPUT}"
