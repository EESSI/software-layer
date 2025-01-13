#!/bin/bash

set -e

# see https://github.com/apptainer/singularity/issues/5390#issuecomment-899111181
sudo apt-get install alien
alien --version
epel_subdir="pub/epel/8"
apptainer_rpm=$(curl --silent -L https://dl.fedoraproject.org/${epel_subdir}/Everything/x86_64/Packages/a/ | grep 'apptainer-[0-9]' | sed 's/.*\(apptainer[0-9._a-z-]*.rpm\).*/\1/g')
curl -OL https://dl.fedoraproject.org/${epel_subdir}/Everything/x86_64/Packages/a/${apptainer_rpm}
sudo alien -d ${apptainer_rpm}
sudo apt install ./apptainer*.deb
# No unpriviledged user name spaces in Ubuntu 23.10+
ubuntu_version=$(lsb_release -r | awk '{print $2}')
if [[ $(echo -e "$ubuntu_version\n23.10" | sort -V | head -n 1) == "23.10" ]]; then
    sudo tee /etc/apparmor.d/apptainer << 'EOF'
# Permit unprivileged user namespace creation for apptainer starter
abi <abi/4.0>,
include <tunables/global>
profile apptainer /usr/local/libexec/apptainer/bin/starter{,-suid} 
    flags=(unconfined) {
  userns,
  # Site-specific additions and overrides. See local/README for details.
  include if exists <local/apptainer>
}
EOF
    sudo systemctl reload apparmor
fi
apptainer --version
# also check whether 'singularity' command is still provided by Apptainer installation
singularity --version
