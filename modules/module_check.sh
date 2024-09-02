#!/bin/bash
# Start interactive shell to access EESSI through build container
# mkdir -p /tmp/$USER/EESSI
# cd /tmp/$USER/EESSI
# git clone https://github.com/EESSI/software-layer
# cd software-layer
# ./eessi_container.sh

# Initialize EESSI + load/configure EasyBuild
# source /cvmfs/software.eessi.io/versions/2023.06/init/bash
# module load EasyBuild/4.9.2
# export WORKDIR=/tmp/$USER/EESSI
# source configure_easybuild

# .eb directory as an argument 
if [ -z "$1" ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

base_dir="$1"

# Dir where the modules will be 
module_install_dir="/tmp/$USER/EESSI/module-only"

locks_dir="/tmp/$USER/EESSI/locks"

# Log file to record broken modules 
broken_modules_log="broken_modules.log"
> $broken_modules_log

declare -A checked_modules

# Locate all .eb files within the base dir
easyconfig_files=$(find $base_dir -name "*.eb")

# Iterate over all eb files found. Package name based on eb file name
for easyconfig_file in $easyconfig_files; do
    package_name=$(basename $easyconfig_file .eb)

    # Run EB to generate the modules. Check if the eb command failed.  
    echo "Generating modules for $package_name using EasyBuild..."
    eb $easyconfig_file --module-only --installpath-modules $module_install_dir --locks-dir $locks_dir --force --robot
    if [ $? -ne 0 ]; then
        echo "EasyBuild command failed for $package_name. Skipping..."
        echo "$package_name: EasyBuild command failed" >> $broken_modules_log
        continue
    fi

    # Check the generated modules and iterate over the modules in the 'all' dir 
    echo "Checking generated modules for $package_name..."
    for module_category in $(ls $module_install_dir/all); do
        for module_version in $(ls $module_install_dir/all/$module_category); do
            module_name="$module_category/$module_version"

            # Checks if the module has already been tested 
            if [ -n "${checked_modules[$module_name]}" ]; then
                echo "Module $module_name already checked. Skipping."
                continue
            fi

            echo "Testing module: $module_name"

            # Try loading the module 
            if module --ignore_cache load $module_name 2>/dev/null; then
                echo "$module_name loaded successfully."
                module unload $module_name
            else
                echo "$module_name is broken."
                echo "$package_name: $module_name" >> $broken_modules_log
            fi

            checked_modules[$module_name]=1
        done
    done
done

echo "All module checks completed. Broken modules are listed in $broken_modules_log"

