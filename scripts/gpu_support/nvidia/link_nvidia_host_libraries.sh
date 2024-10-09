#!/bin/bash

# This script links host libraries related to GPU drivers to a location where
# they can be found by the EESSI linker (or sets LD_PRELOAD as an
# alternative.)

# Initialise our bash functions
TOPDIR=$(dirname "$(realpath "$BASH_SOURCE")")
source "$TOPDIR"/../../utils.sh

# Define a function to find the host ld_config
get_host_ldconfig() {
    local command_name="ldconfig"  # Set command to find
    local exclude_prefix="/cvmfs"  # Set excluded prefix (paths to ignore)
    local found_paths=()           # Initialize an array to store found paths

    # Always attempt to use /sbin/ldconfig
    if [ -x "/sbin/$command_name" ]; then
        found_paths+=("/sbin/$command_name")
    fi

    # Split the $PATH and iterate over each directory
    IFS=':' read -ra path_dirs <<< "$PATH"
    for dir in "${path_dirs[@]}"; do
        if [ "$dir" = "/sbin" ]; then
            continue  # Skip /sbin since it's already checked
        fi

        # Check if directory does not start with the exclude prefix
        if [[ ! "$dir" =~ ^$exclude_prefix ]]; then
            if [ -x "$dir/$command_name" ]; then
                found_paths+=("$dir/$command_name")
            fi
        fi
    done

    # Check if any paths were found
    if [ ${#found_paths[@]} -gt 0 ]; then
        # echo the first version we found and return success
        echo "${found_paths[0]}"
        return 0
    else
        fatal_error "$command_name not found in PATH or only found in paths starting with $exclude_prefix."
    fi
}

get_nvlib_list() {
    local nvliblist_url="https://raw.githubusercontent.com/apptainer/apptainer/main/etc/nvliblist.conf"
    local default_nvlib_list=(
        "libcuda.so"
        "libcudadebugger.so"
        "libEGL_installertest.so"
        "libEGL_nvidia.so"
        "libEGL.so"
        "libGLdispatch.so"
        "libGLESv1_CM_nvidia.so"
        "libGLESv1_CM.so"
        "libGLESv2_nvidia.so"
        "libGLESv2.so"
        "libGL.so"
        "libGLX_installertest.so"
        "libGLX_nvidia.so"
        "libglx.so"
        "libGLX.so"
        "libnvcuvid.so"
        "libnvidia-cbl.so"
        "libnvidia-cfg.so"
        "libnvidia-compiler.so"
        "libnvidia-eglcore.so"
        "libnvidia-egl-wayland.so"
        "libnvidia-encode.so"
        "libnvidia-fatbinaryloader.so"
        "libnvidia-fbc.so"
        "libnvidia-glcore.so"
        "libnvidia-glsi.so"
        "libnvidia-glvkspirv.so"
        "libnvidia-gpucomp.so"
        "libnvidia-gtk2.so"
        "libnvidia-gtk3.so"
        "libnvidia-ifr.so"
        "libnvidia-ml.so"
        "libnvidia-nvvm.so"
        "libnvidia-opencl.so"
        "libnvidia-opticalflow.so"
        "libnvidia-ptxjitcompiler.so"
        "libnvidia-rtcore.so"
        "libnvidia-tls.so"
        "libnvidia-wfb.so"
        "libnvoptix.so"
        "libOpenCL.so"
        "libOpenGL.so"
        "libvdpau_nvidia.so"
        "nvidia_drv.so"
        "tls_test_.so"
    )

        # Check if the function was called with the "default" argument
    if [[ "$1" == "default" ]]; then
        printf "%s\n" "${default_nvlib_list[@]}"
        return 1
    fi

    # Try to download the nvliblist.conf file with curl
    nvliblist_content=$(curl --silent "$nvliblist_url")

    # Check if curl failed (i.e., the content is empty)
    if [ -z "$nvliblist_content" ]; then
        # Failed to download nvliblist.conf, using default list instead
        printf "%s\n" "${default_nvlib_list[@]}"
        return 1
    fi

    # If curl succeeded, filter and return the libraries from the downloaded content
    echo "$nvliblist_content" | grep '.so$'

    return 0
}

# Function to check if umask allows global read
check_global_read() {
    # Get the current umask value
    local current_umask=$(umask)

    # Convert umask to decimal to analyze
    local umask_octal=$(printf '%03o\n' "$current_umask")

    # Check if umask allows global read
    if [ "$umask_octal" -gt 022 ]; then
        fatal_error "The current umask ($current_umask) does not allow global read permissions, you'll want everyone to be able to read the created directory."
    fi
}

# Make sure EESSI is initialised (doesn't matter what version)
check_eessi_initialised

# Check for required commands
command -v nvidia-smi >/dev/null 2>&1 || { echo_yellow "nvidia-smi not found, this script won't do anything useful"; return 1; }

# Variables
LD_PRELOAD_MODE=0
LIBS_LIST=""

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --ld-preload) LD_PRELOAD_MODE=1 ;;  # Enable LD_PRELOAD mode
    --no-download) LIBS_LIST="default" ;;  # Download latest list of CUDA libraries
    *) fatal_error "Unknown option: $1";;
  esac
  shift
done

# Gather information about NVIDIA drivers (even if we are inside a Gentoo Prefix in a container)
export LD_LIBRARY_PATH=/.singularity.d/libs:$LD_LIBRARY_PATH

# Check for NVIDIA GPUs via nvidia-smi command
nvidia_smi=$(command -v nvidia-smi)
if [[ $? -eq 0 ]]; then
    nvidia_smi_out=$(mktemp -p /tmp nvidia_smi_out.XXXXX)
    nvidia-smi --query-gpu=gpu_name,count,driver_version,compute_cap --format=csv,noheader 2>&1 > $nvidia_smi_out
    if [[ $? -eq 0 ]]; then
        nvidia_smi_info=$(head -1 $nvidia_smi_out)
        host_cuda_version=$(echo $nvidia_smi_info | sed 's/, /,/g' | cut -f4 -d,)
        host_driver_version=$(echo $nvidia_smi_info | sed 's/, /,/g' | cut -f3 -d,)
        echo_green "Found host CUDA version ${host_cuda_version}"
        echo_green "Found NVIDIA GPU driver version ${host_driver_version}"
        rm -f $nvidia_smi_out
    else
        fatal_error "nvidia-smi command failed, see output in $nvidia_smi_out"
    fi
else
    fatal_error "nvidia-smi command not found"
    exit 2
fi

# Gather any CUDA related driver libraries from the host
# - First let's see what driver libraries are there
# - then extract the ones we need for CUDA

# Find the host ldconfig
host_ldconfig=$(get_host_ldconfig)
# Gather libraries on the host (_must_ be host ldconfig)
host_libraries=$($host_ldconfig -p | awk '{print $NF}')
singularity_libs=$(ls /.singularity.d/libs/* 2>/dev/null)

# Now gather the list of possible CUDA libraries and make them into an array
cuda_candidate_libraries=($(get_nvlib_list "${LIBS_LIST}"))
# Check if the function returned an error (e.g., curl failed)
if [ $? -ne 0 ]; then
    echo "Using default list of libraries"
else
    echo "Using downloaded list of libraries"
fi

# Filter the host libraries to find the CUDA libaries locations
# Initialize an array to hold the matched libraries
matched_libraries=()

# Process each library and check for matches in libs.txt
for library in "${cuda_candidate_libraries[@]}"; do
    # Search for the library in libs.txt and add it to the matched_libraries array
    matched=$(echo "$host_libraries $singularity_libs" | grep "$library")
    if [ -n "$matched" ]; then
        matched_libraries+=( $matched )  # Add matched library to the array
    fi
done

# Output the number of matched libraries
echo "Matched ${#matched_libraries[@]} CUDA Libraries"

# LD_PRELOAD Mode
if [ "$LD_PRELOAD_MODE" -eq 1 ]; then
    echo
    echo_yellow "When attempting to use LD_PRELOAD we exclude anything related to graphics"

    # Filter out all symlinks and libraries that have missing library dependencies under EESSI
    filtered_libraries=()
    for library in "${matched_libraries[@]}"; do
        # Run ldd on the given binary and filter for "not found" libraries
        NOT_FOUND_LIBS=$(ldd "$library" 2>/dev/null | grep "not found" | awk '{print $1}')
        # Check if it is missing an so dep under EESSI
        if [[ -z "$NOT_FOUND_LIBS" ]]; then
            # Anything graphics is out, as is libnvidia-fbc*
            if [[ "$library" != *"GL"* ]]; then
                if [[ "$library" != *"libnvidia-fbc"* ]]; then
                    # Resolve any symlink
                    library=$(realpath "$library")
                    if [[ ! " ${filtered_libraries[@]} " =~ " $library " ]]; then
                        filtered_libraries+=("$library")
                    fi
                fi
            fi
        else
            # Iterate over "not found" libraries and check if they are in the array
            all_found=true
            for lib in $NOT_FOUND_LIBS; do
                found=false
                for listed_lib in "${matched_libraries[@]}"; do
                    # Matching to the .so is enough
                    if [[ "$lib" == "$listed_lib"* ]]; then
                        found=true
                        break
                    fi
                done

                if [[ "$found" == false ]]; then
                    echo "$lib is NOT in the provided preload list, filtering $library"
                    all_found=false
                    break
                fi
            done

            # If we find all the missing libs in our list include it
            if [[ "$all_found" == true ]]; then
                # Anything graphics is out, as is libnvidia-fbc*
                if [[ "$library" != *"GL"* ]]; then
                    if [[ "$library" != *"libnvidia-fbc"* ]]; then
                        # Resolve any symlink
                        library=$(realpath "$library")
                        if [[ ! " ${filtered_libraries[@]} " =~ " $library " ]]; then
                            filtered_libraries+=("$library")
                        fi
                    fi
                fi
            fi
        fi
    done

    # Set EESSI_GPU_LD_PRELOAD with the matched libraries
    if [ ${#filtered_libraries[@]} -gt 0 ]; then
      echo
      echo_yellow "The recommended way to use LD_PRELOAD is to only use it when you need to:"
      echo
      EESSI_GPU_LD_PRELOAD=$(printf "%s\n" "${filtered_libraries[@]}" | tr '\n' ':')
      # Remove the trailing colon from LD_PRELOAD if it exists
      EESSI_GPU_LD_PRELOAD=${EESSI_GPU_LD_PRELOAD%:}
      export EESSI_GPU_LD_PRELOAD
      echo_green "export EESSI_GPU_LD_PRELOAD=\"$EESSI_GPU_LD_PRELOAD\""
      export EESSI_OVERRIDE_GPU_CHECK=1
      echo_green "export EESSI_OVERRIDE_GPU_CHECK=\"$EESSI_OVERRIDE_GPU_CHECK\""
      echo
      echo_yellow "Then you can set LD_PRELOAD only when you want to run a GPU application, e.g.,"
      echo_yellow "    LD_PRELOAD=\"\$EESSI_GPU_LD_PRELOAD\" device_query"
    else
      echo "No libraries matched, LD_PRELOAD not set."
    fi
    [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return 1 || exit 1
fi

# If we haven't already exited, we may need to create the symlinks

# First let's make sure the driver libraries are not already in place
link_drivers=1

# Make sure that target of host_injections variant symlink is an existing directory
host_injections_target=$(realpath -m "${EESSI_CVMFS_REPO}/host_injections")
if [ ! -d "$host_injections_target" ]; then
    check_global_read
    create_directory_structure "$host_injections_target"
fi

host_injections_nvidia_dir="${EESSI_CVMFS_REPO}/host_injections/nvidia/${EESSI_CPU_FAMILY}"
host_injection_driver_dir="${host_injections_nvidia_dir}/host"
host_injection_driver_version_file="${host_injection_driver_dir}/driver_version.txt"
if [ -e "$host_injection_driver_version_file" ]; then
  if grep -q "$host_driver_version" "$host_injection_driver_version_file"; then
    echo_green "The host GPU driver libraries (v${host_driver_version}) have already been linked! (based on ${host_injection_driver_version_file})"
    link_drivers=0
  else
    # There's something there but it is out of date
    echo_yellow "Cleaning out outdated symlinks"
    rm "${host_injection_driver_dir}"/* || fatal_error "Unable to remove files under '${host_injection_driver_dir}'."
  fi
fi

drivers_linked=0
if [ "$link_drivers" -eq 1 ]; then
  check_global_read
  if ! create_directory_structure "${host_injection_driver_dir}" ; then
    fatal_error "No write permissions to directory ${host_injection_driver_dir}"
  fi
  cd "${host_injection_driver_dir}" || fatal_error "Failed to cd to ${host_injection_driver_dir}"

  # Make symlinks to all the interesting libraries
  # Loop over each matched library
  for library in "${matched_libraries[@]}"; do
      # Create a symlink in the current directory
      ln -s "$library" .
      # Check if the symlink was created successfully
      if [ $? -ne 0 ]; then
          fatal_error "Error: Failed to create symlink for library $library in $PWD"
      fi
  done

  # Inject driver and CUDA versions into the directory
  echo "$host_driver_version" > driver_version.txt
  echo "$host_cuda_version" > cuda_version.txt
  drivers_linked=1
fi

# Make latest symlink for NVIDIA drivers
cd "$host_injections_nvidia_dir" || fatal_error "Failed to cd to $host_injections_nvidia_dir"
symlink="latest"
if [ -L "$symlink" ]; then
    if [ "$drivers_linked" -eq 1 ]; then
        ln -sf host "$symlink"
        if [ $? -eq 0 ]; then
            echo "Successfully created symlink between $symlink and host in $PWD"
        else
            fatal_error "Failed to create symlink between $symlink and host in $PWD"
        fi
    fi
else
    ln -s host "$symlink"
    if [ $? -eq 0 ]; then
        echo "Successfully created symlink between $symlink and host in $PWD"
    else
        fatal_error "Failed to create symlink between $symlink and host in $PWD"
    fi
fi

# Make sure the libraries can be found by the EESSI linker
host_injection_linker_dir=${EESSI_EPREFIX/versions/host_injections}
if [ -L "$host_injection_linker_dir/lib" ]; then
  target_path=$(readlink -f "$host_injection_linker_dir/lib")
  if [ "$target_path" != "$host_injections_nvidia_dir/latest" ]; then
    cd "$host_injection_linker_dir" || fatal_error "Failed to cd to $host_injection_linker_dir"
    ln -sf "$host_injections_nvidia_dir/latest" lib
    if [ $? -eq 0 ]; then
        echo "Successfully created symlink between $host_injections_nvidia_dir/latest and lib in $PWD"
    else
        fatal_error "Failed to create symlink between $host_injections_nvidia_dir/latest and lib in $PWD"
    fi
  fi
else
  check_global_read
  create_directory_structure "$host_injection_linker_dir"
  cd "$host_injection_linker_dir" || fatal_error "Failed to cd to $host_injection_linker_dir"
  ln -s "$host_injections_nvidia_dir/latest" lib
  if [ $? -eq 0 ]; then
      echo "Successfully created symlink between $host_injections_nvidia_dir/latest and lib in $PWD"
  else
      fatal_error "Failed to create symlink between $host_injections_nvidia_dir/latest and lib in $PWD"
  fi
fi

echo_green "Host NVIDIA GPU drivers linked successfully for EESSI"
