#!/bin/bash
#
# Dummy script, no tests yet
#
# This script is part of the EESSI software layer, see
# https://github.com/EESSI/software-layer.git
#
# author: Kenneth Hoste (HPC-UGent)
#
# license: GPLv2
#

# Create tmp file for output of test step
test_outerr=$(mktemp test.outerr.XXXX)

# TODO: this should not be hardcoded. Ideally, we put some logic in place to discover the newest version
# of the ReFrame module available in the current environment
(module load ReFrame/4.3.3 || echo "FAILED to load the ReFrame module") 2>&1 | tee -a ${test_outerr}

# Check ReFrame came with the hpctestlib and we can import it
(python3 -c 'import hpctestlib.sciapps.gromacs' || echo "FAILED to load hpctestlib") 2>&1 | tee -a ${test_outerr}

# Clone the EESSI test suite
git clone https://github.com/EESSI/test-suite EESSI-test-suite
export TESTSUITEPREFIX=$PWD/EESSI-test-suite
export PYTHONPATH=$TESTSUITEPREFIX:$PYTHONPATH

# Check that we can import from the testsuite
(python3 -c 'import eessi.testsuite' || echo "FAILED to import from eessi.testsuite in Python") 2>&1 | tee -a ${test_outerr}

# Configure ReFrame
export RFM_CONFIG_FILES=$TESTSUITEPREFIX/config/github_actions.py
export RFM_CHECK_SEARCH_PATH=$TESTSUITEPREFIX/eessi/testsuite/tests
export RFM_CHECK_SEARCH_RECURSIVE=1
export RFM_PREFIX=$PWD/reframe_runs

# Check we can run reframe
(reframe --version || echo "FAILED to run ReFrame") 2>&1 | tee -a ${test_outerr}

# List the tests we want to run
export REFRAME_ARGS='--tag CI --tag 1_nodes'
(reframe "${REFRAME_ARGS}" --list || echo "FAILED to list ReFrame tests") 2>&1 | tee -a ${test_outerr}

# Run all tests
reframe "${REFRAME_ARGS}" --run 2>&1 | tee -a ${test_outerr}

exit 0
