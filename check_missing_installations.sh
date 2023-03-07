#!/bin/bash
#
# Script to check for missing installations in EESSI pilot software stack (version 2021.12)
#
# author: Kenneth Hoste (@boegel)
#
# license: GPLv2
#

TOPDIR=$(dirname $(realpath $0))

if [ -z ${EESSI_PILOT_VERSION} ]; then
    echo "ERROR: \${EESSI_PILOT_VERSION} must be set to run $0!" >&2
    exit 1
fi

LOCAL_TMPDIR=$(mktemp -d)

source $TOPDIR/scripts/utils.sh

source $TOPDIR/configure_easybuild

echo ">> Checking for missing installations in ${EASYBUILD_INSTALLPATH}..."
ok_msg="No missing installations, party time!"
fail_msg="On no, some installations are still missing, how did that happen?!"
eb_missing_out=$LOCAL_TMPDIR/eb_missing.out
# we need to use --from-pr to pull in some easyconfigs that are not available in EasyBuild version being used
# PR #16531: Nextflow-22.10.1.eb
${EB:-eb} --from-pr 16531 --easystack eessi-${EESSI_PILOT_VERSION}.yml --experimental --missing | tee ${eb_missing_out}

# the above assesses the installed software for each easyconfig provided in
# the easystack file and then print messages such as
# `No missing modules!`
# or
# `2 out of 3 required modules missing:`
# depending on the result of the assessment. Hence, we need to check if the
# output does not contain any line with ` required modules missing:`

grep " required modules missing:" ${eb_missing_out} > /dev/null

# we need to process the result (from finding `No missing modules` to NOT finding
# ` required modules missing:` and no other error happened)
#
# if grep returns 1 (` required modules missing:` was NOT found), we set
# MODULES_MISSING to 0, otherwise (it was found or another error) we set it to 1
[[ $? -eq 1 ]] && MODULES_MISSING=0 || MODULES_MISSING=1
check_exit_code ${MODULES_MISSING} "${ok_msg}" "${fail_msg}"
