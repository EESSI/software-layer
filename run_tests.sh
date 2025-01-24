#!/bin/bash
#
# This script gets invoked by the bot/test.sh script to run within the EESSI container
# Thus, this script defines all of the steps that should run for the tests.
# Note that, unless we have good reason, we don't run test steps in the prefix environment:
# users also typically don't run in the prefix environment, and we want to check if the
# software works well in that specific setup.
#
# This script is part of the EESSI software layer, see
# https://github.com/EESSI/software-layer.git
#
# author: Caspar van Leeuwen (@casparvl)
#
# license: GPLv2
#

base_dir=$(dirname $(realpath $0))
source ${base_dir}/init/eessi_defaults

# Git clone has to be run in compat layer, to make the git command available
./run_in_compat_layer_env.sh "git clone https://github.com/EESSI/test-suite EESSI-test-suite"

# Run the test suite
./test_suite.sh "$@"
