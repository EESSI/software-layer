#!/bin/bash

os=$1
ver=$2
eessi_cpu_family=$3

# build URL for CUDA libraries
cuda_url="https://developer.download.nvidia.com/compute/cuda/repos/"${os}${ver}"/"${eessi_cpu_family}"/"
# get latest version, files are sorted by date
# TODO: probably better to explicitly check version numbers than trusting that it is sorted
latest_file=$(curl -s "${cuda_url}" | grep 'cuda-compat' | tail -1)
if [[ -z "${latest_file// }" ]]; then
        echo "Could not find any compat lib files under" ${cuda_url}
        exit 1
fi
# extract actual file name from html snippet
file=$(echo $latest_file | sed 's/<\/\?[^>]\+>//g')
# build final URL for wget
cuda_url="${cuda_url}$file"
# simply echo the URL, result will be used by add_gpu_support.sh
echo $cuda_url
