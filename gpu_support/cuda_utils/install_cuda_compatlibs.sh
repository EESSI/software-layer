#!/bin/bash

# Initialise our bash functions
TOPDIR=$(dirname $(realpath $0))
source "$TOPDIR"/../../scripts/utils.sh

# Expect to be in a prefix shell so we know all our required commands exist
check_in_prefix_shell

# Make sure the EESSI environment has been initialised
check_eessi_initialised

libs_url=$1
required_cuda_version=$2

current_dir=$PWD
host_injections_dir="/cvmfs/pilot.eessi-hpc.org/host_injections/nvidia"
host_injection_linker_dir=${EESSI_EPREFIX/versions/host_injections}

# Check if our target CUDA is satisfied by what is installed already
# (driver CUDA is reported as major.minor, i.e., like a float)
driver_cuda_version=$(nvidia-smi  -q --display=COMPUTE | grep CUDA | awk 'NF>1{print $NF}')
eessi_cuda_version=$(LD_LIBRARY_PATH=${host_injections_dir}/latest/compat/:$LD_LIBRARY_PATH nvidia-smi  -q --display=COMPUTE | grep CUDA | awk 'NF>1{print $NF}')
cuda_major_minor=${required_cuda_version%.*}

if [[ ${driver_cuda_version%.*} =~ ^[0-9]+$ ]]; then
  if float_greater_than $driver_cuda_version $eessi_cuda_version ; then
    echo_yellow "You need to update your CUDA compatibility libraries!"
  elif [[ ${eessi_cuda_version%.*} =~ ^[0-9]+$ ]]; then
    if float_greater_than $eessi_cuda_version $cuda_major_minor ; then
      echo_green "Existing CUDA compatibility libraries in EESSI should be ok!"
      exit 0
    fi
  else
    echo_yellow "Installing CUDA compatibility libraries"
  fi
fi

# Grab the latest compat library RPM or deb
# Download and unpack in temporary directory, easier cleanup after installation
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

# Create a general space for our NVIDIA compat drivers
if ! create_directory_structure $host_injections_dir ; then
  fatal_error "Cannot create/write to $host_injections_dir space, exiting now..."
fi
cd $host_injections_dir
# install the compat libs
cuda_dir=$(basename ${tmpdir}/usr/local/cuda-*)
# TODO: This would prevent error messages if folder already exists, but
#       could be problematic if only some files are missing in destination dir
rm -rf ${cuda_dir}
mv -n ${tmpdir}/usr/local/cuda-* .
rm -r ${tmpdir}

# Add a symlink that points the latest version to the version we just installed
ln -sfn ${cuda_dir} latest

if [ ! -e latest ] ; then
  fatal_error "Symlink to latest cuda compat lib version is broken, exiting now..."
fi

# Symlink in the path to the latest libraries
if [ ! -d "${host_injection_linker_dir}/lib" ]; then
  # Create the space to host the libraries for the linker
  if ! create_directory_structure ${host_injection_linker_dir} ; then
    fatal_error "Cannot create/write to ${host_injection_linker_dir} space, exiting now..."
  fi
  ln -s ${host_injections_dir}/latest/compat ${host_injection_linker_dir}/lib
elif [ ! "${host_injection_linker_dir}/lib" -ef "${host_injections_dir}/latest/compat" ]; then
  error_msg="CUDA compat libs symlink exists but points to the wrong location, please fix this...\n"
  error_msg="${error_msg}${host_injection_linker_dir}/lib should point to ${host_injections_dir}/latest/compat"
  fatal_error $error_msg
fi

# return to initial dir
cd $current_dir

echo
echo CUDA driver compatability drivers installed for CUDA version:
echo ${cuda_dir/cuda-/}
