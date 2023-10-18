#!/bin/bash

base_dir=$(dirname $(realpath $0))

BUILD_CONTAINER="docker://ghcr.io/eessi/build-node:debian11"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <shell|run> <path for temporary directories> <extra arguments for singularity (optional)>" >&2
    exit 1
fi
SHELL_OR_RUN=$1
EESSI_TMPDIR=$2
EXTRA_ARGS_SINGULARITY=$3

shift 3

if [ "$SHELL_OR_RUN" == "run" ] && [ $# -eq 0 ]; then
    echo "ERROR: No command specified to run?!" >&2
    exit 1
fi

# make sure specified temporary directory exists
mkdir -p $EESSI_TMPDIR

echo "Using $EESSI_TMPDIR as parent for temporary directories..."

# create temporary directories
mkdir -p $EESSI_TMPDIR/{home,overlay-upper,overlay-work}
mkdir -p $EESSI_TMPDIR/{var-lib-cvmfs,var-run-cvmfs,opt-eessi}
# configure Singularity
export SINGULARITY_CACHEDIR=$EESSI_TMPDIR/singularity_cache

# take into account that $SINGULARITY_BIND may be defined already, to bind additional paths into the build container
BIND_PATHS="$EESSI_TMPDIR/var-run-cvmfs:/var/run/cvmfs,$EESSI_TMPDIR/var-lib-cvmfs:/var/lib/cvmfs,$EESSI_TMPDIR/opt-eessi:/opt/eessi,$EESSI_TMPDIR"
if [ -z $SINGULARITY_BIND ]; then
    export SINGULARITY_BIND="$BIND_PATHS"
else
    export SINGULARITY_BIND="$SINGULARITY_BIND,$BIND_PATHS"
fi

# allow that SINGULARITY_HOME is defined before script is run
if [ -z $SINGULARITY_HOME ]; then
    export SINGULARITY_HOME="$EESSI_TMPDIR/home:/home/$USER"
fi

source ${base_dir}/init/eessi_defaults
# strip "/cvmfs/" from default setting
repo_name=${EESSI_CVMFS_REPO/\/cvmfs\//}

# set environment variables for fuse mounts in Singularity container
export EESSI_PILOT_READONLY="container:cvmfs2 ${repo_name} /cvmfs_ro/${repo_name}"
export EESSI_PILOT_WRITABLE_OVERLAY="container:fuse-overlayfs -o lowerdir=/cvmfs_ro/${repo_name} -o upperdir=$EESSI_TMPDIR/overlay-upper -o workdir=$EESSI_TMPDIR/overlay-work ${EESSI_CVMFS_REPO}"

# pass $EESSI_SOFTWARE_SUBDIR_OVERRIDE into build container (if set)
if [ ! -z ${EESSI_SOFTWARE_SUBDIR_OVERRIDE} ]; then
    export SINGULARITYENV_EESSI_SOFTWARE_SUBDIR_OVERRIDE=${EESSI_SOFTWARE_SUBDIR_OVERRIDE}
    # also specify via $APPTAINERENV_* (future proof, cfr. https://apptainer.org/docs/user/latest/singularity_compatibility.html#singularity-environment-variable-compatibility)
    export APPTAINERENV_EESSI_SOFTWARE_SUBDIR_OVERRIDE=${EESSI_SOFTWARE_SUBDIR_OVERRIDE}
fi

if [ "$SHELL_OR_RUN" == "shell" ]; then
    # start shell in Singularity container, with EESSI repository mounted with writable overlay
    echo "Starting Singularity build container..."
    singularity shell --fusemount "$EESSI_PILOT_READONLY" --fusemount "$EESSI_PILOT_WRITABLE_OVERLAY" $EXTRA_ARGS_SINGULARITY $BUILD_CONTAINER
elif [ "$SHELL_OR_RUN" == "run" ]; then
    echo "Running '$@' in Singularity build container..."
    singularity exec --fusemount "$EESSI_PILOT_READONLY" --fusemount "$EESSI_PILOT_WRITABLE_OVERLAY" $EXTRA_ARGS_SINGULARITY $BUILD_CONTAINER "$@"
else
    echo "ERROR: Unknown action specified: $SHELL_OR_RUN (should be either 'shell' or 'run')" >&2
    exit 1
fi
