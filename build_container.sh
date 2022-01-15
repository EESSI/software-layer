#!/bin/bash

BUILD_CONTAINER="docker://ghcr.io/eessi/build-node:debian10"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <shell|run> <path for temporary directories>" >&2
    exit 1
fi
SHELL_OR_RUN=$1
EESSI_TMPDIR=$2
shift 2

if [ "$SHELL_OR_RUN" == "run" ] && [ -z "$@" ]; then
    echo "ERROR: No command specified to run?!" >&2
    exit 1
fi

# make sure specified temporary directory exists
mkdir -p $EESSI_TMPDIR

# make sure that specified location has support for extended attributes,
# since that's required by CernVM-FS
command -v attr &> /dev/null
if [ $? -eq 0 ]; then
    testfile=$(mktemp -p $EESSI_TMPDIR)
    attr -s test -V test $testfile > /dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR: $EESSI_TMPDIR does not support extended attributes!" >&2
       exit 2
    else
        rm $testfile
    fi
else
    echo "WARNING: 'attr' command not available, so can't check support for extended attributes..." >&2
fi

echo "Using $EESSI_TMPDIR as parent for temporary directories..."

# create temporary directories
mkdir -p $EESSI_TMPDIR/{home,overlay-upper,overlay-work}
mkdir -p $EESSI_TMPDIR/{var-lib-cvmfs,var-run-cvmfs}
# configure Singularity
export SINGULARITY_CACHEDIR=$EESSI_TMPDIR/singularity_cache
export SINGULARITY_BIND="$EESSI_TMPDIR/var-run-cvmfs:/var/run/cvmfs,$EESSI_TMPDIR/var-lib-cvmfs:/var/lib/cvmfs,$EESSI_TMPDIR"
export SINGULARITY_HOME="$EESSI_TMPDIR/home:/home/$USER"

# set environment variables for fuse mounts in Singularity container
export EESSI_PILOT_READONLY="container:cvmfs2 pilot.eessi-hpc.org /cvmfs_ro/pilot.eessi-hpc.org"
export EESSI_PILOT_WRITABLE_OVERLAY="container:fuse-overlayfs -o lowerdir=/cvmfs_ro/pilot.eessi-hpc.org -o upperdir=$EESSI_TMPDIR/overlay-upper -o workdir=$EESSI_TMPDIR/overlay-work /cvmfs/pilot.eessi-hpc.org"

if [ "$SHELL_OR_RUN" == "shell" ]; then
    # start shell in Singularity container, with EESSI repository mounted with writable overlay
    echo "Starting Singularity build container..."
    singularity shell --fusemount "$EESSI_PILOT_READONLY" --fusemount "$EESSI_PILOT_WRITABLE_OVERLAY" $BUILD_CONTAINER
elif [ "$SHELL_OR_RUN" == "run" ]; then
    echo "Running '$@' in Singularity build container..."
    singularity exec --fusemount "$EESSI_PILOT_READONLY" --fusemount "$EESSI_PILOT_WRITABLE_OVERLAY" $BUILD_CONTAINER "$@"
else
    echo "ERROR: Unknown action specified: $SHELL_OR_RUN (should be either 'shell' or 'run')" >&2
    exit 1
fi
