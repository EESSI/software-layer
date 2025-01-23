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

# Make sure we clone the latest version. This assumes versions are of the format "v1.2.3", then picks the latest
# then checks it out
TEST_CLONE="git clone https://github.com/EESSI/test-suite EESSI-test-suite && cd EESSI-test-suite"
LATEST_VERSION="VERSION=$(git tag | grep "^v[0-9]\+\.[0-9]\+\.[0-9]\+$" | sort -t. -k 1,1n -k 2,2n -k 3,3n | tail -1)"
CHECKOUT_LATEST="git checkout ${VERSION}"

# Git clone has to be run in compat layer, to make the git command available
./run_in_compat_layer_env.sh "${TEST_CLONE} && ${LATEST_VERSION} && ${CHECKOUT_LATEST}"

# Run the test suite
./test_suite.sh "$@"
