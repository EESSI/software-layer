#!/bin/bash
base_dir=$(dirname $(realpath $0))
source ${base_dir}/init/eessi_defaults

# Note: for these tests, we _don't_ run in the compat layer env
# These tests should mimic what users do, and they are typically not in a prefix environment

# Run eb --sanity-check-only on changed easyconfigs
# TODO: in the future we may implement this as a light first check.

# Run the test suite
./run_in_compat_layer_env.sh clone_eessi_test_suite.sh
./test_suite.sh
