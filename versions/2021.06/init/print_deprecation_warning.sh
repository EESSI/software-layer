#!/bin/bash
function echo_yellow_stderr() {
    echo -e "\e[33m${1}\e[0m" >&2
}

echo_yellow_stderr
echo_yellow_stderr "WARNING: Version 2021.06 of the EESSI pilot repository has been removed since 16 May 2023."
echo_yellow_stderr
echo_yellow_stderr "Version 2021.12 of the EESSI pilot repository can be used as a drop-in replacement, "
echo_yellow_stderr "so we have prepared your environment to use that instead."
echo_yellow_stderr
echo_yellow_stderr "In the future, please run"
echo_yellow_stderr
echo_yellow_stderr "    source /cvmfs/pilot.eessi-hpc.org/latest/init/bash"
echo_yellow_stderr
echo_yellow_stderr "to prepare your start using the EESSI pilot repository."
echo_yellow_stderr
echo_yellow_stderr "See also https://eessi.github.io/docs/using_eessi/setting_up_environment ."
echo_yellow_stderr
