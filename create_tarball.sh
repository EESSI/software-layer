#!/bin/bash

set -e

if [ $# -ne 2 ]; then
    echo "ERROR: Usage: $0 <pilot version (example: 2021.03)> <CPU arch subdir (example: x86_64/amd/zen2)" >&2
    exit 1
fi
pilot_version=$1
cpu_arch_subdir=$2

tmpdir=`mktemp -d`
echo ">> tmpdir: $tmpdir"

os="linux"
cvmfs_repo="/cvmfs/pilot.eessi-hpc.org"

software_dir="${cvmfs_repo}/${pilot_version}/software/${os}/${cpu_arch_subdir}"
if [ ! -d ${software_dir} ]; then
    echo "Software directory ${software_dir} does not exist?!" >&2
    exit 2
fi

overlay_upper_dir="/tmp/$USER/EESSI/overlay-upper"

software_dir_overlay="${overlay_upper_dir}/${pilot_version}/software/${os}/${cpu_arch_subdir}"
if [ ! -d ${software_dir_overlay} ]; then
    echo "Software directory overlay ${software_dir_overlay} does not exist?!" >&2
    exit 3
fi

cd ${overlay_upper_dir}/${pilot_version}
echo ">> Collecting list of files/directories to include in tarball via ${PWD}..."

files_list=${tmpdir}/files.list.txt

# always include Lmod cache directory
echo "software/${os}/${cpu_arch_subdir}/.lmod/cache" > ${files_list}
# module files
find software/${os}/${cpu_arch_subdir}/modules -type f >> ${files_list}
# module symlinks
find software/${os}/${cpu_arch_subdir}/modules -type l >> ${files_list}
# installation directories, exclude EasyBuild (*.pyc files)
ls -d software/${os}/${cpu_arch_subdir}/software/*/* | grep -v '/software/EasyBuild/' >> ${files_list}

topdir=${cvmfs_repo}/${pilot_version}
timestamp=`date +%s`
target_tgz="$HOME/eessi-${pilot_version}-software-${os}-`echo ${cpu_arch_subdir} | tr '/' '-'`-${timestamp}.tar.gz"

echo ">> Creating tarball ${target_tgz} from ${topdir}..."
tar cfvz ${target_tgz} -C ${topdir} --files-from=${files_list}

echo ${target_tgz} created!

echo ">> Cleaning up tmpdir ${tmpdir}..."
rm -r ${tmpdir}
