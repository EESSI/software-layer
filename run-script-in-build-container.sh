#!/bin/bash

set -e

if [ $# -lt 2 ]; then
    echo "ERROR: Usage: $0 <path to bash in compat layer> <script to run in container>" >&2
    exit 1
fi
bash=$1
script=$2
shift
shift

tmpdir=$(mktemp -d)
cp -a $script ${tmpdir}
tmpscript="$tmpdir/$(basename $script)"
chmod u+x $tmpscript

export EESSI_TMPDIR=/tmp/$USER/EESSI
mkdir -p $EESSI_TMPDIR
mkdir -p $EESSI_TMPDIR/{home,overlay-upper,overlay-work}
mkdir -p $EESSI_TMPDIR/{var-lib-cvmfs,var-run-cvmfs}
export SINGULARITY_CACHEDIR=$EESSI_TMPDIR/singularity_cache
export SINGULARITY_BIND="$EESSI_TMPDIR/var-run-cvmfs:/var/run/cvmfs,$EESSI_TMPDIR/var-lib-cvmfs:/var/lib/cvmfs"
export SINGULARITY_HOME="$EESSI_TMPDIR/home:/home/$USER"
export EESSI_PILOT_READONLY="container:cvmfs2 pilot.eessi-hpc.org /cvmfs_ro/pilot.eessi-hpc.org"
export EESSI_PILOT_WRITABLE_OVERLAY="container:fuse-overlayfs -o lowerdir=/cvmfs_ro/pilot.eessi-hpc.org -o upperdir=$EESSI_TMPDIR/overlay-upper -o workdir=$EESSI_TMPDIR/overlay-work /cvmfs/pilot.eessi-hpc.org"

echo "singularity exec --fusemount "$EESSI_PILOT_READONLY" --fusemount "$EESSI_PILOT_WRITABLE_OVERLAY" docker://ghcr.io/eessi/build-node:debian10 $bash -l $tmpscript $@"
singularity exec --fusemount "$EESSI_PILOT_READONLY" --fusemount "$EESSI_PILOT_WRITABLE_OVERLAY" docker://ghcr.io/eessi/build-node:debian10 $bash -l $tmpscript $@

rm -r $tmpdir
