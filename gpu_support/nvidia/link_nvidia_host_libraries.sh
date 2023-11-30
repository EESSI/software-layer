#!/bin/bash

# This script links host libraries related to GPU drivers to a location where
# they can be found by the EESSI linker

# Initialise our bash functions
TOPDIR=$(dirname $(realpath $BASH_SOURCE))
source "$TOPDIR"/../../scripts/utils.sh

# We rely on ldconfig to give us the location of the libraries on the host
command_name="ldconfig"
# We cannot use a version of ldconfig that's being shipped under CVMFS
exclude_prefix="/cvmfs"

found_paths=()
# Always attempt to use /sbin/ldconfig
if [ -x "/sbin/$command_name" ]; then
    found_paths+=("$dir/$command_name")
fi
IFS=':' read -ra path_dirs <<< "$PATH"
for dir in "${path_dirs[@]}"; do
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
    fatal_error $error
fi

# Make sure EESSI is initialised (doesn't matter what version)
check_eessi_initialised

# Find the CUDA version of the host CUDA drivers
# (making sure that this can still work inside prefix environment inside a container)
nvidia_smi_command="LD_LIBRARY_PATH=/.singularity/libs:$LD_LIBRARY_PATH nvidia-smi --query-gpu=driver_version --format=csv,noheader"
if $nvidia_smi_command; then
  host_cuda_version=$($nvidia_smi_command | tail -n1)
else
  error="Failed to successfully execute\n  $nvidia_smi_command\n"
  fatal_error $error
fi

# Let's make sure the driver libraries are not already in place
link_drivers=1

host_injections_nvidia_dir="/cvmfs/pilot.eessi-hpc.org/host_injections/${EESSI_CPU_FAMILY}/nvidia"
host_injection_driver_dir="${host_injections_nvidia_dir}/host"
host_injection_driver_version_file="$host_injection_driver_dir/version.txt"
if [ -e "$host_injection_driver_version_file" ]; then
  if grep -q "$host_cuda_version" "$host_injection_driver_version_file"; then
    echo_green "The host CUDA driver libraries have already been linked!"
    link_drivers=0
  else
    # There's something there but it is out of date
    echo_yellow "Cleaning out outdated symlinks"
    rm $host_injection_driver_dir/*
    if [ $? -ne 0 ]; then
      error="Unable to remove files under '$host_injection_driver_dir'."
      fatal_error $error
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
  curl -o "$temp_dir"/nvliblist.conf https://raw.githubusercontent.com/apptainer/apptainer/main/etc/nvliblist.conf

  # Make symlinks to all the interesting libraries
  grep '.so$' "$temp_dir"/nvliblist.conf | xargs -i grep {} libs.txt | xargs -i ln -s {}

  # Inject CUDA version into dir
  echo $host_cuda_version > version.txt
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

echo_green "Host NVIDIA gpu drivers linked successfully for EESSI"