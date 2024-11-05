#!/bin/bash

base_dir=$(dirname $(realpath $0))
source ${base_dir}/init/eessi_defaults

if [ -z $EESSI_VERSION ]; then
    echo "ERROR: \$EESSI_VERSION must be set!" >&2
    exit 1
fi

echo "EESSI_COMPAT_LAYER_DIR_OVERRIDE: ${EESSI_COMPAT_LAYER_DIR_OVERRIDE}" 

if [ ! -z ${EESSI_COMPAT_LAYER_DIR_OVERRIDE} ]; then
    echo "EESSI_COMPAT_LAYER_DIR_OVERRIDE found. Setting EESSI_COMPAT_LAYER_DIR to ${EESSI_COMPAT_LAYER_DIR_OVERRIDE}"
    EESSI_COMPAT_LAYER_DIR=${EESSI_COMPAT_LAYER_DIR_OVERRIDE}
else 
    EESSI_COMPAT_LAYER_DIR="${EESSI_CVMFS_REPO}/versions/${EESSI_VERSION}/compat/linux/$(uname -m)"
fi

if [ ! -d ${EESSI_COMPAT_LAYER_DIR} ]; then
    echo "ERROR: ${EESSI_COMPAT_LAYER_DIR} does not exist!" >&2
    exit 1
fi

INPUT=$(echo "$@")
if [ ! -z ${SLURM_JOB_ID} ]; then
    INPUT="export SLURM_JOB_ID=${SLURM_JOB_ID}; ${INPUT}"
fi
if [ ! -z ${EESSI_SOFTWARE_SUBDIR_OVERRIDE} ]; then
    INPUT="export EESSI_SOFTWARE_SUBDIR_OVERRIDE=${EESSI_SOFTWARE_SUBDIR_OVERRIDE}; ${INPUT}"
fi
if [ ! -z ${EESSI_ACCELERATOR_TARGET} ]; then
    INPUT="export EESSI_ACCELERATOR_TARGET=${EESSI_ACCELERATOR_TARGET}; ${INPUT}"
fi
if [ ! -z ${EESSI_CVMFS_REPO_OVERRIDE} ]; then
    INPUT="export EESSI_CVMFS_REPO_OVERRIDE=${EESSI_CVMFS_REPO_OVERRIDE}; ${INPUT}"
fi
if [ ! -z ${EESSI_DEV_PROJECT} ]; then
    INPUT="export EESSI_DEV_PROJECT=${EESSI_DEV_PROJECT}; ${INPUT}"
fi
if [ ! -z ${EESSI_VERSION_OVERRIDE} ]; then
    INPUT="export EESSI_VERSION_OVERRIDE=${EESSI_VERSION_OVERRIDE}; ${INPUT}"
fi
if [ ! -z ${EESSI_COMPAT_LAYER_DIR} ]; then
    INPUT="export EESSI_COMPAT_LAYER_DIR=${EESSI_COMPAT_LAYER_DIR}; ${INPUT}"
fi
if [ ! -z ${EESSI_OVERRIDE_GPU_CHECK} ]; then
    INPUT="export EESSI_OVERRIDE_GPU_CHECK=${EESSI_OVERRIDE_GPU_CHECK}; ${INPUT}"
fi
if [ ! -z ${http_proxy} ]; then
    INPUT="export http_proxy=${http_proxy}; ${INPUT}"
fi
if [ ! -z ${https_proxy} ]; then
    INPUT="export https_proxy=${https_proxy}; ${INPUT}"
fi
if [ ! -z ${EASYBUILD_ROBOT_PATHS} ]; then
    INPUT="export EASYBUILD_ROBOT_PATHS=${EASYBUILD_ROBOT_PATHS}; ${INPUT}"
fi

echo "Running '${INPUT}' in EESSI (${EESSI_CVMFS_REPO}) ${EESSI_VERSION} compatibility layer environment..."
${EESSI_COMPAT_LAYER_DIR}/startprefix <<< "${INPUT}"
