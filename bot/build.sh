#!/usr/bin/env bash

# give up as soon as any error occurs
set -e

git clone -b cuda_host_injections_202506 https://github.com/casparvl/software-layer-scripts

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
