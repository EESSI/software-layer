#!/bin/bash
base_dir=$(dirname $(realpath $0))
source ${base_dir}/init/eessi_defaults
$base_dir/run_in_compat_layer_env.sh $base_dir/EESSI-install-software.sh "$@"
