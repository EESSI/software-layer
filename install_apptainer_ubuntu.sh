#!/bin/bash

set -e

sudo apt update
sudo apt install -y software-properties-common

sudo add-apt-repository -y ppa:apptainer/ppa
sudo apt update
sudo apt install -y apptainer-suid

apptainer --version
# also check whether 'singularity' command is still provided by Apptainer installation
singularity --version
