# Set group (as required, useful if you would like to share the cache with others)
MYGROUP=$GROUPS

# Set user
MYUSER=$USER

# Set path to shared space
SHAREDSPACE="/scratch-shared/"

# Set path to (node) local space to store a local alien cache (e.g., /tmp or /dev/shm)
# WARNING: This directory needs to exist on the nodes where you will mount or you will
#          get a binding error from Singularity!
LOCALSPACE="${TMPDIR}"

# Chose the Singularity image to use
STACK="2020.12"
SINGULARITY_REMOTE="client-pilot:centos7-$(uname -m)"

#########################################################################
# Variables below this point can be changed (but they don't need to be) #
#########################################################################

SINGULARITY_IMAGE="$SHAREDSPACE/$MYGROUP/$MYUSER/${SINGULARITY_REMOTE/:/_}.sif"

# Set text colours for info on commands being run
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Make the directory structures
SINGULARITY_CVMFS_ALIEN="$SHAREDSPACE/$MYGROUP/alien_$STACK"
mkdir -p $SINGULARITY_CVMFS_ALIEN

SINGULARITY_HOMEDIR="$SHAREDSPACE/$MYGROUP/$MYUSER/home"
mkdir -p $SINGULARITY_HOMEDIR

##################################################
# No more variable definitions beyond this point #
##################################################

# Pull the container
#if [ ! -f $SINGULARITY_IMAGE ]; then
#    echo -e "${YELLOW}\nPulling singularity image\n${NC}"
#    singularity pull $SINGULARITY_IMAGE docker://eessi/$SINGULARITY_REMOTE
#fi

# Create a default.local file in the users home
# We use a tiered cache, with a shared alien cache and a local alien cache.
# We populate the shared alien cache and that is used to fill the local
# alien cache (which is usually in a space that gets cleaned up like /tmp or /dev/shm)
if [ ! -f $SINGULARITY_HOMEDIR/default.local ]; then
    echo -e "${YELLOW}\nCreating CVMFS configuration for shared and local alien caches\n${NC}"
    echo "# Custom settings" > $SINGULARITY_HOMEDIR/default.local
    echo "CVMFS_WORKSPACE=/var/lib/cvmfs" >> $SINGULARITY_HOMEDIR/default.local
    echo "CVMFS_CACHE_PRIMARY=hpc" >> $SINGULARITY_HOMEDIR/default.local
    echo "CVMFS_CACHE_hpc_TYPE=tiered" >> $SINGULARITY_HOMEDIR/default.local
    echo "CVMFS_CACHE_hpc_UPPER=local" >> $SINGULARITY_HOMEDIR/default.local
    echo "CVMFS_CACHE_hpc_LOWER=alien" >> $SINGULARITY_HOMEDIR/default.local
    echo "CVMFS_CACHE_LOWER_READONLY=no" >> $SINGULARITY_HOMEDIR/default.local
    echo "CVMFS_CACHE_local_TYPE=posix" >> $SINGULARITY_HOMEDIR/default.local
    echo "CVMFS_CACHE_local_SHARED=no" >> $SINGULARITY_HOMEDIR/default.local
    echo "CVMFS_CACHE_local_QUOTA_LIMIT=-1" >> $SINGULARITY_HOMEDIR/default.local
    echo "CVMFS_CACHE_local_ALIEN=\"/local_alien\"" >> $SINGULARITY_HOMEDIR/default.local
    echo "CVMFS_CACHE_alien_TYPE=posix" >> $SINGULARITY_HOMEDIR/default.local
    echo "CVMFS_CACHE_alien_SHARED=no" >> $SINGULARITY_HOMEDIR/default.local
    echo "CVMFS_CACHE_alien_QUOTA_LIMIT=-1" >> $SINGULARITY_HOMEDIR/default.local
    echo "CVMFS_CACHE_alien_ALIEN=\"/shared_alien\"" >> $SINGULARITY_HOMEDIR/default.local
    echo "CVMFS_HTTP_PROXY=\"DIRECT\"" >> $SINGULARITY_HOMEDIR/default.local
fi


# Environment variables
export EESSI_CONFIG="container:cvmfs2 cvmfs-config.eessi-hpc.org /cvmfs/cvmfs-config.eessi-hpc.org"
export EESSI_PILOT="container:cvmfs2 pilot.eessi-hpc.org /cvmfs/pilot.eessi-hpc.org"
export SINGULARITY_HOME="$SINGULARITY_HOMEDIR:/home/$MYUSER"
export SINGULARITY_SCRATCH="/var/lib/cvmfs,/var/run/cvmfs"
# export SINGULARITY_BIND="$SINGULARITY_CVMFS_ALIEN:/shared_alien,$LOCALSPACE:/local_alien"
export SINGULARITY_BIND="$SINGULARITY_CVMFS_ALIEN:/shared_alien,$LOCALSPACE:/local_alien,$SINGULARITY_HOMEDIR/default.local:/etc/cvmfs/default.local"

# Get a shell
echo -e "${YELLOW}\nTo get a shell inside a singularity container (for example), use:\n${NC}"
echo -e "  export EESSI_CONFIG=\"$EESSI_CONFIG\""
echo -e "  export EESSI_PILOT=\"$EESSI_PILOT\""
echo -e "  export SINGULARITY_HOME=\"$SINGULARITY_HOME\""
echo -e "  export SINGULARITY_BIND=\"$SINGULARITY_BIND\""
echo -e "  export SINGULARITY_SCRATCH=\"/var/lib/cvmfs,/var/run/cvmfs\""
echo -e "  singularity shell --fusemount \"\$EESSI_CONFIG\" --fusemount \"\$EESSI_PILOT\" $SINGULARITY_IMAGE"
