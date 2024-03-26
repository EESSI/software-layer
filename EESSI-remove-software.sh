#!/bin/bash
#
# Script to remove part of the EESSI software stack (version set through init/eessi_defaults)

# see example parsing of command line arguments at
#   https://wiki.bash-hackers.org/scripting/posparams#using_a_while_loop
#   https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

display_help() {
  echo "usage: $0 [OPTIONS]"
  echo "  --build-logs-dir       -  location to copy EasyBuild logs to for failed builds"
  echo "  -g | --generic         -  instructs script to build for generic architecture target"
  echo "  -h | --help            -  display this usage information"
}

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -g|--generic)
      echo_yellow ">> GENERIC build requested, taking appropriate measures!"
      EASYBUILD_OPTARCH="GENERIC"
      DETECTION_PARAMETERS="--generic"
      shift
      ;;
    -h|--help)
      display_help  # Call your function
      # no shifting needed here, we're done.
      exit 0
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

export TMPDIR=$(mktemp -d /tmp/eessi-remove.XXXXXXXX)

source $TOPDIR/scripts/utils.sh

echo ">> Setting up environment..."

source $TOPDIR/init/bash

if [ -d $EESSI_CVMFS_REPO ]; then
    echo_green "$EESSI_CVMFS_REPO available, OK!"
else
    fatal_error "$EESSI_CVMFS_REPO is not available!"
fi

echo ">> Determining software subdirectory to use for current build host..."
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
ml --version
if [[ $? -eq 0 ]]; then
    echo_green ">> Found Lmod ${LMOD_VERSION}"
else
    fatal_error "Failed to initialize Lmod?!"
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

# if this script is run as root, use PR patch file to determine if software needs to be removed first
if [ $EUID -eq 0 ]; then
    changed_easystacks_rebuilds=$(cat ${pr_diff} | grep '^+++' | cut -f2 -d' ' | sed 's@^[a-z]/@@g' | grep '^easystacks/.*yml$' | egrep -v 'known-issues|missing' | grep "/rebuilds/")
    if [ -z ${changed_easystacks_rebuilds} ]; then
        echo "No software needs to be removed."
    else
        for easystack_file in ${changed_easystacks_rebuilds}; do
            # determine version of EasyBuild module to load based on EasyBuild version included in name of easystack file
            eb_version=$(echo ${easystack_file} | sed 's/.*eb-\([0-9.]*\).*/\1/g')

            # load EasyBuild module (will be installed if it's not available yet)
            source ${TOPDIR}/load_easybuild_module.sh ${eb_version}

            if [ -f ${easystack_file} ]; then
                echo_green "Software rebuild(s) requested in ${easystack_file}, so determining which existing installation have to be removed..."
                # we need to remove existing installation directories first,
                # so let's figure out which modules have to be rebuilt by doing a dry-run and grepping "someapp/someversion" for the relevant lines (with [R])
                #  * [R] $CFGS/s/someapp/someapp-someversion.eb (module: someapp/someversion)
                rebuild_apps=$(eb --allow-use-as-root-and-accept-consequences --dry-run-short --rebuild --easystack ${easystack_file} | grep "^ \* \[R\]" | grep -o "module: .*[^)]" | awk '{print $2}')
                for app in ${rebuild_apps}; do
                    app_dir=${EASYBUILD_INSTALLPATH}/software/${app}
                    app_module=${EASYBUILD_INSTALLPATH}/modules/all/${app}.lua
                    echo_yellow "Removing ${app_dir} and ${app_module}..."
                    rm -rf ${app_dir}
                    rm -rf ${app_module}
                done
            else
                fatal_error "Easystack file ${easystack_file} not found!"
            fi
        done
    fi
else
    fatal_error "This script can only be run by root!"
fi
