#!/bin/bash
#
# Script to install EESSI pilot software stack (version 2021.06)
#

TOPDIR=$(dirname $(realpath $0))

function echo_green() {
    echo -e "\e[32m$1\e[0m"
}

function echo_red() {
    echo -e "\e[31m$1\e[0m"
}

function echo_yellow() {
    echo -e "\e[33m$1\e[0m"
}

function error() {
    echo_red "ERROR: $1" >&2
    exit 1
}

function check_exit_code {
    ec=$1
    ok_msg=$2
    fail_msg=$3

    if [[ $ec -eq 0 ]]; then
        echo_green "${ok_msg}"
    else
        error "${fail_msg}"
    fi
}

# honor $TMPDIR if it is already defined, use /tmp otherwise
if [ -z $TMPDIR ]; then
    export WORKDIR=/tmp/$USER
else
    export WORKDIR=$TMPDIR/$USER
fi

TMPDIR=$(mktemp -d)

echo ">> Setting up environment..."
export CVMFS_REPO="/cvmfs/pilot.eessi-hpc.org"
export EESSI_PILOT_VERSION="2021.06"

if [[ $(uname -s) == 'Linux' ]]; then
    export EESSI_OS_TYPE='linux'
else
    export EESSI_OS_TYPE='macos'
fi

# aarch64 (Arm 64-bit), ppc64le (POWER 64-bit), x86_64 (x86 64-bit)
export EESSI_CPU_FAMILY=$(uname -m)

export EESSI_PREFIX=${CVMFS_REPO}/${EESSI_PILOT_VERSION}
export EPREFIX=${EESSI_PREFIX}/compat/${EESSI_OS_TYPE}/${EESSI_CPU_FAMILY}

# avoid that pyc files for EasyBuild are stored in EasyBuild installation directory
export PYTHONPYCACHEPREFIX=$TMPDIR/pycache

DETECTION_PARAMETERS=''
GENERIC=0
EB='eb'
if [[ "$1" == "--generic" || "$EASYBUILD_OPTARCH" == "GENERIC" ]]; then
    echo_yellow ">> GENERIC build requested, taking appropriate measures!"
    DETECTION_PARAMETERS="$DETECTION_PARAMETERS --generic"
    GENERIC=1
    EB='eb --optarch=GENERIC'
fi


# make sure we're in Prefix environment by which path to 'bash' command
if [[ $(which bash) = ${EPREFIX}/bin/bash ]]; then
    echo_green ">> It looks like we're in a Gentoo Prefix environment, good!"
else
    error "Not running in Gentoo Prefix environment, run '${EPREFIX}/startprefix' first!"
fi

echo ">> Initializing Lmod..."
source $EPREFIX/usr/share/Lmod/init/bash
ml_version_out=$TMPDIR/ml.out
ml --version &> $ml_version_out
if [[ $? -eq 0 ]]; then
    echo_green ">> Found Lmod ${LMOD_VERSION}"
else
    error "Failed to initialize Lmod?! (see output in ${ml_version_out}"
fi

echo ">> Determining software subdirectory to use for current build host..."
export EESSI_SOFTWARE_SUBDIR=$(python3 $TOPDIR/eessi_software_subdir.py $DETECTION_PARAMETERS)
if [[ -z ${EESSI_SOFTWARE_SUBDIR} ]]; then
    error "Failed to determine software subdirectory?!"
else
    echo_green ">> Using ${EESSI_SOFTWARE_SUBDIR} as software subdirectory!"
fi

echo ">> Configuring EasyBuild..."
export EASYBUILD_PREFIX=${WORKDIR}/easybuild
export EASYBUILD_INSTALLPATH=${EESSI_PREFIX}/software/${EESSI_OS_TYPE}/${EESSI_SOFTWARE_SUBDIR}
export EASYBUILD_SOURCEPATH=${WORKDIR}/easybuild/sources:${EESSI_SOURCEPATH}

# just ignore OS dependencies for now, see https://github.com/easybuilders/easybuild-framework/issues/3430
export EASYBUILD_IGNORE_OSDEPS=1

export EASYBUILD_SYSROOT=${EPREFIX}

export EASYBUILD_DEBUG=1
export EASYBUILD_TRACE=1
export EASYBUILD_ZIP_LOGS=bzip2

export EASYBUILD_RPATH=1
export EASYBUILD_FILTER_ENV_VARS=LD_LIBRARY_PATH

export EASYBUILD_HOOKS=$TOPDIR/eb_hooks.py
# make sure hooks are available, so we can produce a clear error message
if [ ! -f $EASYBUILD_HOOKS ]; then
    error "$EASYBUILD_HOOKS does not exist!"
fi

# note: filtering Bison may break some installations, like Qt5 (see https://github.com/EESSI/software-layer/issues/49)
# filtering pkg-config breaks R-bundle-Bioconductor installation (see also https://github.com/easybuilders/easybuild-easyconfigs/pull/11104)
# problems occur when filtering pkg-config with gnuplot too (picks up Lua 5.1 from $EPREFIX rather than from Lua 5.3 dependency)
DEPS_TO_FILTER=Autoconf,Automake,Autotools,binutils,bzip2,cURL,DBus,flex,gettext,gperf,help2man,intltool,libreadline,libtool,Lua,M4,makeinfo,ncurses,util-linux,XZ,zlib
# For aarch64 we need to also filter out Yasm.
# See https://github.com/easybuilders/easybuild-easyconfigs/issues/11190
if [[ "$EESSI_CPU_FAMILY" == "aarch64" ]]; then
    DEPS_TO_FILTER="${DEPS_TO_FILTER},Yasm"
fi

export EASYBUILD_FILTER_DEPS=$DEPS_TO_FILTER


export EASYBUILD_MODULE_EXTENSIONS=1

echo ">> Setting up \$MODULEPATH..."
# make sure no modules are loaded
module --force purge
# ignore current $MODULEPATH entirely
module unuse $MODULEPATH
module use $EASYBUILD_INSTALLPATH/modules/all
if [[ -z ${MODULEPATH} ]]; then
    error "Failed to set up \$MODULEPATH?!"
else
    echo_green ">> MODULEPATH set up: ${MODULEPATH}"
fi

echo ">> Checking for EasyBuild module..."
ml_av_easybuild_out=$TMPDIR/ml_av_easybuild.out
module avail easybuild &> ${ml_av_easybuild_out}
if [[ $? -eq 0 ]]; then
    echo_green ">> EasyBuild module found!"
else
    echo_yellow ">> No EasyBuild module yet, installing it..."

    EB_TMPDIR=${TMPDIR}/ebtmp
    echo ">> Temporary installation (in ${EB_TMPDIR})..."
    pip_install_out=${TMPDIR}/pip_install.out
    pip3 install --prefix $EB_TMPDIR easybuild &> ${pip_install_out}

    echo ">> Final installation in ${EASYBUILD_INSTALLPATH}..."
    export PATH=${EB_TMPDIR}/bin:$PATH
    export PYTHONPATH=$(ls -d ${EB_TMPDIR}/lib/python*/site-packages):$PYTHONPATH
    eb_install_out=${TMPDIR}/eb_install.out
    eb --install-latest-eb-release &> ${eb_install_out}

    module avail easybuild &> ${ml_av_easybuild_out}
    if [[ $? -eq 0 ]]; then
        echo_green ">> EasyBuild module installed!"
    else
        error "EasyBuild module failed to install?! (output of 'pip install' in ${pip_install_out}, output of 'eb' in ${eb_install_out}, output of 'ml av easybuild' in ${ml_av_easybuild_out})"
    fi
fi

REQ_EB_VERSION='4.4.1'
echo ">> Loading EasyBuild module..."
module load EasyBuild
eb_show_system_info_out=${TMPDIR}/eb_show_system_info.out
$EB --show-system-info > ${eb_show_system_info_out}
if [[ $? -eq 0 ]]; then
    echo_green ">> EasyBuild seems to be working!"
    $EB --version | grep "${REQ_EB_VERSION}"
    if [[ $? -eq 0 ]]; then
        echo_green "Found EasyBuild version ${REQ_EB_VERSION}, looking good!"
    else
        $EB --version
        error "Expected to find EasyBuild version ${REQ_EB_VERSION}, giving up here..."
    fi
    $EB --show-config
else
    cat ${eb_show_system_info_out}
    error "EasyBuild not working?!"
fi

echo_green "All set, let's start installing some software in ${EASYBUILD_INSTALLPATH}..."

# download source tarball for DB (dependency for Perl) using fixed source URL,
# see https://github.com/easybuilders/easybuild-easyconfigs/pull/13813
$EB --fetch --from-pr 13813 DB-18.1.32-GCCcore-9.3.0.eb

# install Java with fixed custom easyblock that uses patchelf to ensure right glibc is picked up,
# see https://github.com/EESSI/software-layer/issues/123
# and https://github.com/easybuilders/easybuild-easyblocks/pull/2557
ok_msg="Java installed, of to a good (?) start!"
fail_msg="Failed to install Java, woopsie..."
$EB Java-11.eb --robot --include-easyblocks-from-pr 2557
check_exit_code $? "${ok_msg}" "${fail_msg}"

# install GCC for foss/2020a
export GCC_EC="GCC-9.3.0.eb"
echo ">> Starting slow with ${GCC_EC}..."
ok_msg="${GCC_EC} installed, yippy! Off to a good start..."
fail_msg="Installation of ${GCC_EC} failed!"
$EB ${GCC_EC} --robot
check_exit_code $? "${ok_msg}" "${fail_msg}"

# install CMake with custom easyblock that patches CMake when --sysroot is used
echo ">> Install CMake with fixed easyblock to take into account --sysroot"
ok_msg="CMake installed!"
fail_msg="Installation of CMake failed, what the ..."
$EB CMake-3.16.4-GCCcore-9.3.0.eb --robot --include-easyblocks-from-pr 2248
check_exit_code $? "${ok_msg}" "${fail_msg}"

# If we're building OpenBLAS for GENERIC, we need https://github.com/easybuilders/easybuild-easyblocks/pull/1946
echo ">> Installing OpenBLAS..."
ok_msg="Done with OpenBLAS!"
fail_msg="Installation of OpenBLAS failed!"
if [[ $GENERIC -eq 1 ]]; then
    echo_yellow ">> Using https://github.com/easybuilders/easybuild-easyblocks/pull/1946 to build generic OpenBLAS."
    $EB --include-easyblocks-from-pr 1946 OpenBLAS-0.3.9-GCC-9.3.0.eb --robot
else
    $EB OpenBLAS-0.3.9-GCC-9.3.0.eb --robot
fi
check_exit_code $? "${ok_msg}" "${fail_msg}"

echo ">> Installing OpenMPI..."
ok_msg="OpenMPI installed, w00!"
fail_msg="Installation of OpenMPI failed, that's not good..."
$EB OpenMPI-4.0.3-GCC-9.3.0.eb --robot
check_exit_code $? "${ok_msg}" "${fail_msg}"

# install Python
echo ">> Install Python 2.7.18 and Python 3.8.2..."
ok_msg="Python 2.7.18 and 3.8.2 installed, yaay!"
fail_msg="Installation of Python failed, oh no..."
$EB Python-2.7.18-GCCcore-9.3.0.eb Python-3.8.2-GCCcore-9.3.0.eb --robot
check_exit_code $? "${ok_msg}" "${fail_msg}"

echo ">> Installing Perl..."
ok_msg="Perl installed, making progress..."
fail_msg="Installation of Perl failed, this never happens..."
$EB Perl-5.30.2-GCCcore-9.3.0.eb --robot
check_exit_code $? "${ok_msg}" "${fail_msg}"

echo ">> Installing Qt5..."
ok_msg="Qt5 installed, phieuw, that was a big one!"
fail_msg="Installation of Qt5 failed, that's frustrating..."
$EB Qt5-5.14.1-GCCcore-9.3.0.eb --robot
check_exit_code $? "${ok_msg}" "${fail_msg}"

# skip test step when installing SciPy-bundle on aarch64,
# to dance around problem with broken numpy tests;
# cfr. https://github.com/easybuilders/easybuild-easyconfigs/issues/11959
echo ">> Installing SciPy-bundle"
ok_msg="SciPy-bundle installed, yihaa!"
fail_msg="SciPy-bundle installation failed, bummer..."
SCIPY_EC=SciPy-bundle-2020.03-foss-2020a-Python-3.8.2.eb
if [[ "$(uname -m)" == "aarch64" ]]; then
  $EB $SCIPY_EC --robot --skip-test-step
else
  $EB $SCIPY_EC --robot
fi
check_exit_code $? "${ok_msg}" "${fail_msg}"

echo ">> Installing GROMACS..."
ok_msg="GROMACS installed, wow!"
fail_msg="Installation of GROMACS failed, damned..."
$EB GROMACS-2020.1-foss-2020a-Python-3.8.2.eb GROMACS-2020.4-foss-2020a-Python-3.8.2.eb --robot
check_exit_code $? "${ok_msg}" "${fail_msg}"

# note: compiling OpenFOAM is memory hungry (16GB is not enough with 8 cores)!
# 32GB is sufficient to build with 16 cores
echo ">> Installing OpenFOAM (twice!)..."
ok_msg="OpenFOAM installed, now we're talking!"
fail_msg="Installation of OpenFOAM failed, we were so close..."
$EB OpenFOAM-8-foss-2020a.eb OpenFOAM-v2006-foss-2020a.eb --robot
check_exit_code $? "${ok_msg}" "${fail_msg}"

echo ">> Installing QuantumESPRESSO..."
ok_msg="QuantumESPRESSO installed, let's go quantum!"
fail_msg="Installation of QuantumESPRESSO failed, did somebody observe it?!"
$EB QuantumESPRESSO-6.6-foss-2020a.eb --robot
check_exit_code $? "${ok_msg}" "${fail_msg}"

echo ">> Installing R 4.0.0 (better be patient)..."
ok_msg="R installed, wow!"
fail_msg="Installation of R failed, so sad..."
$EB R-4.0.0-foss-2020a.eb --robot
check_exit_code $? "${ok_msg}" "${fail_msg}"

echo ">> Installing Bioconductor 3.11 bundle..."
ok_msg="Bioconductor installed, enjoy!"
fail_msg="Installation of Bioconductor failed, that's annoying..."
$EB R-bundle-Bioconductor-3.11-foss-2020a-R-4.0.0.eb --robot
check_exit_code $? "${ok_msg}" "${fail_msg}"

if [ ! "${EESSI_CPU_FAMILY}" = "ppc64le" ]; then
    echo ">> Installing TensorFlow 2.3.1..."
    ok_msg="TensorFlow 2.3.1 installed, w00!"
    fail_msg="Installation of TensorFlow failed, why am I not surprised..."
    $EB TensorFlow-2.3.1-foss-2020a-Python-3.8.2.eb --robot --include-easyblocks-from-pr 2218
    check_exit_code $? "${ok_msg}" "${fail_msg}"

    echo ">> Installing Horovod 0.21.3..."
    ok_msg="Horovod installed! Go do some parallel training!"
    fail_msg="Horovod installation failed. There comes the headache..."
    $EB Horovod-0.21.3-foss-2020a-TensorFlow-2.3.1-Python-3.8.2.eb --robot
    check_exit_code $? "${ok_msg}" "${fail_msg}"

    echo ">> Installing code-server 3.7.3..."
    ok_msg="code-server 3.7.3 installed, now you can use VS Code!"
    fail_msg="Installation of code-server failed, that's going to be hard to fix..."
    $EB code-server-3.7.3.eb --robot
    check_exit_code $? "${ok_msg}" "${fail_msg}"
fi

echo ">> Installing ReFrame 3.6.2 ..."
ok_msg="ReFrame installed, enjoy!"
fail_msg="Installation of ReFrame failed, that's a bit strange..."
# note: newer PythonPackage easyblock required to ensure auto-download of sources works
$EB ReFrame-3.6.2.eb --robot
check_exit_code $? "${ok_msg}" "${fail_msg}"

echo ">> Installing RStudio-Server 1.3.1093..."
ok_msg="RStudio-Server installed, enjoy!"
fail_msg="Installation of RStudio-Server failed, might be OS deps..."
$EB RStudio-Server-1.3.1093-foss-2020a-Java-11-R-4.0.0.eb --robot
check_exit_code $? "${ok_msg}" "${fail_msg}"

echo ">> Installing OSU-Micro-Benchmarks 5.6.3..."
ok_msg="OSU-Micro-Benchmarks installed, yihaa!"
fail_msg="Installation of OSU-Micro-Benchmarks failed, that's unexpected..."
$EB OSU-Micro-Benchmarks-5.6.3-gompi-2020a.eb -r
check_exit_code $? "${ok_msg}" "${fail_msg}"

echo ">> Installing Spark 3.1.1..."
ok_msg="Spark installed, set off the fireworks!"
fail_msg="Installation of Spark failed, no fireworks this time..."
$EB Spark-3.1.1-foss-2020a-Python-3.8.2.eb -r
check_exit_code $? "${ok_msg}" "${fail_msg}"

echo ">> Installing IPython 7.15.0..."
ok_msg="IPython installed, launch your Jupyter Notebooks!"
fail_msg="Installation of IPython failed, that's unexpected..."
$EB IPython-7.15.0-foss-2020a-Python-3.8.2.eb -r
check_exit_code $? "${ok_msg}" "${fail_msg}"

echo ">> Creating/updating Lmod cache..."
export LMOD_RC="${EASYBUILD_INSTALLPATH}/.lmod/lmodrc.lua"
if [ ! -f $LMOD_RC ]; then
    python3 $TOPDIR/create_lmodrc.py ${EASYBUILD_INSTALLPATH}
    check_exit_code $? "$LMOD_RC created" "Failed to create $LMOD_RC"
fi

# we need to specify the path to the Lmod cache dir + timestamp file to ensure
# that update_lmod_system_cache_files updates correct Lmod cache
lmod_cache_dir=${EASYBUILD_INSTALLPATH}/.lmod/cache
lmod_cache_timestamp_file=${EASYBUILD_INSTALLPATH}/.lmod/cache/timestamp
modpath=${EASYBUILD_INSTALLPATH}/modules/all

${LMOD_DIR}/update_lmod_system_cache_files -d ${lmod_cache_dir} -t ${lmod_cache_timestamp_file} ${modpath}
check_exit_code $? "Lmod cache updated" "Lmod cache update failed!"

ls -lrt ${EASYBUILD_INSTALLPATH}/.lmod/cache

# temporarily install PyYAML in a temporary directory, and make sure it's picked up
# this can be removed when https://github.com/EESSI/compatibility-layer/issues/95 is fixed
ok_msg="PyYAML installed in $TMPDIR"
fail_msg="PyYAML failed to install in $TMPDIR, what the..."
pip_install_pyyaml_out=$TMPDIR/pip_pyyaml.out
pip install --prefix $TMPDIR PyYAML &> ${pip_install_pyyaml_out}
check_exit_code $? "${ok_msg}" "${fail_msg}"
export PYTHONPATH=$(ls -1 -d $TMPDIR/lib*/python*/site-packages):$PYTHONPATH
echo "PYTHONPATH=$PYTHONPATH"

echo ">> Checking for missing installations..."
ok_msg="No missing installations, party time!"
fail_msg="On no, some installations are still missing, how did that happen?!"
eb_missing_out=$TMPDIR/eb_missing.out
$EB --easystack eessi-${EESSI_PILOT_VERSION}.yml --experimental --missing --robot $EASYBUILD_PREFIX/ebfiles_repo | tee ${eb_missing_out}
grep "No missing modules" ${eb_missing_out} > /dev/null
check_exit_code $? "${ok_msg}" "${fail_msg}"

echo ">> Cleaning up ${TMPDIR}..."
rm -r ${TMPDIR}
