#!/bin/bash
#
# unified script to access EESSI in different scenarios: read-only
# for just using EESSI, read & write for building software to be
# added to the software stack
#
# This script is part of the EESSI software layer, see
# https://github.com/EESSI/software-layer.git
#
# author: Thomas Roeblitz (@trz42)
#
# license: GPLv2
#

# script overview
# -. initial settings & exit codes
# 0. parse args
# 1. check if argument values are valid
# 2. set up local disk/tmp
# 3. set up common vars and directories
# 4. set up vars specific to a scenario
# 5. initialize local disk/tmp from previous run if provided
# 6. run container

# -. initial settings & exit codes
base_dir=$(dirname $(realpath $0))

# functions
function echo_red() {
    echo -e "\e[31m$1\e[0m"
}

function fatal_error() {
    echo_red "ERROR: ${1}" >&2
    exit ${2}
}

# exit codes: bitwise shift codes to allow for combination of exit codes
ANY_ERROR_EXITCODE=1
CMDLINE_ARG_UNKNOWN_EXITCODE=$((${ANY_ERROR_EXITCODE} << 1))
ACCESS_UNKNOWN_EXITCODE=$((${ANY_ERROR_EXITCODE} << 2))
CONTAINER_ERROR_EXITCODE=$((${ANY_ERROR_EXITCODE} << 3))
LOCAL_DISK_ERROR_EXITCODE=$((${ANY_ERROR_EXITCODE} << 4))
MODE_UNKNOWN_EXITCODE=$((${ANY_ERROR_EXITCODE} << 5))
PREVIOUS_RUN_ERROR_EXITCODE=$((${ANY_ERROR_EXITCODE} << 6))
REPOSITORY_UNKNOWN_EXITCODE=$((${ANY_ERROR_EXITCODE} << 7))
HTTP_PROXY_ERROR_EXITCODE=$((${ANY_ERROR_EXITCODE} << 8))
HTTPS_PROXY_ERROR_EXITCODE=$((${ANY_ERROR_EXITCODE} << 9))
RUN_SCRIPT_MISSING_EXITCODE=$((${ANY_ERROR_EXITCODE} << 10))

# CernVM-FS settings
CVMFS_VAR_LIB="var-lib-cvmfs"
CVMFS_VAR_RUN="var-run-cvmfs"


# 0. parse args
#    see example parsing of command line arguments at
#    https://wiki.bash-hackers.org/scripting/posparams#using_a_while_loop
#    https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

display_help() {
  echo "usage: $0 [OPTIONS] [SCRIPT]"
  echo " OPTIONS:"
  echo "  -a | --access {ro,rw}    -  ro (read-only), rw (read & write) [default: ro]"
  echo "  -c | --container IMAGE   -  image file or URL defining the container to use"
  echo "                           [default: docker://ghcr.io/eessi/build-node:debian10]"
  echo "  -d | --dry-run           -  run script except for executing the container,"
  echo "                              print information about setup [default: false]"
  echo "  -h | --help              -  display this usage information [default: false]"
  echo "  -i | --info              -  display configured repositories [default: false]"
  echo "  -l | --local-disk DIR    -  directory space on local machine (used for"
  echo "                              temporary data) [default: 1. TMPDIR, 2. /tmp]"
  echo "  -m | --mode {shell,run}  -  shell (launch interactive shell)"
  echo "                              run (run a script) [default: shell]"
  echo "  -p | --previous-run PRUN -  init local disk with data from previous run"
  echo "                              format is PATH[:TAR/ZIP] where PATH is pointing"
  echo "                              to the previously used local disk, and TAR/ZIP"
  echo "                              is used to initialize the local disk if PATH"
  echo "                              doesn't exist currently; if PATH exists and"
  echo "                              a TAR/ZIP is provided an error is reported"
  echo "                              [default: not set]"
  echo "  -r | --repository CFG    -  configuration file or identifier defining the"
  echo "                              repository to use [default: EESSI-pilot]"
  echo "  -x | --http-proxy URL    -  provides URL for the env variable http_proxy"
  echo "                              [default: not set]"
  echo "  -y | --https-proxy URL   -  provides URL for the env variable https_proxy"
  echo "                              [default: not set]"
  echo
  echo " If value for --mode is 'run', the SCRIPT provided is executed."
}

# set defaults for command line arguments
ACCESS="ro"
CONTAINER="docker://ghcr.io/eessi/build-node:debian10"
DRY_RUN=0
INFO=0
LOCAL_DISK=
MODE="shell"
PREVIOUS_RUN=
REPOSITORY="EESSI-pilot"
HTTP_PROXY=
HTTPS_PROXY=
RUN_SCRIPT_AND_ARGS=

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -a|--access)
      ACCESS="$2"
      shift 2
      ;;
    -c|--container)
      CONTAINER="$2"
      shift 2
      ;;
    -d|--dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      display_help
      exit 0
      ;;
    -i|--info)
      INFO=1
      ;;
    -l|--local-disk)
      LOCAL_DISK="$2"
      #EESSI_TMPDIR="$2"
      shift 2
      ;;
    -m|--mode)
      MODE="$2"
      shift 2
      ;;
    -p|--previous-run)
      PREVIOUS_RUN="$2"
      shift 2
      ;;
    -x|--http-proxy)
      HTTP_PROXY="$2"
      export http_proxy=${HTTP_PROXY}
      shift 2
      ;;
    -y|--https-proxy)
      HTTPS_PROXY="$2"
      export https_proxy=${HTTPS_PROXY}
      shift 2
      ;;
    -*|--*)
      fatal_error "Unknown option: $1" "${CMDLINE_ARG_UNKNOWN_EXITCODE}"
      ;;
    *)  # No more options
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"


# 1. check if argument values are valid
# (arg -a|--access) check if ACCESS is supported
if [[ ${ACCESS} != "ro" -a ${ACCESS} != "rw" ]]; then
  fatal_error "unknown access method '${ACCESS}'" "${ACCESS_UNKNOWN_EXITCODE}"
fi

# TODO (arg -c|--container) check container (is it a file or URL & access those)
# CONTAINER_ERROR_EXITCODE

# TODO (arg -l|--local-disk) check if it exists, if user has write permission,
#      if it contains no data, etc.
# LOCAL_DISK_ERROR_EXITCODE

# (arg -m|--mode) check if MODE is known
if [[ ${MODE} != "shell" -a ${MODE} != "run" ]]; then
  fatal_error "unknown execution mode '${MODE}'" "${MODE_UNKNOWN_EXITCODE}"
fi

# TODO (arg -p|--previous-run) check if it exists, if user has read permission,
#      if it contains data from a previous run
# PREVIOUS_RUN_ERROR_EXITCODE

# TODO (arg -r|--repository) check if repository is known
# REPOSITORY_UNKNOWN_EXITCODE

# TODO (arg -x|--http-proxy) check if http proxy is accessible
# HTTP_PROXY_ERROR_EXITCODE

# TODO (arg -y|--https-proxy) check if https proxy is accessible
# HTTPS_PROXY_ERROR_EXITCODE

# check if a script is provided if mode is 'run'
if [[ "${MODE}" == "run" ]]; then
  if [[ $# -eq 0 ]]; then
    fatal_error "no command specified to run?!" "${RUN_SCRIPT_MISSING_EXITCODE}"
  else
    RUN_SCRIPT_AND_ARGS=$@
  fi
fi


# 2. set up local disk/tmp
# as location for temporary data use in the following order
#   a. command line argument -l|--local_disk
#   b. env var TMPDIR
#   c. /tmp
# note, we ensure that (a) takes precedence by setting TMPDIR to LOCAL_DISK
#     if LOCAL_DISK is not empty
# note, (b) & (c) are automatically ensured by using mktemp -d to create
#     a temporary directory
# note, if previous run is used the name of the temporary directory
#     should be identical to previous run, ie, then we don't create a new
#     temporary directory
if [[ ! -z ${LOCAL_DISK} ]]; then
  TMPDIR=${LOCAL_DISK}
fi
if [[ ! -z ${TMPDIR} ]]; then
  # TODO check if TMPDIR already exists
  EESSI_LOCAL_DISK=${TMPDIR}
fi
if [[ -z ${TMPDIR} ]]; then
  # mktemp falls back to using /tmp if TMPDIR is empty
  # TODO check if /tmp is writable, large enough and usable (different
  #      features for ro-access and rw-access)
  echo "skipping sanity checks for /tmp"
fi
EESSI_LOCAL_DISK=$(mktemp -d eessi.XXXXXXXXXX)
echo "Using ${EESSI_LOCAL_DISK} as parent for temporary directories..."


# 3. set up common vars and directories
#    directory structure should be:
#      ${EESSI_LOCAL_DISK}
#      |-singularity_cache
#      |-${CVMFS_VAR_LIB}
#      |-${CVMFS_VAR_RUN}

source ${base_dir}/init/eessi_defaults

# configure Singularity
export SINGULARITY_CACHEDIR=${EESSI_LOCAL_DISK}/singularity_cache
mkdir -p ${SINGULARITY_CACHEDIR}
[[ ${INFO} -eq 1 ]] && echo "SINGULARITY_CACHEDIR=${SINGULARITY_CACHEDIR}"

# set env vars and create directories for CernVM-FS
EESSI_CVMFS_VAR_LIB=${EESSI_LOCAL_DISK}/${CVMFS_VAR_LIB}
EESSI_CVMFS_VAR_RUN=${EESSI_LOCAL_DISK}/${CVMFS_VAR_RUN}
mkdir -p ${EESSI_CVMFS_VAR_LIB}
mkdir -p ${EESSI_CVMFS_VAR_RUN}
[[ ${INFO} -eq 1 ]] && echo "EESSI_CVMFS_VAR_LIB=${EESSI_CVMFS_VAR_LIB}"
[[ ${INFO} -eq 1 ]] && echo "EESSI_CVMFS_VAR_RUN=${EESSI_CVMFS_VAR_RUN}"

# tmp dir for EESSI
EESSI_TMPDIR=${EESSI_LOCAL_DISK}/tmp
mkdir -p ${EESSI_TMPDIR}
[[ ${INFO} -eq 1 ]] && echo "EESSI_TMPDIR=${EESSI_TMPDIR}"

# allow that SINGULARITY_HOME is defined before script is run
if [[ -z ${SINGULARITY_HOME} ]]; then
  export SINGULARITY_HOME="${EESSI_LOCAL_DISK}/home:/home/${USER}"
  mkdir -p ${EESSI_LOCAL_DISK}/home
  [[ ${INFO} -eq 1 ]] && echo "SINGULARITY_HOME=${SINGULARITY_HOME}"
fi

# define paths to add to SINGULARITY_BIND (added later when all BIND mounts are defined)
BIND_PATHS="${EESSI_CVMFS_VAR_LIB}:/var/lib/cvfms,${EESSI_CVMFS_VAR_RUN}:/var/run/cvmfs"
BIND_PATHS="${BIND_PATHS},${EESSI_TMPDIR}:/tmp"


# 4. set up vars and dirs specific to a scenario

# strip "/cvmfs/" from default setting
repo_name=${EESSI_CVMFS_REPO/\/cvmfs\//}

if [[ "${ACCESS}" == "ro" ]]; then
  export EESSI_PILOT_READONLY="container:cvmfs2 ${repo_name} ${EESSI_CVMFS_REPO}"
  export EESSI_FUSE_MOUNTS="--fusemount ${EESSI_PILOT_READONLY}"
fi

if [[ "${ACCESS}" == "rw" ]]; then
  EESSI_CVMFS_OVERLAY_UPPER=${EESSI_LOCAL_DISK}/overlay-upper
  EESSI_CVMFS_OVERLAY_WORK=${EESSI_LOCAL_DISK}/overlay-work
  mkdir -p ${EESSI_CMVFS_OVERLAY_UPPER}
  mkdir -p ${EESSI_CMVFS_OVERLAY_WORK}
  [[ ${INFO} -eq 1 ]] && echo "EESSI_CVMFS_OVERLAY_UPPER=${EESSI_CVMFS_OVERLAY_UPPER}"
  [[ ${INFO} -eq 1 ]] && echo "EESSI_CVMFS_OVERLAY_WORK=${EESSI_CVMFS_OVERLAY_WORK}"

  # set environment variables for fuse mounts in Singularity container
  export EESSI_PILOT_READONLY="container:cvmfs2 ${repo_name} /cvmfs_ro/${repo_name}"
  EESSI_PILOT_WRITABLE_OVERLAY="container:fuse-overlayfs"
  EESSI_PILOT_WRITABLE_OVERLAY+=" -o lowerdir=/cvmfs_ro/${repo_name}"
  EESSI_PILOT_WRITABLE_OVERLAY+=" -o upperdir=${EESSI_CVMFS_OVERLAY_UPPER}"
  EESSI_PILOT_WRITABLE_OVERLAY+=" -o workdir=${EESSI_CVMFS_OVERLAY_WORK}"
  EESSI_PILOT_WRITABLE_OVERLAY+=" ${EESSI_CVMFS_REPO}"
  export EESSI_PILOT_WRITABLE_OVERLAY

  EESSI_FUSE_MOUNTS="--fusemount ${EESSI_PILOT_READONLY}"
  EESSI_FUSE_MOUNTS+=" --fusemount ${EESSI_PILOT_WRITABLE_OVERLAY}"
  export EESSI_FUSE_MOUNTS
fi


# 5. initialize local disk/tmp from previous run if provided


# 6. run container
echo "Launching container with command (next line):"
echo "singularity ${MODE} ${EESSI_FUSE_MOUNTS} ${CONTAINER} ${RUN_SCRIPT_AND_ARGS}"
singularity ${MODE} ${EESSI_FUSE_MOUNTS} ${CONTAINER} ${RUN_SCRIPT_AND_ARGS}
