echo "Initializing environment for EESSI..."

export EESSI_MOUNT="/tmp/cvmfs"
export EESSI_REPO="pilot.eessi-hpc.org"
export EESSI_CPU_SUBDIR="$(python eessi_cpu_subdir.py)"
export EESSI_PATH="$EESSI_MOUNT/$EESSI_REPO/$EESSI_CPU_SUBDIR"

echo ">> EESSI path: $EESSI_PATH"
