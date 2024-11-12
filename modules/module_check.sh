#!/bin/bash

# This script checks the consistency of EB-generated modules and identifies broken or missing modules.
# Usage: ./module_check.sh <path to easystack file> [<optional path to PR diff>]

# It uses an adapted approach from check_missing_installations.sh to handling PRs/unmerged PRs
TOPDIR=$(dirname $(realpath $0))

if [ "$#" -eq 1 ]; then
    echo "No PR diff provided. Processing all modules in the easystack file."
    pr_exceptions=""
elif [ "$#" -eq 2 ]; then
    echo "Using $2 to create exceptions for PR filtering of easystack"
    pr_diff="$2"
    pr_exceptions=$(grep '^+' "$pr_diff" | grep 'from-pr' | uniq | awk '{print $3}' | xargs -I {} echo " || /'{}'/")
else
    echo "ERROR: Usage: $0 <path to easystack file> [<optional path to PR diff>]" >&2
    exit 1
fi

easystack="$1"

LOCAL_TMPDIR=$(mktemp -d)
mkdir -p "$LOCAL_TMPDIR"

# Clone the develop branch of EasyBuild and use that to search for easyconfigs
git clone -b develop https://github.com/easybuilders/easybuild-easyconfigs.git $LOCAL_TMPDIR/easyconfigs
export EASYBUILD_ROBOT_PATHS=$LOCAL_TMPDIR/easyconfigs/easybuild/easyconfigs

# All PRs used in EESSI are supposed to be merged, so we can strip ou all cases of from-pr
tmp_easystack="${LOCAL_TMPDIR}/$(basename "${easystack}")"
grep -v 'from-pr' "${easystack}" > "${tmp_easystack}"

# If PR exceptions exist, modify the easystack file to include exceptions
if [ -n "$pr_exceptions" ]; then
    # Use awk to exclude lines containing PR numbers specified in pr_exceptions
    awk_command="awk '!/from-pr/ EXCEPTIONS' ${easystack}"
    awk_command=${awk_command/\\/}
    eval "${awk_command/EXCEPTIONS/$pr_exceptions}" > "${tmp_easystack}"
fi

# Set up temporary directories for module installation and lock files
TMPDIR=${TMPDIR:-/tmp}/$USER
module_install_dir="$TMPDIR/EESSI/module-only"
locks_dir="$TMPDIR/EESSI/locks"
mkdir -p "$module_install_dir" "$locks_dir"

# Log file to record broken modules
broken_modules_log="broken_modules.log"
> "$broken_modules_log" 

# To keep track of already-checked modules and avoid re-checking
declare -A checked_modules

# Identify missing easyconfigs based on the temporary easystack file
echo "Identifying missing easyconfigs using the temporary easystack file..."
missing_easyconfigs=$(eb --easystack "${tmp_easystack}" --missing --robot 2>&1)

if [ -z "$missing_easyconfigs" ]; then
    echo "No missing easyconfigs to install."
    rm -rf "$LOCAL_TMPDIR"
    exit 0
fi

# Process each missing easyconfig file
for easyconfig_file in $missing_easyconfigs; do
    package_name=$(basename "$easyconfig_file" .eb)

    # Building of the easyconfig
    echo "Building $package_name using EasyBuild..."
    eb "$easyconfig_file" --robot
    if [ $? -ne 0 ]; then
        echo "EasyBuild build failed for $package_name. Skipping..."
        echo "$package_name: EasyBuild build failed" >> "$broken_modules_log"
        continue
    fi

    # Generate the module using --module-only
    echo "Generating module for $package_name using --module-only..."
    eb "$easyconfig_file" --module-only --installpath-modules "$module_install_dir" --locks-dir "$locks_dir" --force --robot
    if [ $? -ne 0 ]; then
        echo "EasyBuild --module-only command failed for $package_name. Skipping..."
        echo "$package_name: EasyBuild --module-only command failed" >> "$broken_modules_log"
        continue
    fi

    # Find the module file generated from the build
    module_relpath=$(eb "$easyconfig_file" --show-module --robot 2>/dev/null)
    if [ -z "$module_relpath" ]; then
        echo "Failed to get module relative path for $package_name"
        echo "$package_name: Failed to get module relative path" >> "$broken_modules_log"
        continue
    fi
    
    # Modules names and version 
    module_software=$(echo "$module_relpath" | sed 's/\.lua$//')

    # Check if the module has already been validated to avoid redundant checks
    if [ -n "${checked_modules[$module_software]}" ]; then
        echo "Module $module_software already checked. Skipping."
        continue
    fi

    # Paths to the module files generated from build and the --module-only
    module_file_build="${EASYBUILD_INSTALLPATH}/modules/all/${module_relpath}"
    module_file_module_only="${module_install_dir}/all/${module_relpath}"

    # Check if both module files exist
    if [ ! -f "$module_file_build" ]; then
        echo "Module file from full build not found: $module_file_build"
        echo "$package_name: Module file from full build not found" >> "$broken_modules_log"
        continue
    fi

    if [ ! -f "$module_file_module_only" ]; then
        echo "Module file from --module-only build not found: $module_file_module_only"
        echo "$package_name: Module file from --module-only build not found" >> "$broken_modules_log"
        continue
    fi

    # Compare the module files 
    if diff -q "$module_file_build" "$module_file_module_only" >/dev/null; then
        echo "Module files for $package_name match"
    else
        echo "Module files for $package_name differ"
        echo "$package_name: Module files differ" >> "$broken_modules_log"
	# Save differences 
        diff_file="${module_software//\//_}_module_diff.txt"
        diff "$module_file_build" "$module_file_module_only" > "$diff_file"
        echo "Module file differences saved to $diff_file"
    fi

    # Proceed to compare the environments
    echo "Testing module: $module_software"

    # Function to get filtered environment variables, excluding lmod-related vars 
    get_filtered_env() {
        env | grep -v -E '^(LMOD_|MODULEPATH|MODULESHOME|LOADEDMODULES|BASH_FUNC_module|_ModuleTable_|PWD=|SHLVL=|OLDPWD=|PS1=|PS2=|_LMFILES_)=.*$' | sort
    }

    # Compare the environments of the modules
    module purge
    module unuse "$module_install_dir"
    module load EasyBuild

    # Load the module from the full build
    if module --ignore_cache load "$module_software" 2>/dev/null; then
        original_env=$(get_filtered_env)
        module unload "$module_software"
    else
        echo "Failed to load module from full build: $module_software."
        original_env=""
    fi

    # Load the module from the --module-only 
    module purge
    module use "$module_install_dir"

    if module --ignore_cache load "$module_software" 2>/dev/null; then
        new_env=$(get_filtered_env)
        module unload "$module_software"
    else
        echo "Failed to load module from --module-only build: $module_software."
        echo "$package_name: Failed to load module from --module-only build" >> "$broken_modules_log"
        module unuse "$module_install_dir"
        continue
    fi

    # Compare the environments
    if [ -n "$original_env" ]; then
        if diff <(echo "$original_env") <(echo "$new_env") >/dev/null; then
            echo "$module_software loaded with identical environment."
        else
            echo "$module_software environment mismatch."
            echo "$package_name: $module_software (environment mismatch)" >> "$broken_modules_log"
            diff_file="${module_software//\//_}_env_diff.txt"
            diff <(echo "$original_env") <(echo "$new_env") > "$diff_file"
            echo "Environment differences saved to $diff_file"
        fi
    else
        echo "Original environment not available for comparison for $module_software."
        echo "$package_name: $module_software (failed to load module from full build)" >> "$broken_modules_log"
    fi


    module unuse "$module_install_dir"

    # Mark module as checked
    checked_modules[$module_software]=1

done

# Report 
if [ -f "$broken_modules_log" ] && [ -s "$broken_modules_log" ]; then
    echo "Some modules did not match. See $broken_modules_log for details."
    exit 1
else
    echo "All modules match between build and --module-only build."
fi

# Clean up temporary directories
rm -rf "$LOCAL_TMPDIR"

