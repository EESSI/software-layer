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

if [ "$#" -eq 1 ]; then
    true
elif [ "$#" -eq 2 ]; then
    echo "Using $2 to give create exceptions for PR filtering of easystack"
    # Find lines that are added and use from-pr, make them unique, grab the
    # PR numbers and use them to construct something we can use within awk
    pr_exceptions=$(grep ^+ $2 | grep from-pr | uniq | awk '{print $3}' | xargs -i echo " || /'{}'/")
else
    echo "ERROR: Usage: $0 <path to easystack file> (<optional path to PR diff>)" >&2
    exit 1
fi
easystack=$1

LOCAL_TMPDIR=$(mktemp -d)

# Clone the develop branch of EasyBuild and use that to search for easyconfigs

if [[ -z ${EASYBUILD_ROBOT_PATHS} ]]; then
    git clone -b develop https://github.com/easybuilders/easybuild-easyconfigs.git $LOCAL_TMPDIR/easyconfigs
    export EASYBUILD_ROBOT_PATHS=$LOCAL_TMPDIR/easyconfigs/easybuild/easyconfigs
fi

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
if [ "$exit_code" -ne 0 ] && [ ! -z "$pr_exceptions" ]; then
    # We might have failed due to unmerged PRs. Try to make exceptions for --from-pr added in this PR
    # to software-layer, and see if then it passes. If so, we can report a more specific fail_msg
    # Note that if no --from-pr's were used in this PR, $pr_exceptions will be empty and we might as
    # well skip this check - unmerged PRs can not be the reason for the non-zero exit code in that scenario

    # Let's use awk so we can allow for exceptions if we are given a PR diff file
    awk_command="awk '\!/'from-pr'/ EXCEPTIONS' $easystack"
    awk_command=${awk_command/\\/}  # Strip out the backslash we needed for !
    eval ${awk_command/EXCEPTIONS/$pr_exceptions} > ${tmp_easystack}

    msg=">> Checking for missing installations in ${EASYBUILD_INSTALLPATH},"
    msg="${msg} allowing for --from-pr's that were added in this PR..."
    echo ${msg}
    eb_missing_out=$LOCAL_TMPDIR/eb_missing_with_from_pr.out
    ${EB:-eb} --easystack ${tmp_easystack} --missing 2>&1 | tee ${eb_missing_out}
    exit_code_with_from_pr=${PIPESTATUS[0]}

    # If now we succeeded, the reason must be that we originally stripped the --from-pr's
    if [ "$exit_code_with_from_pr" -eq 0 ]; then
        fail_msg="$fail_msg (are you sure all PRs referenced have been merged in EasyBuild?)"
    fi
fi

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
