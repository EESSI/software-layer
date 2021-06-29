#!/bin/bash

set -e

if [ $# -ne 2 ]; then
    echo "ERROR: Usage: $0 <pilot version (example: 2021.03)> <CPU arch subdir (example: x86_64/amd/zen2)>" >&2
    exit 1
fi
pilot_version=$1
cpu_arch_subdir=$2

cd $HOME/software-layer

./EESSI-pilot-install-software.sh

os="linux"
timestamp=`date +%s`
target_tgz="$HOME/eessi-${pilot_version}-software-${os}-`echo ${cpu_arch_subdir} | tr '/' '-'`-${timestamp}.tar.gz"

./create_tarball.sh $pilot_version $cpu_arch_subdir $target_tgz

echo "EESSI tarball to ingest created: $target_tgz"
