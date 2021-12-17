#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <path for temporary directories>" >&2
    exit 1
fi
export EESSI_TMPDIR=$1

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

# start shell in Singularity container, with EESSI repository mounted with writable overlay
echo "Starting Singularity container..."
singularity shell --fusemount "$EESSI_PILOT_READONLY" --fusemount "$EESSI_PILOT_WRITABLE_OVERLAY" docker://ghcr.io/eessi/build-node:debian10
