#!/bin/bash
base_dir=$(dirname $(realpath $0))
source ${base_dir}/init/eessi_defaults
./run_in_compat_layer_env.sh ./test_suite.sh "$@"
