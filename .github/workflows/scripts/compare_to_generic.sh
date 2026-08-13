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

if ! python3 $script_dir/compare_stacks.py $source_of_truth_modules $arch_modules; then
    echo "Warning: Comparison failed for CPU stacks" >&2
    exit 1
fi

# Also compare accelerator software stacks
if [[ -n "$ACCELERATOR_TARGETS" ]]; then
    read -ra accel_capabilities <<< "$ACCELERATOR_TARGETS"
    echo "Also comparing accelerator-enabled software stacks (for compute capabilities: ${accel_capabilities[@]})"
    # Initialize a variable to track failures
    any_failure=0
    # Loop over the array
    for accel in "${accel_capabilities[@]}"; do
        source_of_truth_accel="${ACCELERATOR_TARGETS%% *}"  # Just use the first entry as source of truth
        source_of_truth_modules="$base_dir/$source_of_truth/accel/${source_of_truth_accel}/$modules_subdir"
        arch_modules="$base_dir/$target_arch/accel/$accel/$modules_subdir"
        echo "Comparing $arch_modules to $source_of_truth_modules"
        if ! python3 $script_dir/compare_stacks.py $source_of_truth_modules $arch_modules; then
            echo "Warning: Comparison failed for compute capability $cc" >&2
            any_failure=1
        fi
    done
    if [[ $any_failure -ne 0 ]]; then
        echo "One or more accelerator software stack comparisons failed." >&2
        exit 1
    fi
else
    echo "ACCELERATOR_TARGETS is not set or is empty, not checking accelerator software stacks"
fi
