#!/bin/bash

set -e

# see https://github.com/apptainer/singularity/issues/5390#issuecomment-899111181
sudo apt-get install alien
alien --version
# stick to Apptainer < 1.3.0 by downloading from EPEL 8.8 archive,
# since CI workflow for testing scripts hangs/fails when using Apptainer 1.3.0
# cfr. https://github.com/EESSI/software-layer/pull/514
epel_subdir="pub/epel/8"
epel_subdir="pub/archive/epel/8.8"
apptainer_rpm=$(curl --silent -L https://dl.fedoraproject.org/${epel_subdir}/Everything/x86_64/Packages/a/ | grep 'apptainer-[0-9]' | sed 's/.*\(apptainer[0-9._a-z-]*.rpm\).*/\1/g')
curl -OL https://dl.fedoraproject.org/${epel_subdir}/Everything/x86_64/Packages/a/${apptainer_rpm}
sudo alien -d ${apptainer_rpm}
sudo apt install ./apptainer*.deb
apptainer --version
# also check whether 'singularity' command is still provided by Apptainer installation
singularity --version
