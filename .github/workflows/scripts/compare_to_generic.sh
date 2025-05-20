#!/usr/bin/env bash
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Take the arguments
base_dir=$1
target_arch=$2
modules_subdir="modules/all"
# Decide if we want x86_64 or aarch64
arch=$(echo $target_arch | cut -d"/" -f1)
# Get the generic directory
source_of_truth="$arch/generic"
case $arch in
    "x86_64")
        echo "Using $source_of_truth as source of truth"
        ;;
    "aarch64")
        echo "Using $source_of_truth as source of truth"
        ;;
    *)
        echo "I don't understand the base architecture: $arch"
        exit 1
        ;;
esac
source_of_truth_modules="$base_dir/$source_of_truth/$modules_subdir"
arch_modules="$base_dir/$target_arch/$modules_subdir"
echo "Comparing $arch_modules to $source_of_truth_modules"
python3 $script_dir/compare_stacks.py $source_of_truth_modules $arch_modules

# Also compare NVIDIA GPU software stacks
if [[ -n "$CUDA_COMPUTE_CAPABILITIES" ]]; then
    read -ra compute_capabilities <<< "$CUDA_COMPUTE_CAPABILITIES"
    echo "Also comparing CUDA-enabled software stacks (for compute capabilities: ${compute_capabilities[@]})"
    # Loop over the array
    for cc in "${compute_capabilities[@]}"; do
        source_of_truth_modules="$base_dir/$source_of_truth/accel/nvidia/cc80/$modules_subdir"
        arch_modules="$base_dir/$target_arch/accel/nvidia/$cc/$modules_subdir"
        echo "Comparing $arch_modules to $source_of_truth_modules"
        python3 $script_dir/compare_stacks.py $source_of_truth_modules $arch_modules
    done
else
    echo "CUDA_COMPUTE_CAPABILITIES is not set or is empty, not checking NVIDIA software stacks"
fi
