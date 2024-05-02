#!/bin/bash
function echo_yellow_stderr() {
    echo -e "\e[33m${1}\e[0m" >&2
}

echo_yellow_stderr
echo_yellow_stderr "WARNING: the EESSI pilot repository is deprecated and no longer supported."
echo_yellow_stderr
echo_yellow_stderr "We strongly recommend to switch to the EESSI production repository (software.eessi.io)."
echo_yellow_stderr "See https://www.eessi.io/docs/repositories/software.eessi.io/ for more information."
echo_yellow_stderr
echo_yellow_stderr "You can find instructions for making the production repository available at:"
echo_yellow_stderr "https://www.eessi.io/docs/getting_access/is_eessi_accessible/"
echo_yellow_stderr
echo_yellow_stderr "If the production repository is available on your system, please run"
echo_yellow_stderr
echo_yellow_stderr "    source /cvmfs/software.eessi.io/versions/2023.06/init/bash"
echo_yellow_stderr
echo_yellow_stderr "to prepare your environment for using the EESSI production repository."
echo_yellow_stderr
echo_yellow_stderr "See also https://eessi.github.io/docs/using_eessi/setting_up_environment."
echo_yellow_stderr
echo_yellow_stderr "If you have any questions or if you need any help, please open a support ticket:"
echo_yellow_stderr "https://www.eessi.io/docs/support"
echo_yellow_stderr
echo_yellow_stderr "This script will now try to automatically switch to the production repository,"
echo_yellow_stderr "unless it's not available or if \$EESSI_FORCE_PILOT is set."
echo_yellow_stderr
echo_yellow_stderr
