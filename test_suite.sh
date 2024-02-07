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

# avoid that pyc files for EasyBuild are stored in EasyBuild installation directory
export PYTHONPYCACHEPREFIX=$TMPDIR/pycache

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

echo ">> Setting up \$MODULEPATH..."
# make sure no modules are loaded
module --force purge
# ignore current $MODULEPATH entirely
module unuse $MODULEPATH
module use ${EESSI_SOFTWARE_PATH}/modules/all
if [[ -z ${MODULEPATH} ]]; then
    fatal_error "Failed to set up \$MODULEPATH?!"
else
    echo_green ">> MODULEPATH set up: ${MODULEPATH}"
fi

# TODO: this should not be hardcoded. Ideally, we put some logic in place to discover the newest version
# of the ReFrame module available in the current environment
module load ReFrame/4.3.3
if [[ $? -eq 0 ]]; then
    echo_green ">> Loaded ReFrame/4.3.3"
else
    fatal_error "Failed to load the ReFrame module"
fi

# Check ReFrame came with the hpctestlib and we can import it
python3 -c 'import hpctestlib.sciapps.gromacs'
if [[ $? -eq 0 ]]; then
    echo_green "Succesfully found and imported hpctestlib.sciapps.gromas"
else
    fatal_error "Failed to load hpctestlib"
fi

# Cloning should already be done by clone_eessi_test_suite.sh, which runs in compat layer to have 'git' available
# git clone https://github.com/EESSI/test-suite EESSI-test-suite
export TESTSUITEPREFIX=$PWD/EESSI-test-suite
if [ -d $TESTSUITEPREFIX ]; then
    echo_green "Clone of the test suite $TESTSUITEPREFIX available, OK!"
else
    fatal_error "Clone of the test suite $TESTSUITEPREFIX is not available!"
fi
export PYTHONPATH=$TESTSUITEPREFIX:$PYTHONPATH

# Check that we can import from the testsuite
python3 -c 'import eessi.testsuite'
if [[ $? -eq 0 ]]; then
    echo_green "Succesfully found and imported eessi.testsuite"
else
    fatal_error "FAILED to import from eessi.testsuite in Python"
fi

# Configure ReFrame
export RFM_CONFIG_FILES=$TESTSUITEPREFIX/config/software_layer_bot.py
export RFM_CHECK_SEARCH_PATH=$TESTSUITEPREFIX/eessi/testsuite/tests
export RFM_CHECK_SEARCH_RECURSIVE=1
export RFM_PREFIX=$PWD/reframe_runs

echo "Configured reframe with the following environment variables:"
env | grep "RFM_"

# Check we can run reframe
reframe --version
if [[ $? -eq 0 ]]; then
    echo_green "Succesfully ran reframe --version"
else
    fatal_error "Failed to run ReFrame --version"
fi

# List the tests we want to run
export REFRAME_ARGS='--tag CI --tag 1_node'
echo "Listing tests: reframe ${REFRAME_ARGS} --list"
reframe ${REFRAME_ARGS} --list
if [[ $? -eq 0 ]]; then
    echo_green "Succesfully listed ReFrame tests with command: reframe ${REFRAME_ARGS} --list"
else
    fatal_error "Failed to list ReFrame tests with command: reframe ${REFRAME_ARGS} --list"
fi

# Run all tests
echo "Running tests: reframe ${REFRAME_ARGS} --run"
reframe ${REFRAME_ARGS} --run
if [[ $? -eq 0 ]]; then
    echo_green "ReFrame runtime ran succesfully with command: reframe ${REFRAME_ARGS} --run."
else
    fatal_error "ReFrame runtime failed to run with command: reframe ${REFRAME_ARGS} --run."
fi

echo ">> Cleaning up ${TMPDIR}..."
rm -r ${TMPDIR}

exit 0
