#!/usr/bin/env bash

# This script can be used to install extra packages under ${EESSI_SOFTWARE_PATH}

# some logging
echo ">>> Running ${BASH_SOURCE}"

# Initialise our bash functions
TOPDIR=$(dirname $(realpath ${BASH_SOURCE}))
source "${TOPDIR}"/../utils.sh

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --help                           Display this help message"
    echo "  -e, --easystack EASYSTACKFILE    Easystack file which specifies easyconfigs to be installed."
    echo "  -t, --temp-dir /path/to/tmpdir   Specify a location to use for temporary"
    echo "                                   storage during the installation"
}

# Initialize variables
TEMP_DIR=
EASYSTACK_FILE=

# Parse command-line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)
            show_help
            exit 0
            ;;
        -e|--easystack)
            if [ -n "$2" ]; then
                EASYSTACK_FILE="$2"
                shift 2
            else
                echo "Error: Argument required for $1"
                show_help
                exit 1
            fi
            ;;
        -t|--temp-dir)
            if [ -n "$2" ]; then
                TEMP_DIR="$2"
                shift 2
            else
                echo "Error: Argument required for $1"
                show_help
                exit 1
            fi
            ;;
        *)
            show_help
            fatal_error "Error: Unknown option: $1"
            ;;
    esac
done

if [[ -z ${EASYSTACK_FILE} ]]; then
    show_help
    fatal_error "Error: need to specify easystack file"
fi

# Make sure NESSI is initialised
check_eessi_initialised

# As an installation location just use $EESSI_SOFTWARE_PATH
export NESSI_CVMFS_INSTALL=${EESSI_SOFTWARE_PATH}

# we need a directory we can use for temporary storage
if [[ -z "${TEMP_DIR}" ]]; then
    tmpdir=$(mktemp -d)
else
    mkdir -p ${TEMP_DIR}
    tmpdir=$(mktemp -d --tmpdir=${TEMP_DIR} extra.XXX)
    if [[ ! -d "$tmpdir" ]] ; then
        fatal_error "Could not create directory ${tmpdir}"
    fi
fi
echo "Created temporary directory '${tmpdir}'"
export WORKING_DIR=${tmpdir}

# load EasyBuild
ml EasyBuild

# load NESSI-extend/2023.06-easybuild
ml NESSI-extend/2023.06-easybuild

eb --show-config

eb --easystack ${EASYSTACK_FILE} --robot

# clean up tmpdir
rm -rf "${tmpdir}"
