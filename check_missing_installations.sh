#!/bin/bash
#
# Script to check for missing installations in EESSI pilot software stack (version 2021.12)

TOPDIR=$(dirname $(realpath $0))

TMPDIR=$(mktemp -d)

source $TOPDIR/utils.sh

source $TOPDIR/configure_easybuild

echo ">> Checking for missing installations in ${EASYBUILD_INSTALLPATH}..."
ok_msg="No missing installations, party time!"
fail_msg="On no, some installations are still missing, how did that happen?!"
eb_missing_out=$TMPDIR/eb_missing.out
# we need to use --from-pr to pull in some easyconfigs that are not available in EasyBuild version being used
# PR #16531: Nextflow-22.10.1.eb
${EB:-eb} --from-pr 16531 --easystack eessi-${EESSI_PILOT_VERSION}.yml --experimental --missing | tee ${eb_missing_out}
grep "No missing modules" ${eb_missing_out} > /dev/null
check_exit_code $? "${ok_msg}" "${fail_msg}"
