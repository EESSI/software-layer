#!/bin/bash

current_dir=$(dirname $(realpath $0))

# Get arch type from EESSI environment
if [[ -z "${EESSI_CPU_FAMILY}" ]]; then
  # set up basic environment variables, EasyBuild and Lmod
  EESSI_SILENT=1 source /cvmfs/pilot.eessi-hpc.org/latest/init/bash
fi
eessi_cpu_family="${EESSI_CPU_FAMILY:-x86_64}"

# Get OS family
# TODO: needs more thorough testing
os_family=$(uname | tr '[:upper:]' '[:lower:]')

# Get OS version
# TODO: needs more thorough testing, taken from https://unix.stackexchange.com/a/6348
if [ -f /etc/os-release ]; then
  # freedesktop.org and systemd
  . /etc/os-release
  os=$NAME
  ver=$VERSION_ID
  if [[ "$os" == *"Rocky"* ]]; then
    os="rhel"
    # Convert OS version to major versions, e.g. rhel8.5 -> rhel8
    ver=${ver%.*}
  fi
  if [[ "$os" == *"Debian"* ]]; then
    os="debian"
  fi
  if [[ "$os" == *"Ubuntu"* ]]; then
    os="ubuntu"
    # Convert OS version
    ver=${ver/./}
  fi
elif type lsb_release >/dev/null 2>&1; then
  # linuxbase.org
  os=$(lsb_release -si)
  ver=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
  # For some versions of Debian/Ubuntu without lsb_release command
  . /etc/lsb-release
  os=$DISTRIB_ID
  ver=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
  # Older Debian/Ubuntu/etc.
  os=Debian
  ver=$(cat /etc/debian_version)
else
  # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
  os=$(uname -s)
  ver=$(uname -r)
fi

# build URL for CUDA libraries
cuda_url="https://developer.download.nvidia.com/compute/cuda/repos/"${os}${ver}"/"${eessi_cpu_family}"/"
# get all versions in decending order
files=$(curl -s "${cuda_url}" | grep 'cuda-compat' | sed 's/<\/\?[^>]\+>//g' | xargs -n1 | /cvmfs/pilot.eessi-hpc.org/latest/compat/linux/${eessi_cpu_family}/bin/sort -r --version-sort )
if [[ -z "${files// }" ]]; then
        echo "Could not find any compat lib files under" ${cuda_url}
        exit 1
fi
for file in $files; do echo "${cuda_url}$file"; done
