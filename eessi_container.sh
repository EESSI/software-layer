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
# 2. set up host storage/tmp
# 3. set up common vars and directories
# 4. set up vars specific to a scenario
# 5. initialize host storage/tmp from previous run if provided
# 6. run container

# -. initial settings & exit codes
base_dir=$(dirname $(realpath $0))

source ${base_dir}/utils.sh
source ${base_dir}/cfg_files.sh

# exit codes: bitwise shift codes to allow for combination of exit codes
# ANY_ERROR_EXITCODE is sourced from ${base_dir}/utils.sh
CMDLINE_ARG_UNKNOWN_EXITCODE=$((${ANY_ERROR_EXITCODE} << 1))
ACCESS_UNKNOWN_EXITCODE=$((${ANY_ERROR_EXITCODE} << 2))
CONTAINER_ERROR_EXITCODE=$((${ANY_ERROR_EXITCODE} << 3))
HOST_STORAGE_ERROR_EXITCODE=$((${ANY_ERROR_EXITCODE} << 4))
MODE_UNKNOWN_EXITCODE=$((${ANY_ERROR_EXITCODE} << 5))
PREVIOUS_RUN_ERROR_EXITCODE=$((${ANY_ERROR_EXITCODE} << 6))
REPOSITORY_ERROR_EXITCODE=$((${ANY_ERROR_EXITCODE} << 7))
HTTP_PROXY_ERROR_EXITCODE=$((${ANY_ERROR_EXITCODE} << 9))
HTTPS_PROXY_ERROR_EXITCODE=$((${ANY_ERROR_EXITCODE} << 10))
RUN_SCRIPT_MISSING_EXITCODE=$((${ANY_ERROR_EXITCODE} << 11))

# CernVM-FS settings
CVMFS_VAR_LIB="var-lib-cvmfs"
CVMFS_VAR_RUN="var-run-cvmfs"

# repository cfg file
REPO_CFG_FILE=repos.cfg


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
  echo "  -l | --host-storage DIR  -  directory space on host machine (used for"
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
HOST_STORAGE=
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
      shift 1
      ;;
    -h|--help)
      display_help
      exit 0
      ;;
    -i|--info)
      INFO=1
      shift 1
      ;;
    -l|--host-storage)
      HOST_STORAGE="$2"
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
    -r|--repository)
      REPOSITORY="$2"
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
if [[ "${ACCESS}" != "ro" && "${ACCESS}" != "rw" ]]; then
  fatal_error "unknown access method '${ACCESS}'" "${ACCESS_UNKNOWN_EXITCODE}"
fi

# TODO (arg -c|--container) check container (is it a file or URL & access those)
# CONTAINER_ERROR_EXITCODE

# TODO (arg -l|--host-storage) check if it exists, if user has write permission,
#      if it contains no data, etc.
# HOST_STORAGE_ERROR_EXITCODE

# (arg -m|--mode) check if MODE is known
if [[ "${MODE}" != "shell" && "${MODE}" != "run" ]]; then
  fatal_error "unknown execution mode '${MODE}'" "${MODE_UNKNOWN_EXITCODE}"
fi

# TODO (arg -p|--previous-run) check if it exists, if user has read permission,
#      if it contains data from a previous run
# PREVIOUS_RUN_ERROR_EXITCODE

# TODO (arg -r|--repository) check if repository is known
# REPOSITORY_ERROR_EXITCODE

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


# 2. set up host storage/tmp
# as location for temporary data use in the following order
#   a. command line argument -l|--host-storage
#   b. env var TMPDIR
#   c. /tmp
# note, we ensure that (a) takes precedence by setting TMPDIR to HOST_STORAGE
#     if HOST_STORAGE is not empty
# note, (b) & (c) are automatically ensured by using 'mktemp -d --tmpdir' to
#     create a temporary directory
# note, if previous run is used the name of the temporary directory
#     should be identical to previous run, ie, then we don't create a new
#     temporary directory
if [[ ! -z ${HOST_STORAGE} ]]; then
  export TMPDIR=${HOST_STORAGE}
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
  echo "skipping sanity checks for /tmp"
fi
EESSI_HOST_STORAGE=$(mktemp -d --tmpdir eessi.XXXXXXXXXX)
echo "Using ${EESSI_HOST_STORAGE} as parent for temporary directories..."


# 3. set up common vars and directories
#    directory structure should be:
#      ${EESSI_HOST_STORAGE}
#      |-singularity_cache
#      |-${CVMFS_VAR_LIB}
#      |-${CVMFS_VAR_RUN}
#      |-overlay-upper
#      |-overlay-work
#      |-home
#      |-cfg

# tmp dir for EESSI
EESSI_TMPDIR=${EESSI_HOST_STORAGE}
mkdir -p ${EESSI_TMPDIR}
[[ ${INFO} -eq 1 ]] && echo "EESSI_TMPDIR=${EESSI_TMPDIR}"

# configure Singularity
export SINGULARITY_CACHEDIR=${EESSI_TMPDIR}/singularity_cache
mkdir -p ${SINGULARITY_CACHEDIR}
[[ ${INFO} -eq 1 ]] && echo "SINGULARITY_CACHEDIR=${SINGULARITY_CACHEDIR}"

# set env vars and create directories for CernVM-FS
EESSI_CVMFS_VAR_LIB=${EESSI_TMPDIR}/${CVMFS_VAR_LIB}
EESSI_CVMFS_VAR_RUN=${EESSI_TMPDIR}/${CVMFS_VAR_RUN}
mkdir -p ${EESSI_CVMFS_VAR_LIB}
mkdir -p ${EESSI_CVMFS_VAR_RUN}
[[ ${INFO} -eq 1 ]] && echo "EESSI_CVMFS_VAR_LIB=${EESSI_CVMFS_VAR_LIB}"
[[ ${INFO} -eq 1 ]] && echo "EESSI_CVMFS_VAR_RUN=${EESSI_CVMFS_VAR_RUN}"

# allow that SINGULARITY_HOME is defined before script is run
if [[ -z ${SINGULARITY_HOME} ]]; then
  export SINGULARITY_HOME="${EESSI_TMPDIR}/home:/home/${USER}"
  mkdir -p ${EESSI_TMPDIR}/home
  [[ ${INFO} -eq 1 ]] && echo "SINGULARITY_HOME=${SINGULARITY_HOME}"
fi

# define paths to add to SINGULARITY_BIND (added later when all BIND mounts are defined)
BIND_PATHS="${EESSI_CVMFS_VAR_LIB}:/var/lib/cvmfs,${EESSI_CVMFS_VAR_RUN}:/var/run/cvmfs"
BIND_PATHS="${BIND_PATHS},${EESSI_TMPDIR}:/tmp"
[[ ${INFO} -eq 1 ]] && echo "BIND_PATHS=${BIND_PATHS}"

# set up repository config (always create cfg dir and populate it with info when
# arg -r|--repository is used)
mkdir -p ${EESSI_TMPDIR}/cfg
if [[ "${REPOSITORY}" == "EESSI-pilot" ]]; then
  # need to source defaults as late as possible (see other sourcing below)
  source ${base_dir}/init/eessi_defaults

  # strip "/cvmfs/" from default setting
  repo_name=${EESSI_CVMFS_REPO/\/cvmfs\//}
else
  # TODO implement more flexible specification of repo cfgs
  #      REPOSITORY => repo-id OR repo-cfg-file (with a single section) OR
  #                    repo-cfg-file:repo-id (repo-id defined in repo-cfg-file)
  #
  # for now, assuming repo-id is defined in config file pointed to
  #   REPO_CFG_FILE, which is to be copied into the working directory
  #   (could also become part of the software layer to define multiple
  #    standard EESSI repositories)
  cfg_load ${REPO_CFG_FILE}

  # cfg file should include: repo_name, repo_version, config_bundle,
  #   map { local_filepath -> container_filepath }
  #
  # repo_name_domain is the domain part of the repo_name, e.g.,
  #   eessi-hpc.org for pilot.eessi-hpc.org
  #
  # where config bundle includes the files (-> target location in container)
  # - default.local -> /etc/cvmfs/default.local
  #   contains CVMFS settings, e.g., CVMFS_HTTP_PROXY, CVMFS_QUOTA_LIMIT, ...
  # - ${repo_name_domain}.conf -> /etc/cvmfs/domain.d/${repo_name_domain}.conf
  #   contains CVMFS settings, e.g., CVMFS_SERVER_URL (Stratum 1s),
  #   CVMFS_KEYS_DIR, CVMFS_USE_GEOAPI, ...
  # - ${repo_name_domain}/ -> /etc/cvmfs/keys/${repo_name_domain}
  #   a directory that contains the public key to access the repository, key
  #   itself then doesn't need to be BIND mounted
  # - ${repo_name_domain}/${repo_name}.pub
  #   (-> /etc/cvmfs/keys/${repo_name_domain}/${repo_name}.pub
  #   the public key to access the repository, key itself is BIND mounted
  #   via directory ${repo_name_domain}
  repo_name=$(cfg_get_value ${REPOSITORY} "repo_name")
  # derive domain part from repo_name (everything after first '.')
  repo_name_domain=${repo_name#*.}
  repo_version=$(cfg_get_value ${REPOSITORY} "repo_version")
  config_bundle=$(cfg_get_value ${REPOSITORY} "config_bundle")
  config_map=$(cfg_get_value ${REPOSITORY} "config_map")

  # convert config_map into associative array cfg_file_map
  cfg_init_file_map "${config_map}"
  cfg_print_map

  # TODO use information to set up dir ${EESSI_TMPDIR}/cfg,
  #      define BIND mounts and override repo name and version
  # check if config_bundle exists, if so, unpack it into ${EESSI_TMPDIR}/cfg
  if [[ ! -r ${config_bundle} ]]; then
    fatal_error "config bundle '${config_bundle}' is not readable" ${REPOSITORY_ERROR_EXITCODE}
  fi
  tar xf ${config_bundle} -C ${EESSI_TMPDIR}/cfg
  for src in "${!cfg_file_map[@]}"
  do
    target=${cfg_file_map[${src}]}
    BIND_PATHS="${BIND_PATHS},${src}:${target}"
  done
  export EESSI_PILOT_VERSION_OVERRIDE=${repo_version}
  export EESSI_CVMFS_REPO_OVERRIDE=${repo_name}
  # need to source defaults as late as possible (after *_OVERRIDEs)
  source ${base_dir}/init/eessi_defaults
fi


# 4. set up vars and dirs specific to a scenario

declare -a EESSI_FUSE_MOUNTS=()
if [[ "${ACCESS}" == "ro" ]]; then
  export EESSI_PILOT_READONLY="container:cvmfs2 ${repo_name} ${EESSI_CVMFS_REPO}"
  EESSI_FUSE_MOUNTS+=("--fusemount" "${EESSI_PILOT_READONLY}")
fi

if [[ "${ACCESS}" == "rw" ]]; then
  EESSI_CVMFS_OVERLAY_UPPER=/tmp/overlay-upper
  EESSI_CVMFS_OVERLAY_WORK=/tmp/overlay-work
  mkdir -p ${EESSI_TMPDIR}/overlay-upper
  mkdir -p ${EESSI_TMPDIR}/overlay-work
  [[ ${INFO} -eq 1 ]] && echo "EESSI_CVMFS_OVERLAY_UPPER=${EESSI_CVMFS_OVERLAY_UPPER}"
  [[ ${INFO} -eq 1 ]] && echo "EESSI_CVMFS_OVERLAY_WORK=${EESSI_CVMFS_OVERLAY_WORK}"

  # set environment variables for fuse mounts in Singularity container
  EESSI_PILOT_READONLY="container:cvmfs2 ${repo_name} /cvmfs_ro/${repo_name}"
  EESSI_FUSE_MOUNTS+=("--fusemount" "${EESSI_PILOT_READONLY}")

  EESSI_PILOT_WRITABLE_OVERLAY="container:fuse-overlayfs"
  EESSI_PILOT_WRITABLE_OVERLAY+=" -o lowerdir=/cvmfs_ro/${repo_name}"
  EESSI_PILOT_WRITABLE_OVERLAY+=" -o upperdir=/tmp/overlay-upper"
  EESSI_PILOT_WRITABLE_OVERLAY+=" -o workdir=/tmp/overlay-work"
  EESSI_PILOT_WRITABLE_OVERLAY+=" ${EESSI_CVMFS_REPO}"
  EESSI_FUSE_MOUNTS+=("--fusemount" "${EESSI_PILOT_WRITABLE_OVERLAY}")
fi


# 5. initialize host storage/tmp from previous run if provided


# 6. run container
# final settings
if [[ -z ${SINGULARITY_BIND} ]]; then
    export SINGULARITY_BIND="${BIND_PATHS}"
else
    export SINGULARITY_BIND="${SINGULARITY_BIND},${BIND_PATHS}"
fi
[[ ${INFO} -eq 1 ]] && echo "SINGULARITY_BIND=${SINGULARITY_BIND}"

echo "Launching container with command (next line):"
echo "singularity ${MODE} ${EESSI_FUSE_MOUNTS[@]} ${CONTAINER} ${RUN_SCRIPT_AND_ARGS}"
singularity ${MODE} "${EESSI_FUSE_MOUNTS[@]}" ${CONTAINER} ${RUN_SCRIPT_AND_ARGS}
