#!/bin/bash

set -e

if [ $# -ne 4 ]; then
    echo "ERROR: Usage: $0 <EESSI tmp dir (example: /tmp/$USER/EESSI)> <pilot version (example: 2021.03)> <CPU arch subdir (example: x86_64/amd/zen2)> <path to tarball>" >&2
    exit 1
fi
eessi_tmpdir=$1
pilot_version=$2
cpu_arch_subdir=$3
target_tgz=$4

tmpdir=`mktemp -d`
echo ">> tmpdir: $tmpdir"

os="linux"
cvmfs_repo="/cvmfs/pilot.eessi-hpc.org"

software_dir="${cvmfs_repo}/versions/${pilot_version}/software/${os}/${cpu_arch_subdir}"
if [ ! -d ${software_dir} ]; then
    echo "Software directory ${software_dir} does not exist?!" >&2
    exit 2
fi

overlay_upper_dir="${eessi_tmpdir}/overlay-upper"

software_dir_overlay="${overlay_upper_dir}/versions/${pilot_version}/software/${os}/${cpu_arch_subdir}"
if [ ! -d ${software_dir_overlay} ]; then
    echo "Software directory overlay ${software_dir_overlay} does not exist?!" >&2
    exit 3
fi

cd ${overlay_upper_dir}/versions/
echo ">> Collecting list of files/directories to include in tarball via ${PWD}..."

files_list=${tmpdir}/files.list.txt

if [ -d ${pilot_version}/software/${os}/${cpu_arch_subdir}/.lmod ]; then
    # include Lmod cache and configuration file (lmodrc.lua),
    # skip whiteout files and backup copies of Lmod cache (spiderT.old.*)
    find ${pilot_version}/software/${os}/${cpu_arch_subdir}/.lmod -type f | egrep -v '/\.wh\.|spiderT.old' > ${files_list}
fi
if [ -d ${pilot_version}/software/${os}/${cpu_arch_subdir}/modules ]; then
    # module files
    find ${pilot_version}/software/${os}/${cpu_arch_subdir}/modules -type f | grep -v '/\.wh\.' >> ${files_list}
    # module symlinks
    find ${pilot_version}/software/${os}/${cpu_arch_subdir}/modules -type l | grep -v '/\.wh\.' >> ${files_list}
fi
if [ -d ${pilot_version}/software/${os}/${cpu_arch_subdir}/software ]; then
    # installation directories
    ls -d ${pilot_version}/software/${os}/${cpu_arch_subdir}/software/*/* | grep -v '/\.wh\.' >> ${files_list}
fi

topdir=${cvmfs_repo}/versions/

echo ">> Creating tarball ${target_tgz} from ${topdir}..."
tar cfvz ${target_tgz} -C ${topdir} --files-from=${files_list}

echo ${target_tgz} created!

echo ">> Cleaning up tmpdir ${tmpdir}..."
rm -r ${tmpdir}
