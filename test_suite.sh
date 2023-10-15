#!/bin/bash
#
# Run sanity check for all requested modules (and built dependencies)?
# get ec from diff
# set up EasyBuild
# run `eb --sanity-only ec`

display_help() {
  echo "usage: $0 [OPTIONS]"
  echo "  -g | --generic         -  instructs script to test for generic architecture target"
  echo "  -h | --help            -  display this usage information"
  echo "  -x | --http-proxy URL  -  provides URL for the environment variable http_proxy"
  echo "  -y | --https-proxy URL -  provides URL for the environment variable https_proxy"
}

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -g|--generic)
      EASYBUILD_OPTARCH="GENERIC"
      shift
      ;;
    -h|--help)
      display_help  # Call your function
      # no shifting needed here, we're done.
      exit 0
      ;;
    -x|--http-proxy)
      export http_proxy="$2"
      shift 2
      ;;
    -y|--https-proxy)
      export https_proxy="$2"
      shift 2
      ;;
    --build-logs-dir)
      export build_logs_dir="${2}"
      shift 2
      ;;
    --shared-fs-path)
      export shared_fs_path="${2}"
      shift 2
      ;;
    -*|--*)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
    *)  # No more options
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"

TOPDIR=$(dirname $(realpath $0))

source $TOPDIR/scripts/utils.sh

# honor $TMPDIR if it is already defined, use /tmp otherwise
if [ -z $TMPDIR ]; then
    export WORKDIR=/tmp/$USER
else
    export WORKDIR=$TMPDIR/$USER
fi

TMPDIR=$(mktemp -d)

echo ">> Setting up environment..."

source $TOPDIR/init/minimal_eessi_env

if [ -d $EESSI_CVMFS_REPO ]; then
    echo_green "$EESSI_CVMFS_REPO available, OK!"
else
    fatal_error "$EESSI_CVMFS_REPO is not available!"
fi

# make sure we're in Prefix environment by checking $SHELL
if [[ ${SHELL} = ${EPREFIX}/bin/bash ]]; then
    echo_green ">> It looks like we're in a Gentoo Prefix environment, good!"
else
    fatal_error "Not running in Gentoo Prefix environment, run '${EPREFIX}/startprefix' first!"
fi

# avoid that pyc files for EasyBuild are stored in EasyBuild installation directory
export PYTHONPYCACHEPREFIX=$TMPDIR/pycache

DETECTION_PARAMETERS=''
GENERIC=0
EB='eb'
if [[ "$EASYBUILD_OPTARCH" == "GENERIC" ]]; then
    echo_yellow ">> GENERIC build/test requested, taking appropriate measures!"
    DETECTION_PARAMETERS="$DETECTION_PARAMETERS --generic"
    GENERIC=1
    EB='eb --optarch=GENERIC'
fi

echo ">> Determining software subdirectory to use for current build/test host..."
if [ -z $EESSI_SOFTWARE_SUBDIR_OVERRIDE ]; then
  export EESSI_SOFTWARE_SUBDIR_OVERRIDE=$(python3 $TOPDIR/eessi_software_subdir.py $DETECTION_PARAMETERS)
  echo ">> Determined \$EESSI_SOFTWARE_SUBDIR_OVERRIDE via 'eessi_software_subdir.py $DETECTION_PARAMETERS' script"
else
  echo ">> Picking up pre-defined \$EESSI_SOFTWARE_SUBDIR_OVERRIDE: ${EESSI_SOFTWARE_SUBDIR_OVERRIDE}"
fi

# Set all the EESSI environment variables (respecting $EESSI_SOFTWARE_SUBDIR_OVERRIDE)
# $EESSI_SILENT - don't print any messages
# $EESSI_BASIC_ENV - give a basic set of environment variables
EESSI_SILENT=1 EESSI_BASIC_ENV=1 source $TOPDIR/init/eessi_environment_variables

if [[ -z ${EESSI_SOFTWARE_SUBDIR} ]]; then
    fatal_error "Failed to determine software subdirectory?!"
elif [[ "${EESSI_SOFTWARE_SUBDIR}" != "${EESSI_SOFTWARE_SUBDIR_OVERRIDE}" ]]; then
    fatal_error "Values for EESSI_SOFTWARE_SUBDIR_OVERRIDE (${EESSI_SOFTWARE_SUBDIR_OVERRIDE}) and EESSI_SOFTWARE_SUBDIR (${EESSI_SOFTWARE_SUBDIR}) differ!"
else
    echo_green ">> Using ${EESSI_SOFTWARE_SUBDIR} as software subdirectory!"
fi

echo ">> Initializing Lmod..."
source $EPREFIX/usr/share/Lmod/init/bash
ml_version_out=$TMPDIR/ml.out
ml --version &> $ml_version_out
if [[ $? -eq 0 ]]; then
    echo_green ">> Found Lmod ${LMOD_VERSION}"
else
    fatal_error "Failed to initialize Lmod?! (see output in ${ml_version_out}"
fi

echo ">> Configuring EasyBuild..."
source $TOPDIR/configure_easybuild

echo ">> Setting up \$MODULEPATH..."
# make sure no modules are loaded
module --force purge
# ignore current $MODULEPATH entirely
module unuse $MODULEPATH
module use $EASYBUILD_INSTALLPATH/modules/all
if [[ -z ${MODULEPATH} ]]; then
    fatal_error "Failed to set up \$MODULEPATH?!"
else
    echo_green ">> MODULEPATH set up: ${MODULEPATH}"
fi

# assume there's only one diff file that corresponds to the PR patch file
pr_diff=$(ls [0-9]*.diff | head -1)

# "split" the file by prefixing each line belonging to the same file with the
# same number
split_file=$(awk '/^\+\+\+/{n++}{print n, "  ", $0 }' ${pr_diff})

# determine which easystack files may have changed
changed_es_files=$(echo "${split_file}" | grep '^[0-9 ]*+++ ./eessi.*.yml$' | egrep -v 'known-issues|missing')

# process all changed easystackfiles
for es_file_num in $(echo "${changed_es_files}" | cut -f1 -d' ')
do
    # determine added lines that do not contain a yaml comment only
    added_lines=$(echo "${split_file}" | grep "${es_file_num}    + " | sed -e "s/^"${es_file_num}"    + //" | grep -v "^[ ]*#")
    # determine easyconfigs
    easyconfigs=$(echo "${added_lines}" | cut -f3 -d' ')
    # get easystack file name
    easystack_file=$(echo "${changed_es_files}" | grep "^${es_file_num}" | sed -e "s/^"${es_file_num}"    ... .\///")
    echo -e "Processing easystack file ${easystack_file}...\n\n"

    # determine version of EasyBuild module to load based on EasyBuild version included in name of easystack file
    eb_version=$(echo ${easystack_file} | sed 's/.*eb-\([0-9.]*\).*/\1/g')

    # load EasyBuild module
    module load EasyBuild/${eb_version}

    echo_green "All set, let's run sanity checks for installed packages..."

    for easyconfig in ${easyconfigs};
    do
        echo "Running sanity check for '${easyconfig}'..."
        eb --sanity-check-only ${easyconfig}
    done
done

echo ">> Cleaning up ${TMPDIR}..."
rm -r ${TMPDIR}
