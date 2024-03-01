#!/bin/bash
#
# Script to check for missing installations in EESSI software stack
#
# author: Kenneth Hoste (@boegel)
# author: Thomas Roeblitz (@trz42)
#
# license: GPLv2
#

TOPDIR=$(dirname $(realpath $0))

if [ $# -ne 1 ]; then
    echo "ERROR: Usage: $0 <path to easystack file>" >&2
    exit 1
fi
easystack=$1

LOCAL_TMPDIR=$(mktemp -d)

# Clone the develop branch of EasyBuild and use that to search for easyconfigs
git clone -b develop https://github.com/easybuilders/easybuild-easyconfigs.git $LOCAL_TMPDIR/easyconfigs
export EASYBUILD_ROBOT_PATHS=$LOCAL_TMPDIR/easyconfigs/easybuild/easyconfigs

# All PRs used in EESSI are supposed to be merged, so we can strip out all cases of from-pr
tmp_easystack=${LOCAL_TMPDIR}/$(basename ${easystack})
grep -v from-pr ${easystack} > ${tmp_easystack} 

source $TOPDIR/scripts/utils.sh

source $TOPDIR/configure_easybuild

echo ">> Active EasyBuild configuration when checking for missing installations:"
${EB:-eb} --show-config

echo ">> Checking for missing installations in ${EASYBUILD_INSTALLPATH}..."
eb_missing_out=$LOCAL_TMPDIR/eb_missing.out
${EB:-eb} --easystack ${tmp_easystack} --missing 2>&1 | tee ${eb_missing_out}
exit_code=${PIPESTATUS[0]}

ok_msg="Command 'eb --missing ...' succeeded, analysing output..."
fail_msg="Command 'eb --missing ...' failed, check log '${eb_missing_out}'"
check_exit_code ${exit_code} "${ok_msg}" "${fail_msg}"

# the above assesses the installed software for each easyconfig provided in
# the easystack file and then print messages such as
# `No missing modules!`
# or
# `2 out of 3 required modules missing:`
# depending on the result of the assessment. Hence, we need to check if the
# output does not contain any line with ` required modules missing:`

grep " required modules missing:" ${eb_missing_out} > /dev/null
exit_code=$?

# if grep returns 1 (` required modules missing:` was NOT found), we set
# MODULES_MISSING to 0, otherwise (it was found or another error) we set it to 1
[[ ${exit_code} -eq 1 ]] && MODULES_MISSING=0 || MODULES_MISSING=1
ok_msg="No missing installations, party time!"
fail_msg="On no, some installations are still missing, how did that happen?!"
check_exit_code ${MODULES_MISSING} "${ok_msg}" "${fail_msg}"
