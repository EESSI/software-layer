#!/bin/bash

# This script links host libraries related to GPU drivers to a location where
# they can be found by the EESSI linker

# Initialise our bash functions
TOPDIR=$(dirname $(realpath $BASH_SOURCE))
source "$TOPDIR"/../../utils.sh

# We rely on ldconfig to give us the location of the libraries on the host
command_name="ldconfig"
# We cannot use a version of ldconfig that's being shipped under CVMFS
exclude_prefix="/cvmfs"

found_paths=()
# Always attempt to use /sbin/ldconfig
if [ -x "/sbin/$command_name" ]; then
    found_paths+=("/sbin/$command_name")
fi
IFS=':' read -ra path_dirs <<< "$PATH"
for dir in "${path_dirs[@]}"; do
  if [ "$dir" = "/sbin" ]; then
    continue  # we've already checked for $command_name in /sbin, don't need to do it twice
  fi
  if [[ ! "$dir" =~ ^$exclude_prefix ]]; then
      if [ -x "$dir/$command_name" ]; then
          found_paths+=("$dir/$command_name")
      fi
  fi
done

if [ ${#found_paths[@]} -gt 0 ]; then
    echo "Found $command_name in the following locations:"
    printf -- "- %s\n" "${found_paths[@]}"
    echo "Using first version"
    host_ldconfig=${found_paths[0]}
else
    error="$command_name not found in PATH or only found in paths starting with $exclude_prefix."
    fatal_error "$error"
fi

# Make sure EESSI is initialised (doesn't matter what version)
check_eessi_initialised

# Find the CUDA version of the host CUDA drivers
# (making sure that this can still work inside prefix environment inside a container)
export LD_LIBRARY_PATH=/.singularity.d/libs:$LD_LIBRARY_PATH
nvidia_smi_command="nvidia-smi --query-gpu=driver_version --format=csv,noheader"
if $nvidia_smi_command > /dev/null; then
  host_driver_version=$($nvidia_smi_command | tail -n1)
  echo_green "Found NVIDIA GPU driver version ${host_driver_version}"
  # If the first worked, this should work too
  host_cuda_version=$(nvidia-smi  -q --display=COMPUTE | grep CUDA | awk 'NF>1{print $NF}')
  echo_green "Found host CUDA version ${host_cuda_version}"
else
  error="Failed to successfully execute\n  $nvidia_smi_command\n"
  fatal_error "$error"
fi

# Let's make sure the driver libraries are not already in place
link_drivers=1

# first make sure that target of host_injections variant symlink is an existing directory
host_injections_target=$(realpath -m ${EESSI_CVMFS_REPO}/host_injections)
if [ ! -d ${host_injections_target} ]; then
    create_directory_structure ${host_injections_target}
fi

host_injections_nvidia_dir="${EESSI_CVMFS_REPO}/host_injections/nvidia/${EESSI_CPU_FAMILY}"
host_injection_driver_dir="${host_injections_nvidia_dir}/host"
host_injection_driver_version_file="$host_injection_driver_dir/driver_version.txt"
if [ -e "$host_injection_driver_version_file" ]; then
  if grep -q "$host_driver_version" "$host_injection_driver_version_file"; then
    echo_green "The host GPU driver libraries (v${host_driver_version}) have already been linked! (based on ${host_injection_driver_version_file})"
    link_drivers=0
  else
    # There's something there but it is out of date
    echo_yellow "Cleaning out outdated symlinks"
    rm $host_injection_driver_dir/*
    if [ $? -ne 0 ]; then
      error="Unable to remove files under '$host_injection_driver_dir'."
      fatal_error "$error"
    fi
  fi
fi

drivers_linked=0
if [ "$link_drivers" -eq 1 ]; then
  if ! create_directory_structure "${host_injection_driver_dir}" ; then
    fatal_error "No write permissions to directory ${host_injection_driver_dir}"
  fi
  cd ${host_injection_driver_dir}
  # Need a small temporary space to hold a couple of files
  temp_dir=$(mktemp -d)

  # Gather libraries on the host (_must_ be host ldconfig)
  $host_ldconfig -p | awk '{print $NF}' > "$temp_dir"/libs.txt
  # Allow for the fact that we may be in a container so the CUDA libs might be in there
  ls /.singularity.d/libs/* >> "$temp_dir"/libs.txt 2>/dev/null

  # Leverage singularity to find the full list of libraries we should be linking to
  echo_yellow "Downloading latest version of nvliblist.conf from Apptainer to ${temp_dir}/nvliblist.conf"
  curl --silent --output "$temp_dir"/nvliblist.conf https://raw.githubusercontent.com/apptainer/apptainer/main/etc/nvliblist.conf

  # Make symlinks to all the interesting libraries
  grep '.so$' "$temp_dir"/nvliblist.conf | xargs -i grep {} "$temp_dir"/libs.txt | xargs -i ln -s {}

  # Inject driver and CUDA versions into dir
  echo $host_driver_version > driver_version.txt
  echo $host_cuda_version > cuda_version.txt
  drivers_linked=1

  # Remove the temporary directory when done
  rm -r "$temp_dir"
fi

# Make latest symlink for NVIDIA drivers
cd $host_injections_nvidia_dir
symlink="latest"
if [ -L "$symlink" ]; then
    # Unless the drivers have been installed, leave the symlink alone
    if [ "$drivers_linked" -eq 1 ]; then
      ln -sf host latest
    fi
else
    # No link exists yet
    ln -s host latest
fi

# Make sure the libraries can be found by the EESSI linker
host_injection_linker_dir=${EESSI_EPREFIX/versions/host_injections}
if [ -L "$host_injection_linker_dir/lib" ]; then
  target_path=$(readlink -f "$host_injection_linker_dir/lib")
  if [ "$target_path" != "$$host_injections_nvidia_dir/latest" ]; then
    cd $host_injection_linker_dir
    ln -sf $host_injections_nvidia_dir/latest lib
  fi
else
  create_directory_structure $host_injection_linker_dir
  cd $host_injection_linker_dir
  ln -s $host_injections_nvidia_dir/latest lib
fi

echo_green "Host NVIDIA GPU drivers linked successfully for EESSI"
