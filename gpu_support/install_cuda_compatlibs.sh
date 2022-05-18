#!/bin/bash

libs_url=$1

current_dir=$(dirname $(realpath $0))

# Create a general space for our NVIDIA compat drivers
if [ -w /cvmfs/pilot.eessi-hpc.org/host_injections ]; then
  mkdir -p ${host_injections_dir}
  cd ${host_injections_dir}
else
  echo "Cannot write to eessi host_injections space, exiting now..." >&2
  exit 1
fi

# Check if we have any version installed by checking for the existence of /cvmfs/pilot.eessi-hpc.org/host_injections/nvidia/latest

driver_cuda_version=$(nvidia-smi  -q --display=COMPUTE | grep CUDA | awk 'NF>1{print $NF}' | sed s/\\.//)
eessi_cuda_version=$(LD_LIBRARY_PATH=${host_injections_dir}/latest/compat/:$LD_LIBRARY_PATH nvidia-smi  -q --display=COMPUTE | grep CUDA | awk 'NF>1{print $NF}' | sed s/\\.//)
if [ "$driver_cuda_version" -gt "$eessi_cuda_version" ]; then  echo "You need to update your CUDA compatability libraries"; fi

# Check if our target CUDA is satisfied by what is installed already
# TODO: Find required CUDA version and see if we need an update

# If not, grab the latest compat library RPM or deb
# download and unpack in temporary directory, easier cleanup after installation
tmpdir=$(mktemp -d)
cd $tmpdir
compat_file=${libs_url##*/}
wget ${libs_url}

# Unpack it
# (the requirements here are OS dependent, can we get around that?)
# (for rpms looks like we can use https://gitweb.gentoo.org/repo/proj/prefix.git/tree/eclass/rpm.eclass?id=d7fc8cf65c536224bace1d22c0cd85a526490a1e)
# (deb files can be unpacked with ar and tar)
file_extension=${compat_file##*.}
if [[ ${file_extension} == "rpm" ]]; then
  rpm2cpio ${compat_file} | cpio -idmv
elif [[ ${file_extension} == "deb" ]]; then
  ar x ${compat_file}
  tar xf data.tar.*
else
  echo "File extension of cuda compat lib not supported, exiting now..." >&2
  exit 1
fi
cd $host_injections_dir
# TODO: This would prevent error messages if folder already exists, but could be problematic if only some files are missing in destination dir
mv -n ${tmpdir}/usr/local/cuda-* .
rm -r ${tmpdir}

# Add a symlink that points to the latest version
latest_cuda_dir=$(find . -maxdepth 1 -type d | grep -i cuda | sort | tail -n1)
ln -sf ${latest_cuda_dir} latest

if [ ! -e latest ] ; then
  echo "Symlink to latest cuda compat lib version is broken, exiting now..."
  exit 1
fi

# Create the space to host the libraries
host_injection_libs_dir=/cvmfs/pilot.eessi-hpc.org/host_injections/${EESSI_PILOT_VERSION}/compat/${os_family}/${eessi_cpu_family}
mkdir -p ${host_injection_libs_dir}
# Symlink in the path to the latest libraries
if [ ! -d "${host_injection_libs_dir}/lib" ]; then
  ln -s ${host_injections_dir}/latest/compat ${host_injection_libs_dir}/lib
elif [ ! "${host_injection_libs_dir}/lib" -ef "${host_injections_dir}/latest/compat" ]; then
  echo "CUDA compat libs symlink exists but points to the wrong location, please fix this..."
  echo "${host_injection_libs_dir}/lib should point to ${host_injections_dir}/latest/compat"
  exit 1
fi

# return to initial dir
cd $current_dir
