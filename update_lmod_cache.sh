#!/bin/bash
#
# Script to update Lmod cache in EESSI
#

TOPDIR=$(dirname $(realpath $0))

source $TOPDIR/utils.sh

if [ $# -ne 2 ]; then
    echo "Usage: $0 <path to compat layer directory> <path to software installation prefix>" >&2
    exit 1
fi
EPREFIX=$1
EASYBUILD_INSTALLPATH=$2

if [ ! -d $EPREFIX ]; then
    echo "\$EPREFIX does not exist!" >&2
    exit 2
fi
if [ ! -d $EASYBUILD_INSTALLPATH ]; then
    echo "\$EASYBUILD_INSTALLPATH does not exist!" >&2
    exit 2
fi

source $EPREFIX/usr/share/Lmod/init/bash

# we need to specify the path to the Lmod cache dir + timestamp file to ensure
# that update_lmod_system_cache_files updates correct Lmod cache
lmod_cache_dir=${EASYBUILD_INSTALLPATH}/.lmod/cache
lmod_cache_timestamp_file=${EASYBUILD_INSTALLPATH}/.lmod/cache/timestamp
modpath=${EASYBUILD_INSTALLPATH}/modules/all

${LMOD_DIR}/update_lmod_system_cache_files -d ${lmod_cache_dir} -t ${lmod_cache_timestamp_file} ${modpath}
check_exit_code $? "Lmod cache updated" "Lmod cache update failed!"

ls -lrt ${EASYBUILD_INSTALLPATH}/.lmod/cache
