#!/bin/bash

set -ev

tmpdir=$(mktemp -d)

pilot_version='2021.06'
cpu_arch='aarch64/graviton2'
bash="/cvmfs/pilot.eessi-hpc.org/${pilot_version}/compat/linux/$(uname -m)/bin/bash"

# build software and create tarball
build_tar_out=$tmpdir/build-and-tar.out
./run-script-in-build-container.sh $bash build-and-tar.sh $pilot_version $cpu_arch | tee $build_tar_out

eessi_tarball=$(grep 'EESSI tarball to ingest created: ' $build_tar_out | cut -f2 -d:)
eessi_tarball=/tmp/eessi/EESSI/home/$(basename $eessi_tarball)

# upload tarball to S3
eessi-upload-to-staging $eessi_tarball

# open PR to staging repo
git clone https://github.com/EESSI/staging
cd staging
git checkout -b ${pilot_version}_${cpu_arch}_$(date +%s)
msg="new stuff for $pilot_version $cpu_arch"
git commit -am $msg
gh pr create --base main --body "$(basename $eessi_tarball)" -t $msg
