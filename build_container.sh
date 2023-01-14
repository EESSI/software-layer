#!/bin/bash

BUILD_CONTAINER="docker://ghcr.io/eessi/build-node:debian11"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <shell|run> <path for temporary directories>" >&2
    exit 1
fi
SHELL_OR_RUN=$1
EESSI_TMPDIR=$2
shift 2

if [ "$SHELL_OR_RUN" == "run" ] && [ $# -eq 0 ]; then
    echo "ERROR: No command specified to run?!" >&2
    exit 1
fi

# make sure specified temporary directory exists
mkdir -p $EESSI_TMPDIR

echo "Using $EESSI_TMPDIR as parent for temporary directories..."

# create temporary directories
mkdir -p $EESSI_TMPDIR/{home,overlay-upper,overlay-work}
mkdir -p $EESSI_TMPDIR/{var-lib-cvmfs,var-run-cvmfs}
# configure Singularity
export SINGULARITY_CACHEDIR=$EESSI_TMPDIR/singularity_cache

# take into account that $SINGULARITY_BIND may be defined already, to bind additional paths into the build container
BIND_PATHS="$EESSI_TMPDIR/var-run-cvmfs:/var/run/cvmfs,$EESSI_TMPDIR/var-lib-cvmfs:/var/lib/cvmfs,$EESSI_TMPDIR"
if [ -z $SINGULARITY_BIND ]; then
    export SINGULARITY_BIND="$BIND_PATHS"
else
    export SINGULARITY_BIND="$SINGULARITY_BIND,$BIND_PATHS"
fi

# allow that SINGULARITY_HOME is defined before script is run
if [ -z $SINGULARITY_HOME ]; then
    export SINGULARITY_HOME="$EESSI_TMPDIR/home:/home/$USER"
fi

# set environment variables for fuse mounts in Singularity container
export EESSI_PILOT_READONLY="container:cvmfs2 pilot.eessi-hpc.org /cvmfs_ro/pilot.eessi-hpc.org"
export EESSI_PILOT_WRITABLE_OVERLAY="container:fuse-overlayfs -o lowerdir=/cvmfs_ro/pilot.eessi-hpc.org -o upperdir=$EESSI_TMPDIR/overlay-upper -o workdir=$EESSI_TMPDIR/overlay-work /cvmfs/pilot.eessi-hpc.org"

# pass $EESSI_SOFTWARE_SUBDIR_OVERRIDE into build container (if set)
if [ ! -z ${EESSI_SOFTWARE_SUBDIR_OVERRIDE} ]; then
    export SINGULARITYENV_EESSI_SOFTWARE_SUBDIR_OVERRIDE=${EESSI_SOFTWARE_SUBDIR_OVERRIDE}
    # also specify via $APPTAINERENV_* (future proof, cfr. https://apptainer.org/docs/user/latest/singularity_compatibility.html#singularity-environment-variable-compatibility)
    export APPTAINERENV_EESSI_SOFTWARE_SUBDIR_OVERRIDE=${EESSI_SOFTWARE_SUBDIR_OVERRIDE}
fi

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
