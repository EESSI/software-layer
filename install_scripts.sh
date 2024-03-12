#!/bin/bash
#
# Script to install scripts from the software-layer repo into the EESSI software stack

display_help() {
  echo "usage: $0 [OPTIONS]"
  echo "  -p | --prefix          -  prefix to copy the scripts to"
  echo "  -h | --help            -  display this usage information"
}

compare_and_copy() {
    if [ "$#" -ne 2 ]; then
        echo "Usage of function: compare_and_copy <source_file> <destination_file>"
        return 1
    fi

    source_file="$1"
    destination_file="$2"

    if [ ! -f "$destination_file" ] || ! diff -q "$source_file" "$destination_file" ; then
        cp "$source_file" "$destination_file"
        echo "File $1 copied to $2"
    else
        echo "Files $1 and $2 are identical. No copy needed."
    fi
}

copy_files_by_list() {
# Compares and copies listed files from a source to a target directory
    if [ ! "$#" -ge 3 ]; then
        echo "Usage of function: copy_files_by_list <source_dir> <destination_dir> <file_list>"
        echo "Here, file_list is an (expanded) bash array"
        echo "Example:"
        echo "my_files=(file1 file2)"
        echo 'copy_files_by_list /my/source /my/target "${my_files[@]}"'
        return 1
    fi
    source_dir="$1"
    target_dir="$2"
    # Need to shift all arguments to the left twice. Then, rebuild the array with the rest of the arguments
    shift
    shift
    file_list=("$@")

    # Create target dir
    mkdir -p ${target_dir}

    # Copy from source to target
    echo "Copying files: ${file_list[@]}"
    echo "From directory: ${source_dir}"
    echo "To directory: ${target_dir}"

    for file in ${file_list[@]}; do
        compare_and_copy ${source_dir}/${file} ${target_dir}/${file}
    done
}

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--prefix)
      INSTALL_PREFIX="$2"
      shift 2
      ;;
    -h|--help)
      display_help  # Call your function
      # no shifting needed here, we're done.
      exit 0
      ;;
    -*|--*)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
    *)  # No more options
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"

TOPDIR=$(dirname $(realpath $0))

# Copy for init directory
init_files=(
    bash eessi_archdetect.sh eessi_defaults eessi_environment_variables eessi_software_subdir_for_host.py
    minimal_eessi_env README.md test.py
)
copy_files_by_list ${TOPDIR}/init ${INSTALL_PREFIX}/init "${init_files[@]}"

# Copy for the init/arch_specs directory
arch_specs_files=(
   eessi_arch_arm.spec eessi_arch_ppc.spec eessi_arch_x86.spec
)
copy_files_by_list ${TOPDIR}/init/arch_specs ${INSTALL_PREFIX}/init/arch_specs "${arch_specs_files[@]}"

# Copy for init/Magic_castle directory
mc_files=(
   bash eessi_python3
)
copy_files_by_list ${TOPDIR}/init/Magic_Castle ${INSTALL_PREFIX}/init/Magic_Castle "${mc_files[@]}"

# Copy for the scripts directory
script_files=(
    utils.sh
)
copy_files_by_list ${TOPDIR}/scripts ${INSTALL_PREFIX}/scripts "${script_files[@]}"

# Copy files for the scripts/gpu_support/nvidia directory
nvidia_files=(
    install_cuda_host_injections.sh link_nvidia_host_libraries.sh
)
copy_files_by_list ${TOPDIR}/scripts/gpu_support/nvidia ${INSTALL_PREFIX}/scripts/gpu_support/nvidia "${nvidia_files[@]}"
