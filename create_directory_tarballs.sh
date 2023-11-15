#!/bin/bash

SOFTWARE_LAYER_TARBALL_URL=https://github.com/EESSI/software-layer/tarball/2023.06

set -eo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <EESSI version>" >&2
    exit 1
fi

version=$1

TOPDIR=$(dirname $(realpath $0))

source $TOPDIR/scripts/utils.sh

# Check if the EESSI version number encoded in the filename
# is valid, i.e. matches the format YYYY.DD
if ! echo "${version}" | egrep -q '^20[0-9][0-9]\.(0[0-9]|1[0-2])$'
then
    fatal_error "${version} is not a valid EESSI version."
fi

# Create tarball of init directory
tartmp=$(mktemp -t -d init.XXXXX)
mkdir "${tartmp}/${version}"
tarname="eessi-${version}-init-$(date +%s).tar.gz"
curl -Ls ${SOFTWARE_LAYER_TARBALL_URL} | tar xzf - -C "${tartmp}/${version}" --strip-components=1 --no-wildcards-match-slash --wildcards '*/init/'
source "${tartmp}/${version}/init/minimal_eessi_env"
if [ "${EESSI_VERSION}" != "${version}" ]
then
  fatal_error "Specified version ${version} does not match version ${EESSI_VERSION} in the init files!"
fi
tar czf "${tarname}" -C "${tartmp}" "${version}"
rm -rf "${tartmp}"

echo_green "Done! Created tarball ${tarname}."

# Create tarball of scripts directory
# Version check has already been performed and would have caused script to exit at this point in case of problems
tartmp=$(mktemp -t -d scripts.XXXXX)
mkdir "${tartmp}/${version}"
tarname="eessi-${version}-scripts-$(date +%s).tar.gz"
curl -Ls ${SOFTWARE_LAYER_TARBALL_URL} | tar xzf - -C "${tartmp}/${version}" --strip-components=1 --no-wildcards-match-slash --wildcards '*/scripts/'
tar czf "${tarname}" -C "${tartmp}" "${version}"
rm -rf "${tartmp}"

echo_green "Done! Created tarball ${tarname}."
