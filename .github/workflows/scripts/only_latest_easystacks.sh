#!/bin/bash
#
# This script figures out the latest version of EasyBuild being used for the installation of easystack
# files.
#
# This file is part of the EESSI software layer, see
# https://github.com/EESSI/software-layer.git
#
# author: Alan O'Cais (CECAM)
#
# license: GPLv2
#

EESSI_VERSION=${EESSI_VERSION:-"2023.06"}

directory="easystacks/software.eessi.io/${EESSI_VERSION}"
# List of example filenames
files=($(find "$directory" -name "*.yml" | grep -e '-eb-'))
[ -n "$DEBUG" ] && echo "${files[@]}"

versions=()
# Loop over each filename
for filename in "${files[@]}"; do
    # Extract the semantic version using grep
    version=$(echo "$filename" | grep -oP '(?<=eb-)\d+\.\d+\.\d+?(?=-)')
    
    # Output the result
    [ -n "$DEBUG" ] && echo "Filename: $filename"
    [ -n "$DEBUG" ] && echo "Extracted version: $version"
    [ -n "$DEBUG" ] && echo
    versions+=("$version")
done
highest_version=$(printf "%s\n" "${versions[@]}" | sort -V | tail -n 1)

[ -n "$DEBUG" ] && echo "Highest version: $highest_version"
[ -n "$DEBUG" ] && echo
[ -n "$DEBUG" ] && echo "Matching files:"
all_latest_easystacks=($(find $directory -type f -name "*eb-$highest_version*.yml"))

accel_latest_easystacks=()
cpu_latest_easystacks=()

# Loop through the array and split based on partial matching of string
accel="/accel/"
for item in "${all_latest_easystacks[@]}"; do
  if [[ "$item" == *"$accel"* ]]; then
    accel_latest_easystacks+=("$item")
  else
    cpu_latest_easystacks+=("$item")
  fi
done

# Output the results
if [ -n "$ACCEL_EASYSTACKS" ]; then
    echo "${accel_latest_easystacks[@]}"
else
    echo "${cpu_latest_easystacks[@]}"
fi
