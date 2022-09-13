#!/bin/bash

libs_url=$1

current_dir=$(dirname $(realpath $0))
host_injections_dir="/cvmfs/pilot.eessi-hpc.org/host_injections/nvidia"
host_injection_linker_dir=${EESSI_EPREFIX/versions/host_injections}

# Create a general space for our NVIDIA compat drivers
if [ -w /cvmfs/pilot.eessi-hpc.org/host_injections ]; then
  mkdir -p ${host_injections_dir}
else
  echo "Cannot write to eessi host_injections space, exiting now..." >&2
  exit 1
fi
cd ${host_injections_dir}

# Check if we have any version installed by checking for the existence of /cvmfs/pilot.eessi-hpc.org/host_injections/nvidia/latest

driver_cuda_version=$(nvidia-smi  -q --display=COMPUTE | grep CUDA | awk 'NF>1{print $NF}' | sed s/\\.//)
eessi_cuda_version=$(LD_LIBRARY_PATH=${host_injections_dir}/latest/compat/:$LD_LIBRARY_PATH nvidia-smi  -q --display=COMPUTE | grep CUDA | awk 'NF>1{print $NF}' | sed s/\\.//)
if [[ $driver_cuda_version =~ ^[0-9]+$ ]]; then
  if [ "$driver_cuda_version" -gt "$eessi_cuda_version" ]; then  echo "You need to update your CUDA compatability libraries"; fi
fi

# Check if our target CUDA is satisfied by what is installed already
# TODO: Find required CUDA version and see if we need an update

# If not, grab the latest compat library RPM or deb
# download and unpack in temporary directory, easier cleanup after installation
tmpdir=$(mktemp -d)
cd $tmpdir
compat_file=${libs_url##*/}
wget ${libs_url}
echo $compat_file

# Unpack it
# rpm files are the default for all OSes
# Keep support for deb files in case it is needed in the future
file_extension=${compat_file##*.}
if [[ ${file_extension} == "rpm" ]]; then
  # p7zip is installed under host_injections for now, make that known to the environment
  if [ -d ${cuda_install_dir}/modules/all ]; then
    module use ${cuda_install_dir}/modules/all/
  fi
  # Load p7zip to extract files from rpm file
  module load p7zip
  # Extract .cpio
  7z x ${compat_file}
  # Extract lib*
  7z x ${compat_file/rpm/cpio}
  # Restore symlinks
  cd usr/local/cuda-*/compat
  ls *.so *.so.? | xargs -i -I % sh -c '{ echo -n ln -sf" "; cat %; echo " "%; }'| xargs -i sh -c "{}"
  cd -
elif [[ ${file_extension} == "deb" ]]; then
  ar x ${compat_file}
  tar xf data.tar.*
else
  echo "File extension of cuda compat lib not supported, exiting now..." >&2
  exit 1
fi
cd $host_injections_dir
cuda_dir=$(basename ${tmpdir}/usr/local/cuda-*)
# TODO: This would prevent error messages if folder already exists, but could be problematic if only some files are missing in destination dir
rm -rf ${cuda_dir}
mv -n ${tmpdir}/usr/local/cuda-* .
rm -r ${tmpdir}

# Add a symlink that points the latest version to the version we just installed
ln -sfn ${cuda_dir} latest

if [ ! -e latest ] ; then
  echo "Symlink to latest cuda compat lib version is broken, exiting now..."
  exit 1
fi

# Create the space to host the libraries
mkdir -p ${host_injection_linker_dir}
# Symlink in the path to the latest libraries
if [ ! -d "${host_injection_linker_dir}/lib" ]; then
  ln -s ${host_injections_dir}/latest/compat ${host_injection_linker_dir}/lib
elif [ ! "${host_injection_linker_dir}/lib" -ef "${host_injections_dir}/latest/compat" ]; then
  echo "CUDA compat libs symlink exists but points to the wrong location, please fix this..."
  echo "${host_injection_linker_dir}/lib should point to ${host_injections_dir}/latest/compat"
  exit 1
fi

# return to initial dir
cd $current_dir

echo
echo CUDA driver compatability drivers installed for CUDA version:
echo ${cuda_dir/cuda-/}
