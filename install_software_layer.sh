#!/bin/bash
base_dir=$(dirname $(realpath $0))
source ${base_dir}/init/eessi_defaults
if [ $EUID -eq 0 ]; then
    ./EESSI-remove-software.sh "$@"
    exec runuser -u eessi $( readlink -f "$0" ) -- "$@"
fi
./run_in_compat_layer_env.sh ./EESSI-install-software.sh "$@"
