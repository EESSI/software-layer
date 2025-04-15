#!/bin/bash

# NVIDIA Host Libraries Linking Script for EESSI
# ============================================
# Overview:
# 1. Initialize environment and source utility functions
#    All function definitions be here.
# 2. Check prerequisites:
#    - EESSI environment initialization
#    - nvidia-smi availability
#    - Proper umask settings for global read permissions
# 3. Gather NVIDIA information:
#    - Detect GPU driver version
#    - Get CUDA version
# 4. Library detection and matching:
#    - Download/use default NVIDIA library list
#    - Find host libraries using ldconfig
#    - Match required NVIDIA libraries
# 5. Handle two operation modes:
#    a) Show LD_PRELOAD mode: Displays environment variables for preloading
#       Suggest exports for following variables:
#           EESSI_GPU_COMPAT_LD_PRELOAD (Minimal LD_PRELOAD)
#           EESSI_GPU_LD_PRELOAD (Full LD_PRELOAD)
#           EESSI_OVERRIDE_GPU_CHECK
#    b) Symlink mode: Create directory structure and link libraries
#       Create necessary symlinks in EESSI directory structure
#
# Error Handling:
# - nvidia-smi detection: Exits if NVIDIA drivers not found
# - Library matching: Reports missing libraries
# - Permission issues: Checks write access and umask settings
# - Symlink conflicts: Validates existing symlinks
# - Directory creation: Ensures proper structure exists
#
# Note: This script is part of EESSI (European Environment for Scientific 
# Software Installations) and manages the linking of host NVIDIA libraries
# to make them accessible within the EESSI environment.

# ###################################################### #
# 1. Initialize environment and source utility functions #
# ###################################################### #

TOPDIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
source "$TOPDIR"/../../utils.sh

# Command line help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --help                           Display this help message"
    echo "  --show-ld-preload                Enable recommendations for LD_PRELOAD mode"
    echo "  --no-download                    Don't download list of Nvidia libraries from URL,"
    echo "                                   but use hardcoded list here in get_nvlib_list()"
    echo "  -v, --verbose                    Display debugging messages,"
    echo "                                   actions taken, commands being run."
}

# Initialize global variables (These are accessed or set from functions)
LD_PRELOAD_MODE=0  # Trigger show-ld-preload mode T/F
LIBS_LIST=""  # Command line argument for get_nvlib_list
VERBOSE=0  # Set verbosity logging T/F
HOST_GPU_DRIVER_VERSION=""  # GPU Driver version ()
HOST_GPU_CUDA_VERSION=""  # GPU CUDA version ()
MATCHED_LIBRARIES=()  # List of found CUDA libraries based on get_nvlib_list()
MISSING_LIBRARIES=()  # Complementary to Matched libraries.


# Locates the host system's ldconfig, avoiding CVMFS paths
# Returns path to first valid ldconfig found, prioritizing /sbin
get_host_ldconfig() {
    local command_name="ldconfig"  # Set command to find
    local exclude_prefix="/cvmfs"  # Set excluded prefix (paths to ignore)
    local found_paths=()           # Initialize an array to store found paths

    # Always attempt to use /sbin/ldconfig
    if [ -x "/sbin/${command_name}" ]; then
        found_paths+=("/sbin/${command_name}")
    fi

    # Split the $PATH and iterate over each directory
    IFS=':' read -ra path_dirs <<< "$PATH"
    for dir in "${path_dirs[@]}"; do
        if [ "$dir" = "/sbin" ]; then
            continue  # Skip /sbin since it's already checked
        fi

        # Check if directory does not start with the exclude prefix
        if [[ ! "$dir" =~ ^$exclude_prefix ]]; then
            if [ -x "${dir}/${command_name}" ]; then
                found_paths+=("${dir}/${command_name}")
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

# Downloads or provides default list of required NVIDIA libraries.
# As echo to stdout! Don't print any messages inside this function.
# Returns 0 if download successful, 1 if using default list
get_nvlib_list() {
    local nvliblist_url="https://raw.githubusercontent.com/apptainer/apptainer/main/etc/nvliblist.conf"

    # see https://apptainer.org/docs/admin/1.0/configfiles.html#nvidia-gpus-cuda
    # https://github.com/apptainer/apptainer/commits/main/etc/nvliblist.conf
    # This default_nvlib_list is based on this commit on Oct 1, 2024:
    # https://github.com/apptainer/apptainer/commit/a19fa01527a8914839b8d1649688f83c61ba9ad2
    # TODO: driver version which corresponds to?
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
        # We can't echo here
        # echo_yellow "Download failed, using default list of libraries instead"
        printf "%s\n" "${default_nvlib_list[@]}"
        return 1
    fi

    # If curl succeeded, filter and return the libraries from the downloaded content
    echo "$nvliblist_content" | grep '.so$'
    
    # We can't echo here
    # echo "Using downloaded list of libraries"
    return 0
}

# Verifies if current umask allows global read access
# Exits with error if permissions are too restrictive
check_global_read() {
    # Get the current umask value
    local current_umask
    current_umask=$(umask)
    log_verbose "current umask: ${current_umask}"

    # Convert umask to decimal to analyze
    local umask_octal
    umask_octal=$(printf '%03o\n' "$current_umask")

    # Check if umask allows global read
    if [ "$umask_octal" -gt 022 ]; then
        fatal_error "The current umask ($current_umask) does not allow global read permissions, you'll want everyone to be able to read the created directory."
    fi
    # TODO: Option to set $UMASK here?
    # https://github.com/EESSI/software-layer/pull/754#discussion_r1950643598
}

# Checks for nvidia-smi command and extracts GPU information
# Sets HOST_GPU_CUDA_VERSION and HOST_GPU_DRIVER_VERSION variables
check_nvidia_smi_info() {
    
    if command -v nvidia-smi
    then
        log_verbose "Found nvidia-smi at: $(which nvidia-smi)"
        
        # Create temporary file for nvidia-smi output
        nvidia_smi_out=$(mktemp -p /tmp nvidia_smi_out.XXXXX)
        log_verbose "Creating temporary output file: ${nvidia_smi_out}"
        
        # Query GPU information and parse versions
        
        if nvidia-smi --query-gpu=gpu_name,count,driver_version,compute_cap --format=csv,noheader > "$nvidia_smi_out" 2>&1
        then
            nvidia_smi_info=$(head -1 "${nvidia_smi_out}")
            HOST_GPU_CUDA_VERSION=$(echo "${nvidia_smi_info}" | sed 's/, /,/g' | cut -f4 -d,)
            HOST_GPU_DRIVER_VERSION=$(echo "${nvidia_smi_info}" | sed 's/, /,/g' | cut -f3 -d,)
            echo_green "Found host CUDA version ${HOST_GPU_CUDA_VERSION}"
            echo_green "Found NVIDIA GPU driver version ${HOST_GPU_DRIVER_VERSION}"
            rm -f "$nvidia_smi_out"
        else
            fatal_error "nvidia-smi command failed, see output in $nvidia_smi_out. Please remove the file afterwards."
        fi
    else
        fatal_error "nvidia-smi command not found"
        exit 2
    fi
}

# Suggests configurations for LD_PRELOAD environment for CUDA libraries
# Filters libraries and configures both minimal and full preload options
show_ld_preload() {
    
    echo
    echo_yellow "When attempting to use LD_PRELOAD we exclude anything related to graphics"

    # Define core CUDA libraries needed for compute
    cuda_compat_nvlib_list=(
        "libcuda.so"
        "libcudadebugger.so"
        "libnvidia-nvvm.so"
        "libnvidia-ptxjitcompiler.so"
    )

    # Filter out all symlinks and libraries that have missing library dependencies under EESSI
    filtered_libraries=()
    compat_filtered_libraries=()
    
    for library in "${MATCHED_LIBRARIES[@]}"; do

        # Run ldd on the given binary and filter for "not found" libraries
        # not_found_libs=$(ldd "${library}" 2>/dev/null | grep "not found" | awk '{print $1}')
        # Trim multiple spaces then use cut
        not_found_libs=$(ldd "${library}" 2>/dev/null | grep "not found" | tr -s ' ' | cut -d' ' -f1)
        # Check if it is missing an so dep under EESSI
        if [[ -z "$not_found_libs" ]]; then
            # Resolve any symlink
            realpath_library=$(realpath "$library")
            if [[ ! " ${filtered_libraries[@]} " =~ " $realpath_library " ]]; then
                filtered_libraries+=("${realpath_library}")
                # Also prepare compat only libraries for the short list
                for item in "${cuda_compat_nvlib_list[@]}"; do
                    # Check if the current item is a substring of $library
                    if [[ "$realpath_library" == *"$item"* ]]; then
                        echo "Match found for $item for CUDA compat libraries"
                        if [[ ! " ${compat_filtered_libraries[@]} " =~ " $realpath_library " ]]; then
                            compat_filtered_libraries+=("$realpath_library")
                        fi
                        break
                    fi
                done
           fi
        else
            # Iterate over "not found" libraries and check if they are in the array
            all_found=true
            for lib in $not_found_libs; do
                found=false
                for listed_lib in "${MATCHED_LIBRARIES[@]}"; do
                    # Matching to the .so or a symlink target is enough
                    realpath_lib=$(realpath "${listed_lib}")
                    if [[ "$lib" == "$listed_lib"* || "$realpath_lib" == *"$lib" ]]; then
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
                # Resolve any symlink
                realpath_library=$(realpath "${library}")
                if [[ ! " ${filtered_libraries[@]} " =~ " $realpath_library " ]]; then
                    filtered_libraries+=("${realpath_library}")
                    # Also prepare compat only libraries for the short list
                    for item in "${cuda_compat_nvlib_list[@]}"; do
                        # Check if the current item is a substring of $library
                        if [[ "$realpath_library" == *"$item"* ]]; then
                            echo "Match found for $item for CUDA compat libraries"
                            if [[ ! " ${compat_filtered_libraries[@]} " =~ " $realpath_library " ]]; then
                                compat_filtered_libraries+=("${realpath_library}")
                            fi
                            break
                        fi
                    done
                fi
            fi
        fi
    done

    # Set EESSI_GPU_LD_PRELOAD with the matched libraries
    if [ ${#filtered_libraries[@]} -gt 0 ]; then
        echo
        echo_yellow "The recommended way to use LD_PRELOAD is to only use it when you need to."
        echo

        # Set up MINIMAL preload for common cases
        EESSI_GPU_COMPAT_LD_PRELOAD=$(printf "%s\n" "${compat_filtered_libraries[@]}" | tr '\n' ':')
        # Remove the trailing colon from LD_PRELOAD if it exists
        EESSI_GPU_COMPAT_LD_PRELOAD=${EESSI_GPU_COMPAT_LD_PRELOAD%:}
        export EESSI_GPU_COMPAT_LD_PRELOAD
        
        echo_yellow "A minimal preload which should work in most cases:"
        echo_green "export EESSI_GPU_COMPAT_LD_PRELOAD=\"$EESSI_GPU_COMPAT_LD_PRELOAD\""
        echo

        # Set up FULL preload for corner cases
        EESSI_GPU_LD_PRELOAD=$(printf "%s\n" "${filtered_libraries[@]}" | tr '\n' ':')
        # Remove the trailing colon from LD_PRELOAD if it exists
        EESSI_GPU_LD_PRELOAD=${EESSI_GPU_LD_PRELOAD%:}
        export EESSI_GPU_LD_PRELOAD
        export EESSI_OVERRIDE_GPU_CHECK=1

        echo_yellow "A corner-case full preload (which is hard on memory) for exceptional use:"

        # Display usage instructions
        echo_green "export EESSI_GPU_LD_PRELOAD=\"$EESSI_GPU_LD_PRELOAD\""
        echo_green "export EESSI_OVERRIDE_GPU_CHECK=\"$EESSI_OVERRIDE_GPU_CHECK\""
        echo
        echo_yellow "Then you can set LD_PRELOAD only when you want to run a GPU application,"
        echo_yellow "e.g. deviceQuery command from CUDA-Samples module:"
        echo_yellow "    LD_PRELOAD=\"\$EESSI_GPU_COMPAT_LD_PRELOAD\" deviceQuery"
        echo_yellow "or  LD_PRELOAD=\"\$EESSI_GPU_LD_PRELOAD\" deviceQuery"
    else
        echo "No libraries matched, LD_PRELOAD not set."
    fi
    [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return 1
}

# Check host's ldconfig, gathers library paths, and filters them on matching.
# Sets MATCHED_LIBRARIES and MISSING_LIBRARIES
find_cuda_libraries_on_host() {
    # First let's see what driver libraries are there
    # then extract the ones we need for CUDA

    # Find the host ldconfig
    host_ldconfig=$(get_host_ldconfig)
    log_verbose "Found host ldconfig: ${host_ldconfig}"

    # Gather all libraries on the host (_must_ be host ldconfig).
    # host_libraries=$("${host_ldconfig}" -p | awk '{print $NF}')
    # Trim multiple spaces then use cut
    host_libraries=$("${host_ldconfig}" -p | tr -s ' ' | cut -d' ' -f4)
    # This is only for the scenario where the script is being run inside a container, if it fails the list is empty.
    singularity_libs=$(ls /.singularity.d/libs/* 2>/dev/null)

    # Now gather the list of possible CUDA libraries and make them into an array
    # https://www.shellcheck.net/wiki/SC2207
    cuda_candidate_libraries=($(get_nvlib_list "${LIBS_LIST}"))
    # Check if the function returned an error (e.g., curl failed)
    # Echo here, we take stdout from function as list of libraries.
    if [ $? -ne 0 ]; then
        echo "Using default list of libraries"
    else
        echo "Using downloaded list of libraries"
    fi

    # Search for CUDA Libraries in system paths
    echo "Searching for CUDA Libraries"
    for library in "${cuda_candidate_libraries[@]}"; do

        # Match libraries for current CPU architecture
        # "contains" matching - (eg. 'libcuda.so' matches both 'libcuda.so' and 'libcuda.so.1')
        # The `grep -v "i386"` is done to exclude i386 libraries, which could be installed in parallel with 64 libs.
        matched=$(echo "$host_libraries $singularity_libs" | grep -v "i386" | grep "$library")

        if [ -n "$matched" ]; then
            log_verbose "Found matches for ${library}: $matched"
            
            # Process each matched library and avoid duplicates by filename
            # Used `while - read <<< $matched`` to handle whitespaces and special characters.
            while IFS= read -r lib_path; do
                # Skip empty lines
                [ -z "$lib_path" ] && continue
                
                # Extract just the filename from the path
                lib_name=$(basename "$lib_path")
                echo "Checking library $lib_name for duplicates"
                
                # Check if we already have this library filename in our matched libraries
                duplicate_found=0
                for existing_lib in "${MATCHED_LIBRARIES[@]}"; do
                    existing_name=$(basename "$existing_lib")
                    if [ "$existing_name" = "$lib_name" ]; then
                        log_verbose "Duplicate library found: $lib_name (existing: $existing_lib, currently processed: $lib_path)"
                        log_verbose "Discarting $lib_path"
                        duplicate_found=1
                        break
                    fi
                done
                
                # If no duplicate found, add this library
                if [ "$duplicate_found" -eq 0 ]; then
                    MATCHED_LIBRARIES+=("$lib_path")
                fi
            done <<< "$matched"
        else
            # There are some libraries, that weren't matched/found on the system
            log_verbose "No matches found for ${library}"
            MISSING_LIBRARIES+=("$library")
        fi
    done


    # Report matching results
    echo_green "Matched ${#MATCHED_LIBRARIES[@]} CUDA Libraries"

    if [ ${#MISSING_LIBRARIES[@]} -gt 0 ]; then
        echo_yellow "The following libraries were not found (based on 'get_nvlib_list')"
        printf '%s\n' "${MISSING_LIBRARIES[@]}"
    fi
}

# Actually symlinks the Matched libraries to correct folders.
# Then also creates "host" and "latest" folder symlinks
symlink_mode () {
    # First let's make sure the driver libraries are not already in place
    # Have to link drivers = True
    link_drivers=1

    # Make sure that target of host_injections variant symlink is an existing directory
    echo "Ensure host_injections directory"
    host_injections_target=$(realpath -m "${EESSI_CVMFS_REPO}/host_injections")
    log_verbose "host_injections_target: ${host_injections_target}"
    if [ ! -d "$host_injections_target" ]; then
        check_global_read
        create_directory_structure "$host_injections_target"
    fi

    # Define proper nvidia directory structure for host_injections in EESSI
    host_injections_nvidia_dir="${EESSI_CVMFS_REPO}/host_injections/nvidia/${EESSI_CPU_FAMILY}"
    host_injection_driver_dir="${host_injections_nvidia_dir}/host"
    host_injection_driver_version_file="${host_injection_driver_dir}/driver_version.txt"
    log_verbose "host_injections_nvidia_dir: ${host_injections_nvidia_dir}"
    log_verbose "host_injection_driver_dir: ${host_injection_driver_dir}"
    log_verbose "host_injection_driver_version_file: ${host_injection_driver_version_file}"

    # Check if drivers are already linked with correct version
    # This is done by comparing host_injection_driver_version_file (driver_version.txt)
    # This is needed when updating GPU drivers.
    if [ -e "$host_injection_driver_version_file" ]; then
        if grep -q "$HOST_GPU_DRIVER_VERSION" "$host_injection_driver_version_file"; then
            echo_green "The host GPU driver libraries (v${HOST_GPU_DRIVER_VERSION}) have already been linked! (based on ${host_injection_driver_version_file})"
            # The GPU libraries were already linked for this version of CUDA driver
            # Have to link drivers = False
            link_drivers=0
        else
            # There's something there but it is out of date
            echo_yellow "The host GPU driver libraries version have changed. Now its: (v${HOST_GPU_DRIVER_VERSION})"
            echo_yellow "Cleaning out outdated symlinks."
            rm "${host_injection_driver_dir}"/* || fatal_error "Unable to remove files under '${host_injection_driver_dir}'."
        fi
    fi

    # Link all matched_libraries from Nvidia to correct host_injection folder
    # This step is only run, when linking of drivers is needed (eg. link_drivers==1)
    # Setup variable to track if some drivers were actually linked this run.  
    drivers_linked=0

    # Have to link drivers
    if [ "$link_drivers" -eq 1 ]; then
        # Link the matched libraries
        
        echo_green "Linking drivers to the host_injection folder"
        check_global_read
        if ! create_directory_structure "${host_injection_driver_dir}" ; then
            fatal_error "No write permissions to directory ${host_injection_driver_dir}"
        fi

        cd "${host_injection_driver_dir}" || fatal_error "Failed to cd to ${host_injection_driver_dir}"
        log_verbose "Changed directory to: $PWD"

        # Make symlinks to all the interesting libraries
        # Loop over each matched library
        for library in "${MATCHED_LIBRARIES[@]}"; do
            log_verbose "Linking library: ${library}"
            
            # Get just the library filename
            lib_name=$(basename "$library")
            
            # Check if the symlink already exists
            if [ -L "$lib_name" ]; then
                # Check if it's pointing to the same target
                target=$(readlink "$lib_name")
                if [ "$target" = "$library" ]; then
                    log_verbose "Symlink for $lib_name already exists and points to correct target"
                    continue
                else
                    log_verbose "Symlink for $lib_name exists but points to wrong target: $target, updating..."
                    rm "$lib_name"
                fi
            fi
    
            # Create a symlink in the current directory
            # and check if the symlink was created successfully
            if ! ln -s "$library" .
            then
                fatal_error "Error: Failed to create symlink for library $library in $PWD"
            fi
        done

        # Inject driver and CUDA versions into the directory
        echo "$HOST_GPU_DRIVER_VERSION" > driver_version.txt
        echo "$HOST_GPU_CUDA_VERSION" > cuda_version.txt

        drivers_linked=1
    fi

    # Make latest symlink for NVIDIA drivers
    cd "$host_injections_nvidia_dir" || fatal_error "Failed to cd to $host_injections_nvidia_dir"
    log_verbose "Changed directory to: $PWD"
    symlink="latest"

    # Check if the symlink exists
    if [ -L "$symlink" ]; then
        # If the drivers were linked this run - relink the symlink!
        if [ "$drivers_linked" -eq 1 ]; then
            # Force relinking the current link.
            # Need to remove the link first, otherwise this will follow existing symlink 
            # and create host directory one level down !
            rm "$symlink" || fatal_error "Failed to remove symlink ${symlink}"
            
            if ln -sf host "$symlink"
            then
                echo "Successfully force recreated symlink between $symlink and host in $PWD"
            else
                fatal_error "Failed to force recreate symlink between $symlink and host in $PWD"
            fi
        fi
    else
        # If the symlink doesn't exists, create normal one.
        if ln -s host "$symlink"
        then
            echo "Successfully created symlink between $symlink and host in $PWD"
        else
            fatal_error "Failed to create symlink between $symlink and host in $PWD"
        fi
    fi

    # Make sure the libraries can be found by the EESSI linker
    host_injection_linker_dir=${EESSI_EPREFIX/versions/host_injections}
    if [ -L "$host_injection_linker_dir/lib" ]; then
        # Use readlink without -f to get direct symlink target 
        # using -f option will create "lastest" symlink one dir deeper (inside host) 
        target_path=$(readlink "$host_injection_linker_dir/lib")
        expected_target="$host_injections_nvidia_dir/latest"
        
        log_verbose "Checking symlink target for EESSI linker:"
        log_verbose "Current target: $target_path"
        log_verbose "Expected target: $expected_target"
        
        # Update symlink if needed
        if [ "$target_path" != "$expected_target" ]; then
            cd "$host_injection_linker_dir" || fatal_error "Failed to cd to $host_injection_linker_dir"
            log_verbose "Changed directory to: $PWD"

            
            if ln -sf "$expected_target" lib
            then
                echo "Successfully force created symlink between $expected_target and lib in $PWD"
            else
                fatal_error "Failed to force create symlink between $expected_target and lib in $PWD"
            fi
        else
            log_verbose "Symlink already points to correct target"
        fi
    else
        # Just start from scratch, symlink doesn't exists.
        check_global_read
        create_directory_structure "$host_injection_linker_dir"
        cd "$host_injection_linker_dir" || fatal_error "Failed to cd to $host_injection_linker_dir"
        log_verbose "Changed directory to: $PWD"

        if ln -s "$host_injections_nvidia_dir/latest" lib
        then
            echo "Successfully created symlink between $host_injections_nvidia_dir/latest and lib in $PWD"
        else
            fatal_error "Failed to create symlink between $host_injections_nvidia_dir/latest and lib in $PWD"
        fi
    fi

}

# Logging function for verbose mode
# TODO: move to utils?
log_verbose() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo "[VERBOSE] $*"
    fi
}


# ###############################################
# 2. Check prerequisites                        #
# ###############################################

# Make sure EESSI is initialised (doesn't matter what version)
check_eessi_initialised

# Verify nvidia-smi availability
log_verbose "Checking for nvidia-smi command..."
command -v nvidia-smi >/dev/null 2>&1 || { echo_yellow "nvidia-smi not found, this script won't do anything useful"; return 1; }

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help) 
        show_help 
        exit 0
        ;;  # Show help
    --show-ld-preload) LD_PRELOAD_MODE=1 ;;  # Enable LD_PRELOAD mode
    --no-download) LIBS_LIST="default" ;;  # Download latest list of CUDA libraries
    --verbose|-v) VERBOSE=1 ;;  # Enable verbose output
    *) 
        show_help
        fatal_error "Unknown option: $1"
        ;;
  esac
  shift
done

# ###############################################
# 3. Gather NVIDIA information                  #
# ###############################################

# Gather information about NVIDIA drivers (even if we are inside a Gentoo Prefix in a container)
export LD_LIBRARY_PATH="/.singularity.d/libs:${LD_LIBRARY_PATH}"

# Check for NVIDIA GPUs via nvidia-smi command
check_nvidia_smi_info

# ###############################################
# 4. Library detection and matching             #
# ###############################################

# Gather any CUDA related driver libraries from the host
# Sets MATCHED_LIBRARIES and MISSING_LIBRARIES array variables
find_cuda_libraries_on_host

# ###############################################
# 5. Handle operation modes                     #
# ###############################################

# === 5a. LD_PRELOAD Mode ===
if [ "$LD_PRELOAD_MODE" -eq 1 ]; then
    show_ld_preload
    exit 0
fi

# === 5b. Symlink Mode ===
# If we haven't already exited, we may need to create the symlinks
symlink_mode

# If everything went OK, show success message
echo_green "Host NVIDIA GPU drivers linked successfully for EESSI"
