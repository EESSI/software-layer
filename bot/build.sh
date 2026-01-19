#!/usr/bin/env bash

# give up as soon as any error occurs
set -e

TOPDIR=$(dirname $(realpath $0))

# Clone a the commit from software-layer-script that corresponds to `bot/commit_sha`
commit_sha=$(cat ${TOPDIR}/commit_sha)

# Get a shallow clone first
git clone --depth 1 --filter=blob:none --no-checkout https://github.com/EESSI/software-layer-scripts

# Fetch the relevant commit & check it out
cd software-layer-scripts
git fetch --depth=1 origin ${commit_sha}
git checkout --detach ${commit_sha}
cd ..

# symlink everything, except for:
# - common files like LICENSE and README.md
# - 'bot' subdirectory, there we need to be a bit more careful (see below)
for file in $(ls software-layer-scripts | egrep -v 'easystacks|LICENSE|README.md|^bot'); do
    ln -s software-layer-scripts/${file}
done

# symlink all scripts in 'bot' subdirectory, except for bot/build.sh
for file in $(ls software-layer-scripts/bot | grep -v '^build.sh'); do
    ln -s ../software-layer-scripts/bot/${file} bot/${file}
done

# call out to bot/build.sh script from software-layer-scripts
software-layer-scripts/bot/build.sh

# INSERT BOGUS COMMENT
