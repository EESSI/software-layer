#!/bin/bash

set -e

# see https://github.com/apptainer/singularity/issues/5390#issuecomment-899111181
sudo apt-get install alien
alien --version
apptainer_rpm=$(curl --silent -L https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/a/ | grep 'apptainer-[0-9]' | sed 's/.*\(apptainer[0-9._a-z-]*.rpm\).*/\1/g')
curl -OL https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/a/${apptainer_rpm}
sudo alien -d ${apptainer_rpm}
sudo apt install ./apptainer*.deb
apptainer --version
# also check whether 'singularity' command is still provided by Apptainer installation
singularity --version
