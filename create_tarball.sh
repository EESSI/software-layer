#!/bin/bash

set -e

base_dir=$(dirname $(realpath $0))

if [ $# -ne 4 ]; then
    echo "ERROR: Usage: $0 <EESSI tmp dir (example: /tmp/$USER/EESSI)> <version (example: 2023.06)> <CPU arch subdir (example: x86_64/amd/zen2)> <path to tarball>" >&2
    exit 1
fi
eessi_tmpdir=$1
eessi_version=$2
cpu_arch_subdir=$3
target_tgz=$4

tmpdir=`mktemp -d`
echo ">> tmpdir: $tmpdir"

os="linux"
source ${base_dir}/init/eessi_defaults
cvmfs_repo=${EESSI_CVMFS_REPO}

software_dir="${cvmfs_repo}/versions/${eessi_version}/software/${os}/${cpu_arch_subdir}"
if [ ! -d ${software_dir} ]; then
    echo "Software directory ${software_dir} does not exist?!" >&2
    exit 2
fi

overlay_upper_dir="${eessi_tmpdir}/overlay-upper"

software_dir_overlay="${overlay_upper_dir}/versions/${eessi_version}/software/${os}/${cpu_arch_subdir}"
if [ ! -d ${software_dir_overlay} ]; then
    echo "Software directory overlay ${software_dir_overlay} does not exist?!" >&2
    exit 3
fi

cd ${overlay_upper_dir}/versions/
echo ">> Collecting list of files/directories to include in tarball via ${PWD}..."

files_list=${tmpdir}/files.list.txt
module_files_list=${tmpdir}/module_files.list.txt

if [ -d ${eessi_version}/scripts ]; then
    # include scripts we wish to ship along with EESSI,
    find ${eessi_version}/scripts -type f | grep -v '/\.wh\.' >> ${files_list}
fi
if [ -d ${eessi_version}/software/${os}/${cpu_arch_subdir}/.lmod ]; then
    # include Lmod cache and configuration file (lmodrc.lua),
    # skip whiteout files and backup copies of Lmod cache (spiderT.old.*)
    find ${eessi_version}/software/${os}/${cpu_arch_subdir}/.lmod -type f | egrep -v '/\.wh\.|spiderT.old' > ${files_list}
fi
if [ -d ${eessi_version}/software/${os}/${cpu_arch_subdir}/modules ]; then
    # module files
    find ${eessi_version}/software/${os}/${cpu_arch_subdir}/modules -type f | grep -v '/\.wh\.' >> ${files_list}
    # module symlinks
    find ${eessi_version}/software/${os}/${cpu_arch_subdir}/modules -type l | grep -v '/\.wh\.' >> ${files_list}
    # module files and symlinks
    find ${eessi_version}/software/${os}/${cpu_arch_subdir}/modules/all -type f -o -type l \
        | grep -v '/\.wh\.' | grep -v '/\.modulerc\.lua' | sed -e 's/.lua$//' | sed -e 's@.*/modules/all/@@g' | sort -u \
        >> ${module_files_list}
fi
if [ -d ${eessi_version}/software/${os}/${cpu_arch_subdir}/software -a -r ${module_files_list} ]; then
    # installation directories but only those for which module files were created
    # Note, we assume that module names (as defined by 'PACKAGE_NAME/VERSION.lua'
    # using EasyBuild's standard module naming scheme) match the name of the
    # software installation directory (expected to be 'PACKAGE_NAME/VERSION/').
    # If either side changes (module naming scheme or naming of software
    # installation directories), the procedure will likely not work.
    for package_version in $(cat ${module_files_list}); do
        echo "handling ${package_version}"
        ls -d ${eessi_version}/software/${os}/${cpu_arch_subdir}/software/${package_version} \
            | grep -v '/\.wh\.' >> ${files_list}
    done
fi

# add a bit debug output
echo "wrote file list to ${files_list}"
[ -r ${files_list} ] && cat ${files_list}
echo "wrote module file list to ${module_files_list}"
[ -r ${module_files_list} ] && cat ${module_files_list}

topdir=${cvmfs_repo}/versions/

echo ">> Creating tarball ${target_tgz} from ${topdir}..."
tar cfvz ${target_tgz} -C ${topdir} --files-from=${files_list}

echo ${target_tgz} created!

echo ">> Cleaning up tmpdir ${tmpdir}..."
rm -r ${tmpdir}
