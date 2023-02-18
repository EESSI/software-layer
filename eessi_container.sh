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

source ${TOPDIR}/scripts/utils.sh
source ${TOPDIR}/cfg_files.sh

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

# CernVM-FS settings
CVMFS_VAR_LIB="var-lib-cvmfs"
CVMFS_VAR_RUN="var-run-cvmfs"

# directory for tmp used inside container
export TMP_IN_CONTAINER=/tmp

# repository cfg file, default name (default location: $PWD)
#   can be overwritten by setting env var EESSI_REPOS_CFG_DIR_OVERRIDE
export EESSI_REPOS_CFG_FILE="${EESSI_REPOS_CFG_DIR_OVERRIDE:=${PWD}}/repos.cfg"
# other repository cfg files in directory, default location: $PWD
#   can be overwritten by setting env var EESSI_REPOS_CFG_DIR_OVERRIDE
export EESSI_REPOS_CFG_DIR="${EESSI_REPOS_CFG_DIR_OVERRIDE:=${PWD}}"


# 0. parse args
#    see example parsing of command line arguments at
#    https://wiki.bash-hackers.org/scripting/posparams#using_a_while_loop
#    https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

display_help() {
  echo "usage: $0 [OPTIONS] [SCRIPT]"
  echo " OPTIONS:"
  echo "  -a | --access {ro,rw}  - ro (read-only), rw (read & write) [default: ro]"
  echo "  -c | --container IMG   - image file or URL defining the container to use"
  echo "                           [default: docker://ghcr.io/eessi/build-node:debian11]"
  echo "  -h | --help            - display this usage information [default: false]"
  echo "  -g | --storage DIR     - directory space on host machine (used for"
  echo "                           temporary data) [default: 1. TMPDIR, 2. /tmp]"
  echo "  -l | --list-repos      - list available repository identifiers [default: false]"
  echo "  -m | --mode MODE       - with MODE==shell (launch interactive shell) or"
  echo "                           MODE==run (run a script) [default: shell]"
  echo "  -r | --repository CFG  - configuration file or identifier defining the"
  echo "                           repository to use [default: EESSI-pilot via"
  echo "                          container configuration]"
  echo "  -u | --resume DIR/TGZ  - resume a previous run from a directory or tarball,"
  echo "                           where DIR points to a previously used tmp directory"
  echo "                           (check for output 'Using DIR as tmp ...' of a previous"
  echo "                           run) and TGZ is the path to a tarball which is"
  echo "                           unpacked the tmp dir stored on the local storage space"
  echo "                           (see option --storage above) [default: not set]"
  echo "  -s | --save DIR/TGZ    - save contents of tmp directory to a tarball in"
  echo "                           directory DIR or provided with the fixed full path TGZ"
  echo "                           when a directory is provided, the format of the"
  echo "                           tarball's name will be {REPO_ID}-{TIMESTAMP}.tgz"
  echo "                           [default: not set]"
  echo "  -v | --verbose         - display more information [default: false]"
  echo "  -x | --http-proxy URL  - provides URL for the env variable http_proxy"
  echo "                           [default: not set]; uses env var \$http_proxy if set"
  echo "  -y | --https-proxy URL - provides URL for the env variable https_proxy"
  echo "                           [default: not set]; uses env var \$https_proxy if set"
  echo
  echo " If value for --mode is 'run', the SCRIPT provided is executed."
  echo
  echo " FEATURES/OPTIONS to be implemented:"
  echo "  -d | --dry-run         -  run script except for executing the container,"
  echo "                            print information about setup [default: false]"
}

# set defaults for command line arguments
ACCESS="ro"
CONTAINER="docker://ghcr.io/eessi/build-node:debian11"
#DRY_RUN=0
VERBOSE=0
STORAGE=
LIST_REPOS=0
MODE="shell"
REPOSITORY="EESSI-pilot"
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
    -c|--container)
      CONTAINER="$2"
      shift 2
      ;;
#    -d|--dry-run)
#      DRY_RUN=1
#      shift 1
#      ;;
    -g|--storage)
      STORAGE="$2"
      shift 2
      ;;
    -h|--help)
      display_help
      exit 0
      ;;
    -l|--list-repos)
      LIST_REPOS=1
      shift 1
      ;;
    -m|--mode)
      MODE="$2"
      shift 2
      ;;
    -r|--repository)
      REPOSITORY="$2"
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

if [[ ${LIST_REPOS} -eq 1 ]]; then
    echo "Repositories defined in the config file '${EESSI_REPOS_CFG_FILE}':"
    echo "    EESSI-pilot [default]"
    cfg_load ${EESSI_REPOS_CFG_FILE}
    sections=$(cfg_sections)
    while IFS= read -r repo_id
    do
        echo "    ${repo_id}"
    done <<< "${sections}"
    exit 0
fi

# 1. check if argument values are valid
# (arg -a|--access) check if ACCESS is supported
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

# TODO (arg -r|--repository) check if repository is known
# REPOSITORY_ERROR_EXITCODE
if [[ ! -z "${REPOSITORY}" && "${REPOSITORY}" != "EESSI-pilot" && ! -r ${EESSI_REPOS_CFG_FILE} ]]; then
    fatal_error "arg '--repository ${REPOSITORY}' requires a cfg file at '${EESSI_REPOS_CFG_FILE}'" "${REPOSITORY_ERROR_EXITCODE}"
fi

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
  echo "Using ${EESSI_HOST_STORAGE} as tmp storage (add '--resume ${EESSI_HOST_STORAGE}' to resume where this session ended)."
fi
echo "RESUME_FROM_DIR ${EESSI_HOST_STORAGE}"

# if ${RESUME} is a file (assume a tgz), unpack it into ${EESSI_HOST_STORAGE}
if [[ ! -z ${RESUME} && -f ${RESUME} ]]; then
  tar xf ${RESUME} -C ${EESSI_HOST_STORAGE}
  echo "Resuming from previous run using temporary storage ${RESUME} unpacked into ${EESSI_HOST_STORAGE}"
fi

# 3. set up common vars and directories
#    directory structure should be:
#      ${EESSI_HOST_STORAGE}
#      |-singularity_cache
#      |-${CVMFS_VAR_LIB}
#      |-${CVMFS_VAR_RUN}
#      |-overlay-upper
#      |-overlay-work
#      |-home
#      |-repos_cfg

# tmp dir for EESSI
EESSI_TMPDIR=${EESSI_HOST_STORAGE}
mkdir -p ${EESSI_TMPDIR}
[[ ${VERBOSE} -eq 1 ]] && echo "EESSI_TMPDIR=${EESSI_TMPDIR}"

# configure Singularity
export SINGULARITY_CACHEDIR=${EESSI_TMPDIR}/singularity_cache
mkdir -p ${SINGULARITY_CACHEDIR}
[[ ${VERBOSE} -eq 1 ]] && echo "SINGULARITY_CACHEDIR=${SINGULARITY_CACHEDIR}"

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
  [[ ${VERBOSE} -eq 1 ]] && echo "SINGULARITY_HOME=${SINGULARITY_HOME}"
fi

# define paths to add to SINGULARITY_BIND (added later when all BIND mounts are defined)
BIND_PATHS="${EESSI_CVMFS_VAR_LIB}:/var/lib/cvmfs,${EESSI_CVMFS_VAR_RUN}:/var/run/cvmfs"
# provide a '/tmp' inside the container
BIND_PATHS="${BIND_PATHS},${EESSI_TMPDIR}:${TMP_IN_CONTAINER}"

[[ ${VERBOSE} -eq 1 ]] && echo "BIND_PATHS=${BIND_PATHS}"

# set up repository config (always create directory repos_cfg and populate it with info when
# arg -r|--repository is used)
mkdir -p ${EESSI_TMPDIR}/repos_cfg
if [[ "${REPOSITORY}" == "EESSI-pilot" ]]; then
  # need to source defaults as late as possible (see other sourcing below)
  source ${TOPDIR}/init/eessi_defaults

  # strip "/cvmfs/" from default setting
  repo_name=${EESSI_CVMFS_REPO/\/cvmfs\//}
else
  # TODO implement more flexible specification of repo cfgs
  #      REPOSITORY => repo-id OR repo-cfg-file (with a single section) OR
  #                    repo-cfg-file:repo-id (repo-id defined in repo-cfg-file)
  #
  # for now, assuming repo-id is defined in config file pointed to
  #   EESSI_REPOS_CFG_FILE, which is to be copied into the working directory
  #   (could also become part of the software layer to define multiple
  #    standard EESSI repositories)
  cfg_load ${EESSI_REPOS_CFG_FILE}

  # copy repos.cfg to job directory --> makes it easier to inspect the job
  cp ${EESSI_REPOS_CFG_FILE} ${EESSI_TMPDIR}/repos_cfg/.

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
  [[ ${VERBOSE} -eq 1 ]] && cfg_print_map

  # use information to set up dir ${EESSI_TMPDIR}/repos_cfg,
  #     define BIND mounts and override repo name and version
  # check if config_bundle exists, if so, unpack it into ${EESSI_TMPDIR}/repos_cfg
  # if config_bundle is relative path (no '/' at start) prepend it with
  # EESSI_REPOS_CFG_DIR
  config_bundle_path=
  if [[ ! "${config_bundle}" =~ ^/ ]]; then
      config_bundle_path=${EESSI_REPOS_CFG_DIR}/${config_bundle}
  else
      config_bundle_path=${config_bundle}
  fi

  if [[ ! -r ${config_bundle_path} ]]; then
    fatal_error "config bundle '${config_bundle_path}' is not readable" ${REPOSITORY_ERROR_EXITCODE}
  fi

  # only unpack config_bundle if we're not resuming from a previous run
  if [[ -z ${RESUME} ]]; then
    tar xf ${config_bundle_path} -C ${EESSI_TMPDIR}/repos_cfg
  fi

  for src in "${!cfg_file_map[@]}"
  do
    target=${cfg_file_map[${src}]}
    BIND_PATHS="${BIND_PATHS},${EESSI_TMPDIR}/repos_cfg/${src}:${target}"
  done
  export EESSI_PILOT_VERSION_OVERRIDE=${repo_version}
  export EESSI_CVMFS_REPO_OVERRIDE="/cvmfs/${repo_name}"
  # need to source defaults as late as possible (after *_OVERRIDEs)
  source ${TOPDIR}/init/eessi_defaults
fi

# if http_proxy is not empty, we assume that the machine accesses internet
# via a proxy. then we need to add CVMFS_HTTP_PROXY to
# ${EESSI_TMPDIR}/repos_cfg/default.local on host (and possibly add a BIND
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
    cat ${EESSI_TMPDIR}/repos_cfg/default.local

    # if default.local is not BIND mounted into container, add it to BIND_PATHS
    if [[ ! ${BIND_PATHS} =~ "${EESSI_TMPDIR}/repos_cfg/default.local:/etc/cvmfs/default.local" ]]; then
        export BIND_PATHS="${BIND_PATHS},${EESSI_TMPDIR}/repos_cfg/default.local:/etc/cvmfs/default.local"
    fi
fi

# 4. set up vars and dirs specific to a scenario

declare -a EESSI_FUSE_MOUNTS=()
if [[ "${ACCESS}" == "ro" ]]; then
  export EESSI_PILOT_READONLY="container:cvmfs2 ${repo_name} /cvmfs/${repo_name}"

  EESSI_FUSE_MOUNTS+=("--fusemount" "${EESSI_PILOT_READONLY}")
  export EESSI_FUSE_MOUNTS
fi

if [[ "${ACCESS}" == "rw" ]]; then
  mkdir -p ${EESSI_TMPDIR}/overlay-upper
  mkdir -p ${EESSI_TMPDIR}/overlay-work

  # set environment variables for fuse mounts in Singularity container
  export EESSI_PILOT_READONLY="container:cvmfs2 ${repo_name} /cvmfs_ro/${repo_name}"

  EESSI_FUSE_MOUNTS+=("--fusemount" "${EESSI_PILOT_READONLY}")

  EESSI_PILOT_WRITABLE_OVERLAY="container:fuse-overlayfs"
  EESSI_PILOT_WRITABLE_OVERLAY+=" -o lowerdir=/cvmfs_ro/${repo_name}"
  EESSI_PILOT_WRITABLE_OVERLAY+=" -o upperdir=${TMP_IN_CONTAINER}/overlay-upper"
  EESSI_PILOT_WRITABLE_OVERLAY+=" -o workdir=${TMP_IN_CONTAINER}/overlay-work"
  EESSI_PILOT_WRITABLE_OVERLAY+=" ${EESSI_CVMFS_REPO}"
  export EESSI_PILOT_WRITABLE_OVERLAY

  EESSI_FUSE_MOUNTS+=("--fusemount" "${EESSI_PILOT_WRITABLE_OVERLAY}")
  export EESSI_FUSE_MOUNTS
fi


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

# if INFO is set to 1 (arg --info), add argument '-q'
if [[ -z ${INFO} ]]; then
    RUN_QUIET='-q'
else
    RUN_QUIET=''
fi

echo "Launching container with command (next line):"
echo "singularity ${RUN_QUIET} ${MODE} ${EESSI_FUSE_MOUNTS[@]} ${CONTAINER} $@"
# TODO for now we run singularity with '-q' (quiet), later adjust this to the log level
#      provided to the script
singularity ${RUN_QUIET} ${MODE} "${EESSI_FUSE_MOUNTS[@]}" ${CONTAINER} "$@"
exit_code=$?

# 6. save tmp if requested (arg -s|--save)
if [[ ! -z ${SAVE} ]]; then
  # Note, for now we don't try to be smart and record in any way the OS and
  #   ARCH which might have been used internally, eg, when software packages
  #   were built ... we rather keep the script here "stupid" and leave the handling
  #   of these aspects to where the script is used
  if [[ -d ${SAVE} ]]; then
    # assume SAVE is name of a directory to which tarball shall be written to
    #   name format: {REPO_ID}-{TIMESTAMP}.tgz
    ts=$(date +%s)
    TGZ=${SAVE}/${REPOSITORY}-${ts}.tgz
  else
    # assume SAVE is the full path to a tarball's name
    TGZ=${SAVE}
  fi
  tar cf ${TGZ} -C ${EESSI_TMPDIR} .
  echo "Saved contents of '${EESSI_TMPDIR}' to '${TGZ}' (to resume, add '--resume ${TGZ}')"
  echo "RESUME_FROM_TGZ ${TGZ}"
fi

# TODO clean up tmp by default? only retain if another option provided (--retain-tmp)

# use exit code of container command
exit ${exit_code}
