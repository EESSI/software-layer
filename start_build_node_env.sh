#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <path for temporary directories>" >&2
    exit 1
fi
export EESSI_TMPDIR=$1
echo "Using $EESSI_TMPDIR as parent for temporary directories..."

# create temporary directories
mkdir -p $EESSI_TMPDIR/{home,overlay-upper,overlay-work}
mkdir -p $EESSI_TMPDIR/{var-lib-cvmfs,var-run-cvmfs}
# configure Singularity
export SINGULARITY_CACHEDIR=$EESSI_TMPDIR/singularity_cache
export SINGULARITY_BIND="$EESSI_TMPDIR/var-run-cvmfs:/var/run/cvmfs,$EESSI_TMPDIR/var-lib-cvmfs:/var/lib/cvmfs"
export SINGULARITY_HOME="$EESSI_TMPDIR/home:/home/$USER"

# set environment variables for fuse mounts in Singularity container
export EESSI_PILOT_READONLY="container:cvmfs2 pilot.eessi-hpc.org /cvmfs_ro/pilot.eessi-hpc.org"
export EESSI_PILOT_WRITABLE_OVERLAY="container:fuse-overlayfs -o lowerdir=/cvmfs_ro/pilot.eessi-hpc.org -o upperdir=$EESSI_TMPDIR/overlay-upper -o workdir=$EESSI_TMPDIR/overlay-work /cvmfs/pilot.eessi-hpc.org"

# start shell in Singularity container, with EESSI repository mounted with writable overlay
echo "Starting Singularity container..."
singularity shell --fusemount "$EESSI_PILOT_READONLY" --fusemount "$EESSI_PILOT_WRITABLE_OVERLAY" docker://ghcr.io/eessi/build-node:debian10
