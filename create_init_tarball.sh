#!/bin/bash

SOFTWARE_LAYER_TARBALL_URL=https://github.com/trz42/software-layer/tarball/main

set -eo pipefail

function echo_green() {
    echo -e "\e[32m$1\e[0m"
}

function echo_red() {
    echo -e "\e[31m$1\e[0m"
}

function error() {
    echo_red "ERROR: $1" >&2
    exit 1
}

if [ $# -ne 1 ]; then
    echo "Usage: $0 <EESSI version>" >&2
    exit 1
fi

version=$1

# Check if the EESSI version number encoded in the filename
# is valid, i.e. matches the format YYYY.DD
if ! echo "${version}" | egrep -q '^20[0-9][0-9]\.(0[0-9]|1[0-2])$'
then
    error "${version} is not a valid EESSI version."
fi

tartmp=$(mktemp -t -d init.XXXXX)
mkdir "${tartmp}/${version}"
tarname="eessi-${version}-init-$(date +%s).tar.gz"
curl -Ls ${SOFTWARE_LAYER_TARBALL_URL} | tar xzf - -C "${tartmp}/${version}" --strip-components=1 --wildcards */init/
source "${tartmp}/${version}/init/minimal_eessi_env"
if [ "${EESSI_PILOT_VERSION}" != "${version}" ]
then
  error "Specified version ${version} does not match version ${EESSI_PILOT_VERSION} in the init files!"
fi
tar czf "${tarname}" -C "${tartmp}" "${version}"
rm -rf "${tartmp}"

echo_green "Done! Created tarball ${tarname}."
