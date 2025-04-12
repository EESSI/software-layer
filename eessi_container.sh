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

# -e: stop script as soon as any command has non-zero exit code
# -u: treat usage of undefined variables as errors
# FIXME commented out because it's OK (?) if some environment variables are not set (like $SINGULARITY_HOME)
# set -e -u

# script overview
# -. initial settings & exit codes
# 0. parse args
# 1. check if argument values are valid
# 2. set up host storage/tmp
# 3. set up common vars and directories
# 4. set up vars specific to a scenario
# 5. run container
# 6. save tmp (if requested)

# -. initial settings & exit codes
TOPDIR=$(dirname $(realpath $0))

source "${TOPDIR}"/scripts/utils.sh
source "${TOPDIR}"/scripts/cfg_files.sh

# exit codes: bitwise shift codes to allow for combination of exit codes
# ANY_ERROR_EXITCODE is sourced from ${TOPDIR}/scripts/utils.sh
CMDLINE_ARG_UNKNOWN_EXITCODE=$((${ANY_ERROR_EXITCODE} << 1))
ACCESS_UNKNOWN_EXITCODE=$((${ANY_ERROR_EXITCODE} << 2))
CONTAINER_ERROR_EXITCODE=$((${ANY_ERROR_EXITCODE} << 3))
HOST_STORAGE_ERROR_EXITCODE=$((${ANY_ERROR_EXITCODE} << 4))
MODE_UNKNOWN_EXITCODE=$((${ANY_ERROR_EXITCODE} << 5))
REPOSITORY_ERROR_EXITCODE=$((${ANY_ERROR_EXITCODE} << 6))
RESUME_ERROR_EXITCODE=$((${ANY_ERROR_EXITCODE} << 7))
SAVE_ERROR_EXITCODE=$((${ANY_ERROR_EXITCODE} << 8))
HTTP_PROXY_ERROR_EXITCODE=$((${ANY_ERROR_EXITCODE} << 9))
HTTPS_PROXY_ERROR_EXITCODE=$((${ANY_ERROR_EXITCODE} << 10))
RUN_SCRIPT_MISSING_EXITCODE=$((${ANY_ERROR_EXITCODE} << 11))
NVIDIA_MODE_UNKNOWN_EXITCODE=$((${ANY_ERROR_EXITCODE} << 12))

# CernVM-FS settings
CVMFS_VAR_LIB="var-lib-cvmfs"
CVMFS_VAR_RUN="var-run-cvmfs"

# directory for tmp used inside container
export TMP_IN_CONTAINER=/tmp

# repository cfg directory and file
#   directory: default $PWD or EESSI_REPOS_CFG_DIR_OVERRIDE if set
#   file: directory + '/repos.cfg'
export EESSI_REPOS_CFG_DIR="${EESSI_REPOS_CFG_DIR_OVERRIDE:=${PWD}}"
export EESSI_REPOS_CFG_FILE="${EESSI_REPOS_CFG_DIR}/repos.cfg"


# 0. parse args
#    see example parsing of command line arguments at
#    https://wiki.bash-hackers.org/scripting/posparams#using_a_while_loop
#    https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

display_help() {
  echo "usage: $0 [OPTIONS] [[--] SCRIPT or COMMAND]"
  echo " OPTIONS:"
  echo "  -a | --access {ro,rw}   - sets access globally for all CVMFS repositories:"
  echo "                            ro (read-only), rw (read & write) [default: ro]"
  echo "  -b | --extra-bind-paths - specify extra paths to be bound into the container."
  echo "                            To specify multiple bind paths, separate by comma."
  echo "                            Example: '/src:/dest:ro,/src2:/dest2:rw'"
  echo "  -c | --container IMG    - image file or URL defining the container to use"
  echo "                            [default: docker://ghcr.io/eessi/build-node:debian11]"
  echo "  -f | --fakeroot         - run the container with --fakeroot [default: false]"
  echo "  -g | --storage DIR      - directory space on host machine (used for"
  echo "                            temporary data) [default: 1. TMPDIR, 2. /tmp]"
  echo "  -h | --help             - display this usage information [default: false]"
  echo "  -i | --host-injections  - directory to link to for host_injections "
  echo "                            [default: /..storage../opt-eessi]"
  echo "  -l | --list-repos       - list available repository identifiers [default: false]"
  echo "  -m | --mode MODE        - with MODE==shell (launch interactive shell) or"
  echo "                            MODE==run (run a script or command) [default: shell]"
  echo "  -n | --nvidia MODE      - configure the container to work with NVIDIA GPUs,"
  echo "                            MODE==install for a CUDA installation, MODE==run to"
  echo "                            attach a GPU, MODE==all for both [default: false]"
  echo "  -p | --pass-through ARG - argument to pass through to the launch of the"
  echo "                            container; can be given multiple times [default: not set]"
  echo "  -r | --repository CFG   - configuration file or identifier defining the"
  echo "                            repository to use; can be given multiple times;"
  echo "                            CFG may include a suffix ',access={ro,rw}' to"
  echo "                            overwrite the global access mode for this repository"
  echo "                            [default: software.eessi.io via CVMFS config available"
  echo "                            via default container, see --container]"
  echo "  -u | --resume DIR/TGZ   - resume a previous run from a directory or tarball,"
  echo "                            where DIR points to a previously used tmp directory"
  echo "                            (check for output 'Using DIR as tmp ...' of a previous"
  echo "                            run) and TGZ is the path to a tarball which is"
  echo "                            unpacked the tmp dir stored on the local storage space"
  echo "                            (see option --storage above) [default: not set]"
  echo "  -s | --save DIR/TGZ     - save contents of tmp directory to a tarball in"
  echo "                            directory DIR or provided with the fixed full path TGZ"
  echo "                            when a directory is provided, the format of the"
  echo "                            tarball's name will be {REPO_ID}-{TIMESTAMP}.tgz"
  echo "                            [default: not set]"
  echo "  -v | --verbose          - display more information [default: false]"
  echo "  -x | --http-proxy URL   - provides URL for the env variable http_proxy"
  echo "                            [default: not set]; uses env var \$http_proxy if set"
  echo "  -y | --https-proxy URL  - provides URL for the env variable https_proxy"
  echo "                            [default: not set]; uses env var \$https_proxy if set"
  echo
  echo " If value for --mode is 'run', the SCRIPT/COMMAND provided is executed. If"
  echo " arguments to the script/command start with '-' or '--', use the flag terminator"
  echo " '--' to let eessi_container.sh stop parsing arguments."
}

# set defaults for command line arguments
ACCESS="ro"
CONTAINER="docker://ghcr.io/eessi/build-node:debian11"
#DRY_RUN=0
FAKEROOT=0
VERBOSE=0
STORAGE=
LIST_REPOS=0
MODE="shell"
PASS_THROUGH=()
SETUP_NVIDIA=0
REPOSITORIES=()
RESUME=
SAVE=
HTTP_PROXY=${http_proxy:-}
HTTPS_PROXY=${https_proxy:-}

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -a|--access)
      ACCESS="$2"
      shift 2
      ;;
    -b|--extra-bind-paths)
      EXTRA_BIND_PATHS="$2"
      shift 2
      ;;
    -c|--container)
      CONTAINER="$2"
      shift 2
      ;;
#    -d|--dry-run)
#      DRY_RUN=1
#      shift 1
#      ;;
    -f|--fakeroot)
      FAKEROOT=1
      shift 1
      ;;
    -g|--storage)
      STORAGE="$2"
      shift 2
      ;;
    -h|--help)
      display_help
      exit 0
      ;;
    -i|--host-injections)
      USER_HOST_INJECTIONS="$2"
      shift 2
      ;;
    -l|--list-repos)
      LIST_REPOS=1
      shift 1
      ;;
    -m|--mode)
      MODE="$2"
      shift 2
      ;;
    -n|--nvidia)
      SETUP_NVIDIA=1
      NVIDIA_MODE="$2"
      shift 2
      ;;
    -p|--pass-through)
      PASS_THROUGH+=("$2")
      shift 2
      ;;
    -r|--repository)
      REPOSITORIES+=("$2")
      shift 2
      ;;
    -s|--save)
      SAVE="$2"
      shift 2
      ;;
    -u|--resume)
      RESUME="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=1
      shift 1
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
    --)
      shift
      POSITIONAL_ARGS+=("$@") # save positional args
      break
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

# define a list of CVMFS repositories that are accessible via the
# CVMFS config repository which is always mounted
# TODO instead of hard-coding the 'extra' and 'default' repositories here one
#      could have another script in the GitHub and/or CVMFS repository which
#      provides this "configuration"
declare -A eessi_cvmfs_repos=(["dev.eessi.io"]="extra", ["riscv.eessi.io"]="extra", ["software.eessi.io"]="default")
eessi_default_cvmfs_repo="software.eessi.io,access=${ACCESS}"

# define a list of CVMFS repositories that are accessible via the
#   configuration file provided via $EESSI_REPOS_CFG_FILE
declare -A cfg_cvmfs_repos=()
if [[ -r ${EESSI_REPOS_CFG_FILE} ]]; then
    cfg_load ${EESSI_REPOS_CFG_FILE}
    sections=$(cfg_sections)
    while IFS= read -r repo_id
    do
        cfg_cvmfs_repos[${repo_id}]=${EESSI_REPOS_CFG_FILE}
    done <<< "${sections}"
fi

if [[ ${LIST_REPOS} -eq 1 ]]; then
    echo "Listing available repositories with format 'name [source[, 'default']]'."
    echo "Note, without argument '--repository' the one labeled 'default' will be mounted."
    for cvmfs_repo in "${!eessi_cvmfs_repos[@]}"
    do
        if [[ ${eessi_cvmfs_repos[${cvmfs_repo}]} == "default" ]] ; then
            default_label=", default"
        else
            default_label=""
        fi
        echo "    ${cvmfs_repo} [CVMFS config repo${default_label}]"
    done
    for cfg_repo in "${!cfg_cvmfs_repos[@]}"
    do
        echo "    ${cfg_repo} [${cfg_cvmfs_repos[$cfg_repo]}]"
    done
    exit 0
fi

# if REPOSITORIES is empty add default repository given above
if [[ ${#REPOSITORIES[@]} -eq 0 ]]; then
    REPOSITORIES+=(${eessi_default_cvmfs_repo})
fi

# 1. check if argument values are valid
# (arg -a|--access) check if ACCESS is supported
# use the value as global setting, suffix to --repository can specify an access mode per repository
if [[ "${ACCESS}" != "ro" && "${ACCESS}" != "rw" ]]; then
    fatal_error "unknown access method '${ACCESS}'" "${ACCESS_UNKNOWN_EXITCODE}"
fi

# TODO (arg -c|--container) check container (is it a file or URL & access those)
# CONTAINER_ERROR_EXITCODE

# TODO (arg -g|--storage) check if it exists, if user has write permission,
#      if it contains no data, etc.
# HOST_STORAGE_ERROR_EXITCODE

# (arg -m|--mode) check if MODE is known
if [[ "${MODE}" != "shell" && "${MODE}" != "run" ]]; then
    fatal_error "unknown execution mode '${MODE}'" "${MODE_UNKNOWN_EXITCODE}"
fi

# Also validate the NVIDIA GPU mode (if present)
if [[ ${SETUP_NVIDIA} -eq 1 ]]; then
    if [[ "${NVIDIA_MODE}" != "run" && "${NVIDIA_MODE}" != "install" && "${NVIDIA_MODE}" != "all" ]]; then
        fatal_error "unknown NVIDIA mode '${NVIDIA_MODE}'" "${NVIDIA_MODE_UNKNOWN_EXITCODE}"
    fi
fi

# TODO (arg -r|--repository) check if all explicitly listed repositories are known
# REPOSITORY_ERROR_EXITCODE
# iterate over entries in REPOSITORIES and check if they are known
for cvmfs_repo in "${REPOSITORIES[@]}"
do
    # split into name and access mode if ',access=' in $cvmfs_repo
    if [[ ${cvmfs_repo} == *",access="* ]] ; then
        cvmfs_repo_name=${cvmfs_repo/,access=*/} # remove access mode specification
    else
        cvmfs_repo_name="${cvmfs_repo}"
    fi
    if [[ ! -n "${eessi_cvmfs_repos[${cvmfs_repo_name}]}" && ! -n ${cfg_cvmfs_repos[${cvmfs_repo_name}]} ]]; then
        fatal_error "The repository '${cvmfs_repo_name}' is not an EESSI CVMFS repository or it is not known how to mount it (could be due to a typo or missing configuration). Run '$0 -l' to obtain a list of available repositories." "${REPOSITORY_ERROR_EXITCODE}"
    fi
done

# make sure each repository is only listed once
declare -A listed_repos=()
for cvmfs_repo in "${REPOSITORIES[@]}"
do
    cvmfs_repo_name=${cvmfs_repo/,access=*/} # remove access mode
    [[ ${VERBOSE} -eq 1 ]] && echo "checking for duplicates: '${cvmfs_repo}' and '${cvmfs_repo_name}'"
    # if cvmfs_repo_name is not in eessi_cvmfs_repos, assume it's in cfg_cvmfs_repos
    #   and obtain actual repo_name from config
    cfg_repo_id=''
    if [[ ! -n "${eessi_cvmfs_repos[${cvmfs_repo_name}]}" ]] ; then
        [[ ${VERBOSE} -eq 1 ]] && echo "repo '${cvmfs_repo_name}' is not an EESSI CVMFS repository..."
        # cvmfs_repo_name is actually a repository ID, use that to obtain
        #   the actual name from the EESSI_REPOS_CFG_FILE
        cfg_repo_id=${cvmfs_repo_name}
        cvmfs_repo_name=$(cfg_get_value ${cfg_repo_id} "repo_name")
    fi
    if [[ -n "${listed_repos[${cvmfs_repo_name}]}" ]] ; then
        via_cfg=""
        if [[ -n "${cfg_repo_id}" ]] ; then
            via_cfg=" (via repository ID '${cfg_repo_id}')"
        fi
        fatal_error "CVMFS repository '${cvmfs_repo_name}'${via_cfg} listed multiple times"
    fi
    listed_repos+=([${cvmfs_repo_name}]=true)
done

# TODO (arg -u|--resume) check if it exists, if user has read permission,
#      if it contains data from a previous run
# RESUME_ERROR_EXITCODE

# TODO (arg -s|--save) check if DIR exists, if user has write permission,
#   if TGZ already exists, if user has write permission to directory to which
#   TGZ should be written
# SAVE_ERROR_EXITCODE

# TODO (arg -x|--http-proxy) check if http proxy is accessible
# HTTP_PROXY_ERROR_EXITCODE

# TODO (arg -y|--https-proxy) check if https proxy is accessible
# HTTPS_PROXY_ERROR_EXITCODE

# check if a script is provided if mode is 'run'
if [[ "${MODE}" == "run" ]]; then
  if [[ $# -eq 0 ]]; then
    fatal_error "no command specified to run?!" "${RUN_SCRIPT_MISSING_EXITCODE}"
  fi
fi


# 2. set up host storage/tmp if necessary
# if session to be resumed from a previous one (--resume ARG) and ARG is a directory
#   just reuse ARG, define environment variables accordingly and skip creating a new
#   tmp storage
if [[ ! -z ${RESUME} && -d ${RESUME} ]]; then
  # resume from directory ${RESUME}
  #   skip creating a new tmp directory, just set environment variables
  echo "Resuming from previous run using temporary storage at ${RESUME}"
  EESSI_HOST_STORAGE=${RESUME}
else
  # we need a tmp location (and possibly init it with ${RESUME} if it was not
  #   a directory

  # as location for temporary data use in the following order
  #   a. command line argument -l|--host-storage
  #   b. env var TMPDIR
  #   c. /tmp
  # note, we ensure that (a) takes precedence by setting TMPDIR to STORAGE
  #     if STORAGE is not empty
  # note, (b) & (c) are automatically ensured by using 'mktemp -d --tmpdir' to
  #     create a temporary directory
  if [[ ! -z ${STORAGE} ]]; then
    export TMPDIR=${STORAGE}
    # mktemp fails if TMPDIR does not exist, so let's create it
    mkdir -p ${TMPDIR}
  fi
  if [[ ! -z ${TMPDIR} ]]; then
    # TODO check if TMPDIR already exists
    # mktemp fails if TMPDIR does not exist, so let's create it
    mkdir -p ${TMPDIR}
  fi
  if [[ -z ${TMPDIR} ]]; then
    # mktemp falls back to using /tmp if TMPDIR is empty
    # TODO check if /tmp is writable, large enough and usable (different
    #      features for ro-access and rw-access)
    [[ ${VERBOSE} -eq 1 ]] && echo "skipping sanity checks for /tmp"
  fi
  EESSI_HOST_STORAGE=$(mktemp -d --tmpdir eessi.XXXXXXXXXX)
  echo "Using ${EESSI_HOST_STORAGE} as tmp directory (to resume session add '--resume ${EESSI_HOST_STORAGE}')."
fi

# if ${RESUME} is a file, unpack it into ${EESSI_HOST_STORAGE}
if [[ ! -z ${RESUME} && -f ${RESUME} ]]; then
  if [[ "${RESUME}" == *.tgz ]]; then
    tar xf ${RESUME} -C ${EESSI_HOST_STORAGE}
  # Add support for resuming from zstd-compressed tarballs
  elif [[ "${RESUME}" == *.zst && -x "$(command -v zstd)" ]]; then
    zstd -dc ${RESUME} | tar -xf - -C ${EESSI_HOST_STORAGE}
  elif [[ "${RESUME}" == *.zst && ! -x "$(command -v zstd)" ]]; then
    fatal_error "Trying to resume from tarball ${RESUME} which was compressed using zstd, but zstd command not found"
  fi
  echo "Resuming from previous run using temporary storage ${RESUME} unpacked into ${EESSI_HOST_STORAGE}"
fi

# if ${RESUME} is a file (assume a tgz), unpack it into ${EESSI_HOST_STORAGE}
if [[ ! -z ${RESUME} && -f ${RESUME} ]]; then
  tar xf ${RESUME} -C ${EESSI_HOST_STORAGE}
  echo "Resuming from previous run using temporary storage ${RESUME} unpacked into ${EESSI_HOST_STORAGE}"
fi

# 3. set up common vars and directories
#    directory structure should be:
#      ${EESSI_HOST_STORAGE}
#      |-singularity_cache
#      |-home
#      |-repos_cfg
#      |-${CVMFS_VAR_LIB}
#      |-${CVMFS_VAR_RUN}
#      |-CVMFS_REPO_1
#      |   |-repo_settings.sh (name, id, access, host_injections)
#      |   |-overlay-upper
#      |   |-overlay-work
#      |   |-opt-eessi (unless otherwise specificed for host_injections)
#      |-CVMFS_REPO_n
#          |-repo_settings.sh (name, id, access, host_injections)
#          |-overlay-upper
#          |-overlay-work
#          |-opt-eessi (unless otherwise specificed for host_injections)

# tmp dir for EESSI
EESSI_TMPDIR=${EESSI_HOST_STORAGE}
mkdir -p ${EESSI_TMPDIR}
[[ ${VERBOSE} -eq 1 ]] && echo "EESSI_TMPDIR=${EESSI_TMPDIR}"

# TODO make this specific to repository?
# TODO move this code to when we already know which repositories we want to access
#      actually we should know this already here, but we should rather move this to
#      where repository args are being processed
# Set host_injections directory and ensure it is a writable directory (if user provided)
if [ -z ${USER_HOST_INJECTIONS+x} ]; then
    # Not set, so use our default
    HOST_INJECTIONS=${EESSI_TMPDIR}/opt-eessi
    mkdir -p $HOST_INJECTIONS
else
    # Make sure the host_injections directory specified exists and is a folder
    mkdir -p ${USER_HOST_INJECTIONS} || fatal_error "host_injections directory ${USER_HOST_INJECTIONS} is either not a directory or cannot be created"
    HOST_INJECTIONS=${USER_HOST_INJECTIONS}
fi
[[ ${VERBOSE} -eq 1 ]] && echo "HOST_INJECTIONS=${HOST_INJECTIONS}"

# configure Singularity: if SINGULARITY_CACHEDIR is already defined, use that
#   a global SINGULARITY_CACHEDIR would ensure that we don't consume
#   storage space again and again for the container & also speed-up
#   launch times across different sessions
if [[ -z ${SINGULARITY_CACHEDIR} ]]; then
    export SINGULARITY_CACHEDIR=${EESSI_TMPDIR}/singularity_cache
    mkdir -p ${SINGULARITY_CACHEDIR}
fi
[[ ${VERBOSE} -eq 1 ]] && echo "SINGULARITY_CACHEDIR=${SINGULARITY_CACHEDIR}"

# if VERBOSE is set to 0 (no arg --verbose), add argument '-q'
if [[ ${VERBOSE} -eq 0 ]]; then
    RUN_QUIET='-q'
else
    RUN_QUIET=''
fi

# we try our best to make sure that we retain access to the container image in
# a subsequent session ("best effort" only because pulling or copying operations
# can fail ... in those cases the script may still succeed, but it is not
# guaranteed that we have access to the same container when resuming later on)
# - if CONTAINER references an image in a registry, pull & convert image
#   and store it in ${EESSI_TMPDIR}
#   + however, only pull image if there is no matching image in ${EESSI_TMPDIR} yet
# - if CONTAINER references an image file, copy it to ${EESSI_TMPDIR}
#   + however, only copy it if its base name does not yet exist in ${EESSI_TMPDIR}
# - if the image file created (pulled or copied) or resumed exists in
#   ${EESSI_TMPDIR}, let CONTAINER point to it
#   + thus subsequent singularity commands in this script would just use the
#     image file in EESSI_TMPDIR or the originally given source (some URL or
#     path to an image file)
CONTAINER_IMG=
CONTAINER_URL_FMT=".*://(.*)"
if [[ ${CONTAINER} =~ ${CONTAINER_URL_FMT} ]]; then
    # replace ':', '-', '/' with '_' in match (everything after ://) and append .sif
    CONTAINER_IMG="$(echo ${BASH_REMATCH[1]} | sed 's/[:\/-]/_/g').sif"
    # pull container to ${EESSI_TMPDIR} if it is not there yet (i.e. when
    # resuming from a previous session)
    if [[ ! -x ${EESSI_TMPDIR}/${CONTAINER_IMG} ]]; then
        echo "Pulling container image from ${CONTAINER} to ${EESSI_TMPDIR}/${CONTAINER_IMG}"
        singularity ${RUN_QUIET} pull ${EESSI_TMPDIR}/${CONTAINER_IMG} ${CONTAINER}
    else
        echo "Reusing existing container image ${EESSI_TMPDIR}/${CONTAINER_IMG}"
    fi
else
    # determine file name as basename of CONTAINER
    CONTAINER_IMG=$(basename ${CONTAINER})
    # copy image file to ${EESSI_TMPDIR} if it is not there yet (i.e. when
    # resuming from a previous session)
    if [[ ! -x ${EESSI_TMPDIR}/${CONTAINER_IMG} ]]; then
        echo "Copying container image from ${CONTAINER} to ${EESSI_TMPDIR}/${CONTAINER_IMG}"
        cp -a ${CONTAINER} ${EESSI_TMPDIR}/.
    else
        echo "Reusing existing container image ${EESSI_TMPDIR}/${CONTAINER_IMG}"
    fi
fi
# let CONTAINER point to the pulled, copied or resumed image file
if [[ -x ${EESSI_TMPDIR}/${CONTAINER_IMG} ]]; then
    CONTAINER="${EESSI_TMPDIR}/${CONTAINER_IMG}"
fi
[[ ${VERBOSE} -eq 1 ]] && echo "CONTAINER=${CONTAINER}"

# set env vars and create directories for CernVM-FS
EESSI_CVMFS_VAR_LIB=${EESSI_TMPDIR}/${CVMFS_VAR_LIB}
EESSI_CVMFS_VAR_RUN=${EESSI_TMPDIR}/${CVMFS_VAR_RUN}
mkdir -p ${EESSI_CVMFS_VAR_LIB}
mkdir -p ${EESSI_CVMFS_VAR_RUN}
[[ ${VERBOSE} -eq 1 ]] && echo "EESSI_CVMFS_VAR_LIB=${EESSI_CVMFS_VAR_LIB}"
[[ ${VERBOSE} -eq 1 ]] && echo "EESSI_CVMFS_VAR_RUN=${EESSI_CVMFS_VAR_RUN}"

# allow that SINGULARITY_HOME is defined before script is run
if [[ -z ${SINGULARITY_HOME} ]]; then
  export SINGULARITY_HOME="${EESSI_TMPDIR}/home:/home/${USER}"
  mkdir -p ${EESSI_TMPDIR}/home
fi
[[ ${VERBOSE} -eq 1 ]] && echo "SINGULARITY_HOME=${SINGULARITY_HOME}"

# define paths to add to SINGULARITY_BIND (added later when all BIND mounts are defined)
BIND_PATHS="${EESSI_CVMFS_VAR_LIB}:/var/lib/cvmfs,${EESSI_CVMFS_VAR_RUN}:/var/run/cvmfs,${HOST_INJECTIONS}:/opt/eessi"

# provide a '/tmp' inside the container
BIND_PATHS="${BIND_PATHS},${EESSI_TMPDIR}:${TMP_IN_CONTAINER}"

# if TMPDIR is not empty and if TMP_IN_CONTAINER is not a prefix of TMPDIR, we need to add a bind mount for TMPDIR
if [[ ! -z ${TMPDIR} && ${TMP_IN_CONTAINER} != ${TMPDIR}* ]]; then
    msg="TMPDIR is not empty (${TMPDIR}) and TMP_IN_CONTAINER (${TMP_IN_CONTAINER}) is not a prefix of TMPDIR:"
    msg="${msg} adding bind mount for TMPDIR"
    echo "${msg}"
    BIND_PATHS="${BIND_PATHS},${TMPDIR}"
fi

if [[ ! -z ${EXTRA_BIND_PATHS} ]]; then
    BIND_PATHS="${BIND_PATHS},${EXTRA_BIND_PATHS}"
fi

[[ ${VERBOSE} -eq 1 ]] && echo "BIND_PATHS=${BIND_PATHS}"

declare -a ADDITIONAL_CONTAINER_OPTIONS=()

# Configure anything we need for NVIDIA GPUs and CUDA installation
if [[ ${SETUP_NVIDIA} -eq 1 ]]; then
    if [[ "${NVIDIA_MODE}" == "run" || "${NVIDIA_MODE}" == "all" ]]; then
        # Give singularity the appropriate flag
        ADDITIONAL_CONTAINER_OPTIONS+=("--nv")
        [[ ${VERBOSE} -eq 1 ]] && echo "ADDITIONAL_CONTAINER_OPTIONS=${ADDITIONAL_CONTAINER_OPTIONS[@]}"
    fi
    if [[ "${NVIDIA_MODE}" == "install" || "${NVIDIA_MODE}" == "all" ]]; then
        # Add additional bind mounts to allow CUDA to install within a container
        # (Experience tells us that these are necessary, but we don't know _why_
        # as the CUDA installer is a black box. The suspicion is that the CUDA
        # installer gets confused by the permissions on these directories when
        # inside a container)
        EESSI_VAR_LOG=${EESSI_TMPDIR}/var-log
        EESSI_USR_LOCAL_CUDA=${EESSI_TMPDIR}/usr-local-cuda
        mkdir -p ${EESSI_VAR_LOG}
        mkdir -p ${EESSI_USR_LOCAL_CUDA}
        BIND_PATHS="${BIND_PATHS},${EESSI_VAR_LOG}:/var/log,${EESSI_USR_LOCAL_CUDA}:/usr/local/cuda"
        [[ ${VERBOSE} -eq 1 ]] && echo "BIND_PATHS=${BIND_PATHS}"
        if [[ "${NVIDIA_MODE}" == "install" ]] ; then
            # No GPU so we need to "trick" Lmod to allow us to load CUDA modules even without a CUDA driver
            # (this variable means EESSI_OVERRIDE_GPU_CHECK=1 will be set inside the container)
            export SINGULARITYENV_EESSI_OVERRIDE_GPU_CHECK=1
        fi
    fi
fi

# Configure the fakeroot setting for the container
if [[ ${FAKEROOT} -eq 1 ]]; then
  ADDITIONAL_CONTAINER_OPTIONS+=("--fakeroot")
fi

# set up repository config (always create directory repos_cfg and populate it with info when
# arg -r|--repository is used)
mkdir -p ${EESSI_TMPDIR}/repos_cfg
[[ ${VERBOSE} -eq 1 ]] && echo
[[ ${VERBOSE} -eq 1 ]] && echo -e "BIND_PATHS before processing REPOSITORIES\n  BIND_PATHS=${BIND_PATHS}"
[[ ${VERBOSE} -eq 1 ]] && echo
# iterate over repositories in array REPOSITORIES
for cvmfs_repo in "${REPOSITORIES[@]}"
do
    [[ ${VERBOSE} -eq 1 ]] && echo "process CVMFS repo spec '${cvmfs_repo}'"
    # split into name and access mode if ',access=' in $cvmfs_repo
    if [[ ${cvmfs_repo} == *",access="* ]] ; then
        cvmfs_repo_name=${cvmfs_repo/,access=*/} # remove access mode specification
        cvmfs_repo_access=${cvmfs_repo/*,access=/} # remove repo name part
    else
        cvmfs_repo_name="${cvmfs_repo}"
        cvmfs_repo_access="${ACCESS}" # use globally defined access mode
    fi
    # if cvmfs_repo_name is in cfg_cvmfs_repos, it is a "repository ID" and was
    #   derived from information in EESSI_REPOS_CFG_FILE, namely the section
    #   names in that .ini-type file
    # in the if-block below, we'll use cfg_repo_id to refer to that ID
    # we need to process/provide the config from EESSI_REPOS_CFG_FILE, such
    #   that the necessary information for accessing a CVMFS repository is made
    #   available inside the container
    if [[ -n "${cfg_cvmfs_repos[${cvmfs_repo_name}]}" ]] ; then
        cfg_repo_id=${cvmfs_repo_name}

        # obtain CVMFS repository name from section for the given ID
        cfg_repo_name=$(cfg_get_value ${cfg_repo_id} "repo_name")
        # derive domain part from (cfg_)repo_name (everything after first '.')
        repo_name_domain=${repo_name#*.}

        # cfg_cvmfs_repos is populated through reading the file pointed to by
        #   EESSI_REPOS_CFG_FILE. We need to copy that file and data it needs
        #   into the job's working directory.

        # copy repos.cfg to job directory --> makes it easier to inspect the job
        cp -a ${EESSI_REPOS_CFG_FILE} ${EESSI_TMPDIR}/repos_cfg/.

        # cfg file should include sections (one per CVMFS repository to be mounted)
        #   with each section containing the settings:
        #   - repo_name,
        #   - repo_version,
        #   - config_bundle, and
        #   - a map { filepath_in_bundle -> container_filepath }
        #
        # The config_bundle includes the files which are mapped ('->') to a target
        # location in container:
        # - default.local -> /etc/cvmfs/default.local
        #   contains CVMFS settings, e.g., CVMFS_HTTP_PROXY, CVMFS_QUOTA_LIMIT, ...
        # - ${repo_name_domain}.conf -> /etc/cvmfs/domain.d/${repo_name_domain}.conf
        #   contains CVMFS settings, e.g., CVMFS_SERVER_URL (Stratum 1s),
        #   CVMFS_KEYS_DIR, CVMFS_USE_GEOAPI, ...
        # - ${repo_name_domain}/ -> /etc/cvmfs/keys/${repo_name_domain}
        #   a directory that contains the public key to access the repository, key
        #   itself then doesn't need to be BIND mounted
        # - ${repo_name_domain}/${cfg_repo_name}.pub
        #   (-> /etc/cvmfs/keys/${repo_name_domain}/${cfg_repo_name}.pub
        #   the public key to access the repository, key itself is BIND mounted
        #   via directory ${repo_name_domain}
        cfg_repo_version=$(cfg_get_value ${cfg_repo_id} "repo_version")
        cfg_config_bundle=$(cfg_get_value ${cfg_repo_id} "config_bundle")
        cfg_config_map=$(cfg_get_value ${cfg_repo_id} "config_map")

        # convert cfg_config_map into associative array cfg_file_map
        cfg_init_file_map "${cfg_config_map}"
        [[ ${VERBOSE} -eq 1 ]] && cfg_print_map

        # use information to set up dir ${EESSI_TMPDIR}/repos_cfg and define
        #   BIND mounts
        # check if config_bundle exists, if so, unpack it into
        #   ${EESSI_TMPDIR}/repos_cfg; if it doesn't, exit with an error
        # if config_bundle is relative path (no '/' at start) prepend it with
        #   EESSI_REPOS_CFG_DIR
        config_bundle_path=
        if [[ ! "${cfg_config_bundle}" =~ ^/ ]]; then
            config_bundle_path=${EESSI_REPOS_CFG_DIR}/${cfg_config_bundle}
        else
            config_bundle_path=${cfg_config_bundle}
        fi

        if [[ ! -r ${config_bundle_path} ]]; then
            fatal_error "config bundle '${config_bundle_path}' is not readable" ${REPOSITORY_ERROR_EXITCODE}
        fi

        # only unpack cfg_config_bundle if we're not resuming from a previous run
        if [[ -z ${RESUME} ]]; then
            tar xf ${config_bundle_path} -C ${EESSI_TMPDIR}/repos_cfg
        fi

        for src in "${!cfg_file_map[@]}"
        do
            target=${cfg_file_map[${src}]}
            # if target is alreay BIND mounted, exit with an error
            if [[ ${BIND_PATHS} =~ "${target}" ]]; then
                fatal_error "target '${target}' is already listed in paths to bind mount into the container ('${BIND_PATHS}')" ${REPOSITORY_ERROR_EXITCODE}
            fi
            BIND_PATHS="${BIND_PATHS},${EESSI_TMPDIR}/repos_cfg/${src}:${target}"
        done
    fi
    [[ ${VERBOSE} -eq 1 ]] && echo -e "BIND_PATHS after processing '${cvmfs_repo}'\n  BIND_PATHS=${BIND_PATHS}"
    [[ ${VERBOSE} -eq 1 ]] && echo
done

# if http_proxy is not empty, we assume that the machine accesses internet
# via a proxy. then we need to add CVMFS_HTTP_PROXY to
# ${EESSI_TMPDIR}/repos_cfg/default.local on the host (and possibly add a BIND
# MOUNT if it was not yet in BIND_PATHS)
if [[ ! -z ${http_proxy} ]]; then
    # TODO tolerate other formats for proxy URLs, for now assume format is
    # http://SOME_HOSTNAME:SOME_PORT/
    [[ ${VERBOSE} -eq 1 ]] && echo "http_proxy='${http_proxy}'"
    PROXY_HOST=$(get_host_from_url ${http_proxy})
    [[ ${VERBOSE} -eq 1 ]] && echo "PROXY_HOST='${PROXY_HOST}'"
    PROXY_PORT=$(get_port_from_url ${http_proxy})
    [[ ${VERBOSE} -eq 1 ]] && echo "PROXY_PORT='${PROXY_PORT}'"
    HTTP_PROXY_IPV4=$(get_ipv4_address ${PROXY_HOST})
    [[ ${VERBOSE} -eq 1 ]] && echo "HTTP_PROXY_IPV4='${HTTP_PROXY_IPV4}'"
    echo "CVMFS_HTTP_PROXY=\"${http_proxy}|http://${HTTP_PROXY_IPV4}:${PROXY_PORT}\"" \
       >> ${EESSI_TMPDIR}/repos_cfg/default.local
    [[ ${VERBOSE} -eq 1 ]] && echo "contents of default.local"
    [[ ${VERBOSE} -eq 1 ]] && cat ${EESSI_TMPDIR}/repos_cfg/default.local

    # if default.local is not BIND mounted into container, add it to BIND_PATHS
    src=${EESSI_TMPDIR}/repos_cfg/default.local
    target=/etc/cvmfs/default.local
    if [[ ${BIND_PATHS} =~ "${target}" ]]; then
        fatal_error "BIND target in '${src}:${target}' is already in paths to be bind mounted into the container ('${BIND_PATHS}')" ${REPOSITORY_ERROR_EXITCODE}
    fi
    BIND_PATHS="${BIND_PATHS},${src}:${target}"
fi

# 4. set up vars and dirs specific to a scenario

declare -a EESSI_FUSE_MOUNTS=()

# mount cvmfs-config repo (to get access to EESSI repositories such as software.eessi.io) unless env var
# EESSI_DO_NOT_MOUNT_CVMFS_CONFIG_CERN_CH is defined
if [ -z ${EESSI_DO_NOT_MOUNT_CVMFS_CONFIG_CERN_CH+x} ]; then
    EESSI_FUSE_MOUNTS+=("--fusemount" "container:cvmfs2 cvmfs-config.cern.ch /cvmfs/cvmfs-config.cern.ch")
fi


# iterate over REPOSITORIES and either use repository-specific access mode or global setting (possibly a global default)
for cvmfs_repo in "${REPOSITORIES[@]}"
do
    unset cfg_repo_id
    [[ ${VERBOSE} -eq 1 ]] && echo "add fusemount options for CVMFS repo '${cvmfs_repo}'"
    # split into name and access mode if ',access=' in $cvmfs_repo
    if [[ ${cvmfs_repo} == *",access="* ]] ; then
        cvmfs_repo_name=${cvmfs_repo/,access=*/} # remove access mode specification
        cvmfs_repo_access=${cvmfs_repo/*,access=/} # remove repo name part
    else
        cvmfs_repo_name="${cvmfs_repo}"
        cvmfs_repo_access="${ACCESS}" # use globally defined access mode
    fi
    # obtain cvmfs_repo_name from EESSI_REPOS_CFG_FILE if cvmfs_repo is in cfg_cvmfs_repos
    if [[ ${cfg_cvmfs_repos[${cvmfs_repo_name}]} ]]; then
        [[ ${VERBOSE} -eq 1 ]] && echo "repo '${cvmfs_repo_name}' is not an EESSI CVMFS repository..."
        # cvmfs_repo_name is actually a repository ID, use that to obtain
        #   the actual name from the EESSI_REPOS_CFG_FILE
        cfg_repo_id=${cvmfs_repo_name}
        cvmfs_repo_name=$(cfg_get_value ${cfg_repo_id} "repo_name")
    fi

    # always create a directory for the repository (e.g., to store settings, ...)
    mkdir -p ${EESSI_TMPDIR}/${cvmfs_repo_name}

    # add fusemount options depending on requested access mode ('ro' - read-only; 'rw' - read & write)
    if [[ ${cvmfs_repo_access} == "ro" ]] ; then
        # need to distinguish between basic "ro" access and "ro" after a "rw" session
        if [[ -d ${EESSI_TMPDIR}/${cvmfs_repo_name}/overlay-upper ]]; then
            # the overlay-upper directory is only created in a read-write-session, thus
            # we are resuming from such a session here (otherwise there shouldn't be such
            # directory yet as it is only created for read-write-sessions a bit further
            # below); the overlay-upper directory can only exist because it is part of
            # the ${RESUME} directory or tarball
            # to be able to see the contents of the read-write session we have to mount
            # the fuse-overlayfs (in read-only mode) on top of the CernVM-FS repository

            echo "While processing '${cvmfs_repo_name}' to be mounted 'read-only' we detected an overlay-upper"
            echo "  directory (${EESSI_TMPDIR}/${cvmfs_repo_name}/overlay-upper) likely from a previous"
            echo "  session. Will use it as left-most directory in 'lowerdir' argument for fuse-overlayfs."

            # make the target CernVM-FS repository available under /cvmfs_ro
            export EESSI_READONLY="container:cvmfs2 ${cvmfs_repo_name} /cvmfs_ro/${cvmfs_repo_name}"

            EESSI_FUSE_MOUNTS+=("--fusemount" "${EESSI_READONLY}")

            # now, put the overlay-upper read-only on top of the repo and make it available under the usual prefix /cvmfs
            EESSI_READONLY_OVERLAY="container:fuse-overlayfs"
            # The contents of the previous session are available under
            #   ${EESSI_TMPDIR} which is bind mounted to ${TMP_IN_CONTAINER}.
            #   Hence, we have to use ${TMP_IN_CONTAINER}/${cvmfs_repo_name}/overlay-upper
            # the left-most directory given for the lowerdir argument is put on top,
            #   and with no upperdir=... the whole overlayfs is made available read-only
            EESSI_READONLY_OVERLAY+=" -o lowerdir=${TMP_IN_CONTAINER}/${cvmfs_repo_name}/overlay-upper:/cvmfs_ro/${cvmfs_repo_name}"
            EESSI_READONLY_OVERLAY+=" /cvmfs/${cvmfs_repo_name}"
            export EESSI_READONLY_OVERLAY

            EESSI_FUSE_MOUNTS+=("--fusemount" "${EESSI_READONLY_OVERLAY}")
            export EESSI_FUSE_MOUNTS
        else
            # basic "ro" access that doesn't require any fuseoverlay-fs
            echo "Mounting '${cvmfs_repo_name}' 'read-only' without fuse-overlayfs."

            export EESSI_READONLY="container:cvmfs2 ${cvmfs_repo_name} /cvmfs/${cvmfs_repo_name}"

            EESSI_FUSE_MOUNTS+=("--fusemount" "${EESSI_READONLY}")
            export EESSI_FUSE_MOUNTS
        fi
    elif [[ ${cvmfs_repo_access} == "rw" ]] ; then
        # use repo-specific overlay directories
        mkdir -p ${EESSI_TMPDIR}/${cvmfs_repo_name}/overlay-upper
        mkdir -p ${EESSI_TMPDIR}/${cvmfs_repo_name}/overlay-work
        [[ ${VERBOSE} -eq 1 ]] && echo -e "TMP directory contents:\n$(ls -l ${EESSI_TMPDIR})"

        # set environment variables for fuse mounts in Singularity container
        export EESSI_READONLY="container:cvmfs2 ${cvmfs_repo_name} /cvmfs_ro/${cvmfs_repo_name}"

        EESSI_FUSE_MOUNTS+=("--fusemount" "${EESSI_READONLY}")

        EESSI_WRITABLE_OVERLAY="container:fuse-overlayfs"
        EESSI_WRITABLE_OVERLAY+=" -o lowerdir=/cvmfs_ro/${cvmfs_repo_name}"
        EESSI_WRITABLE_OVERLAY+=" -o upperdir=${TMP_IN_CONTAINER}/${cvmfs_repo_name}/overlay-upper"
        EESSI_WRITABLE_OVERLAY+=" -o workdir=${TMP_IN_CONTAINER}/${cvmfs_repo_name}/overlay-work"
        EESSI_WRITABLE_OVERLAY+=" /cvmfs/${cvmfs_repo_name}"
        export EESSI_WRITABLE_OVERLAY

        EESSI_FUSE_MOUNTS+=("--fusemount" "${EESSI_WRITABLE_OVERLAY}")
        export EESSI_FUSE_MOUNTS
    else
        echo -e "ERROR: access mode '${cvmfs_repo_access}' for CVMFS repository\n  '${cvmfs_repo_name}' is not known"
        exit ${REPOSITORY_ERROR_EXITCODE}
    fi
    # create repo_settings.sh file in ${EESSI_TMPDIR}/${cvmfs_repo_name} to store
    #   (intention is that the file could be just sourced to obtain the settings)
    # repo_name = ${cvmfs_repo_name}
    # repo_id = ${cfg_repo_id} # empty if not an EESSI repo
    # repo_access = ${cvmfs_repo_access}
    # repo_host_injections = [ {"src_path":"target_path"}... ] # TODO
    settings=
    #[[ -n ${cfg_repo_id} ]] && settings="[${cvmfs_repo_name}]\n" || settings="[${cfg_repo_id}]\n"
    settings="${settings}repo_name = ${cvmfs_repo_name}\n"
    settings="${settings}repo_id = ${cfg_repo_id}\n"
    settings="${settings}repo_access = ${cvmfs_repo_access}\n"
    # TODO iterate over host_injections (first need means to define them (globally and/or per repository)
    # settings="${settings}repo_host_injections = ${host_injections}\n"
    echo -e "${settings}" > ${EESSI_TMPDIR}/${cvmfs_repo_name}/repo_settings.sh
done

# 5. run container
# final settings
if [[ -z ${SINGULARITY_BIND} ]]; then
    export SINGULARITY_BIND="${BIND_PATHS}"
else
    export SINGULARITY_BIND="${SINGULARITY_BIND},${BIND_PATHS}"
fi
[[ ${VERBOSE} -eq 1 ]] && echo "SINGULARITY_BIND=${SINGULARITY_BIND}"

# pass $EESSI_SOFTWARE_SUBDIR_OVERRIDE into build container (if set)
if [ ! -z ${EESSI_SOFTWARE_SUBDIR_OVERRIDE} ]; then
    export SINGULARITYENV_EESSI_SOFTWARE_SUBDIR_OVERRIDE=${EESSI_SOFTWARE_SUBDIR_OVERRIDE}
    # also specify via $APPTAINERENV_* (future proof, cfr. https://apptainer.org/docs/user/latest/singularity_compatibility.html#singularity-environment-variable-compatibility)
    export APPTAINERENV_EESSI_SOFTWARE_SUBDIR_OVERRIDE=${EESSI_SOFTWARE_SUBDIR_OVERRIDE}
fi

# add pass through arguments
for arg in "${PASS_THROUGH[@]}"; do
    ADDITIONAL_CONTAINER_OPTIONS+=(${arg})
done

echo "Launching container with command (next line):"
echo "singularity ${RUN_QUIET} ${MODE} ${ADDITIONAL_CONTAINER_OPTIONS[@]} ${EESSI_FUSE_MOUNTS[@]} ${CONTAINER} $@"
singularity ${RUN_QUIET} ${MODE} "${ADDITIONAL_CONTAINER_OPTIONS[@]}" "${EESSI_FUSE_MOUNTS[@]}" ${CONTAINER} "$@"
exit_code=$?

# 6. save tmp if requested (arg -s|--save)
if [[ ! -z ${SAVE} ]]; then
  # Note, for now we don't try to be smart and record in any way the OS and
  #   ARCH which might have been used internally, eg, when software packages
  #   were built ... we rather keep the script here "stupid" and leave the handling
  #   of these aspects to where the script is used
  # Compression with zlib may be quite slow. On some systems, the pipeline takes ~20 mins for a 2 min build because of this.
  # Check if zstd is present for faster compression and decompression
  if [[ -d ${SAVE} ]]; then
    # assume SAVE is name of a directory to which tarball shall be written to
    #   name format: tmp_storage-{TIMESTAMP}.tgz
    ts=$(date +%s)
    if [[ -x "$(command -v zstd)" ]]; then
      TARBALL=${SAVE}/tmp_storage-${ts}.zst
      tar -cf - -C ${EESSI_TMPDIR} . | zstd -T0 > ${TARBALL}
    else
      TARBALL=${SAVE}/tmp_storage-${ts}.tgz
      tar czf ${TARBALL} -C ${EESSI_TMPDIR} .
    fi
  else
    # assume SAVE is the full path to a tarball's name
    TARBALL=${SAVE}
    # if zstd is present and a .zst extension is asked for, use it
    if [[ "${SAVE}" == *.zst && -x "$(command -v zstd)" ]]; then
      tar -cf - -C ${EESSI_TMPDIR} . | zstd -T0 > ${TARBALL}
    else
      tar czf ${TARBALL} -C ${EESSI_TMPDIR}
    fi
  fi
  echo "Saved contents of tmp directory '${EESSI_TMPDIR}' to tarball '${TARBALL}' (to resume session add '--resume ${TARBALL}')"
fi

# TODO clean up tmp by default? only retain if another option provided (--retain-tmp)

# use exit code of container command
exit ${exit_code}
