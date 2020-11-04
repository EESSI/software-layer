#!/bin/bash
#
# Script to install EESSI pilot software stack (version 2020.10)
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

# honor $TMPDIR if it is already defined, use /tmp otherwise
if [ -z $TMPDIR ]; then
    export WORKDIR=/tmp/$USER
else
    export WORKDIR=$TMPDIR/$USER
fi

TMPDIR=$(mktemp -d)

echo ">> Setting up environment..."
export CVMFS_REPO="/cvmfs/pilot.eessi-hpc.org"
export EESSI_PILOT_VERSION="2020.10"
export ARCH=$(uname -m)
export EESSI_PREFIX=${CVMFS_REPO}/${EESSI_PILOT_VERSION}
export EPREFIX=${EESSI_PREFIX}/compat/${ARCH}

DETECTION_PARAMETERS=''
GENERIC=0
EB='eb'
if [[ "$1" == "--generic" || "$EASYBUILD_OPTARCH" == "GENERIC" ]]; then
    echo_yellow ">> GENERIC build requested, taking appropriate measures!"
    DETECTION_PARAMETERS="$DETECTION_PARAMETERS --generic"
    GENERIC=1
    EB='eb --optarch=GENERIC'
fi


# make sure that $PATH starts with $CVMFS_REPO
# (if not, we're not running in the environment set up by 'startprefix')
if [[ $PATH = ${CVMFS_REPO}* ]]; then
    echo_green ">> It looks like we're in a Gentoo Prefix environment, good!"
else
    error "Not running in Gentoo Prefix environment, run '${EPREFIX}/startprefix' first!"
fi

echo ">> Initializing Lmod..."
source $EPREFIX/usr/lmod/lmod/init/bash
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
export EASYBUILD_INSTALLPATH=${EESSI_PREFIX}/software/${EESSI_SOFTWARE_SUBDIR}
export EASYBUILD_SOURCEPATH=${WORKDIR}/easybuild/sources:${EESSI_SOURCEPATH}

# just ignore OS dependencies for now, see https://github.com/easybuilders/easybuild-framework/issues/3430
export EASYBUILD_IGNORE_OSDEPS=1

export EASYBUILD_SYSROOT=${EPREFIX}

export EASYBUILD_DEBUG=1
export EASYBUILD_TRACE=1
export EASYBUILD_ZIP_LOGS=bzip2

export EASYBUILD_RPATH=1
export EASYBUILD_FILTER_ENV_VARS=LD_LIBRARY_PATH


DEPS_TO_FILTER=Autoconf,Automake,Autotools,binutils,bzip2,gettext,libreadline,libtool,M4,ncurses,XZ,zlib
# For aarch64 we need to also filter out Yasm.
# See https://github.com/easybuilders/easybuild-easyconfigs/issues/11190
if [[ "$ARCH" == "aarch64" ]]; then
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

    eb_bootstrap_out=${TMPDIR}/eb_bootstrap.out

    workdir=${TMPDIR}/easybuild_bootstrap
    mkdir -p ${workdir}
    cd ${workdir}
    curl --silent -OL https://raw.githubusercontent.com/easybuilders/easybuild-framework/develop/easybuild/scripts/bootstrap_eb.py
    python3 bootstrap_eb.py ${EASYBUILD_INSTALLPATH} &> ${eb_bootstrap_out}
    cd - > /dev/null

    module avail easybuild &> ${ml_av_easybuild_out}
    if [[ $? -eq 0 ]]; then
        echo_green ">> EasyBuild module installed!"
    else
        error "EasyBuild module failed to install?! (output of bootstrap script in ${eb_bootstrap_out}, output of 'ml av easybuild' in ${ml_av_easybuild_out})"
    fi
fi

REQ_EB_VERSION='4.3.1'
echo ">> Loading EasyBuild module..."
module load EasyBuild
$EB --show-system-info > /dev/null
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
    error "EasyBuild not working?!"
fi

# patch RPATH wrapper to also take into account $LIBRARY_PATH (required for TensorFlow)
# see https://github.com/easybuilders/easybuild-framework/pull/3495
echo ">> Patching rpath_args.py script in EasyBuild installation..."
EB_SCRIPTS=$EBROOTEASYBUILD/easybuild/scripts
RPATH_ARGS='rpath_args.py'
cp -a ${EB_SCRIPTS}/${RPATH_ARGS} ${EB_SCRIPTS}/${RPATH_ARGS}.orig
cd ${TMPDIR}
curl --silent -OL https://raw.githubusercontent.com/easybuilders/easybuild-framework/develop/easybuild/scripts/${RPATH_ARGS}
cd - > /dev/null
cp ${TMPDIR}/${RPATH_ARGS} ${EB_SCRIPTS}/${RPATH_ARGS}
chmod u+x ${EB_SCRIPTS}/${RPATH_ARGS}

echo_green "All set, let's start installing some software in ${EASYBUILD_INSTALLPATH}..."

# install GCC, using GCC easyblock with workaround for bug introduced in EasyBuild v4.3.1,
# see https://github.com/easybuilders/easybuild-easyblocks/pull/2217
export GCC_EC="GCC-9.3.0.eb"
echo ">> Starting slow with ${GCC_EC}..."
$EB ${GCC_EC} --robot --include-easyblocks-from-pr 2217
if [[ $? -eq 0 ]]; then
    echo_green "${GCC_EC} installed, yippy! Off to a good start..."
else
    error "Installation of ${GCC_EC} failed!"
fi

# install custom fontconfig that is aware of the compatibility layer's fonts directory
# see https://github.com/EESSI/software-layer/pull/31
export FONTCONFIG_EC="fontconfig-2.13.92-GCCcore-9.3.0.eb"
echo ">> Installing custom fontconfig easyconfig (${FONTCONFIG_EC})..."
cd ${TMPDIR}
curl --silent -OL https://raw.githubusercontent.com/EESSI/software-layer/master/easyconfigs/${FONTCONFIG_EC}
cd - > /dev/null
$EB $TMPDIR/${FONTCONFIG_EC} --robot
if [[ $? -eq 0 ]]; then
    echo_green "Custom fontconfig installed!"
else
    error "Installation of fontconfig failed, what the ..."
fi

# If we're building OpenBLAS for GENERIC, we need https://github.com/easybuilders/easybuild-easyblocks/pull/1946
echo ">> Installing OpenBLAS..."
if [[ $GENERIC -eq 1 ]]; then
    echo_yellow ">> Using https://github.com/easybuilders/easybuild-easyblocks/pull/1946 to build generic OpenBLAS."
    $EB --include-easyblocks-from-pr 1946 OpenBLAS-0.3.9-GCC-9.3.0.eb --robot
else
    $EB OpenBLAS-0.3.9-GCC-9.3.0.eb --robot
fi
if [[ $? -eq 0 ]]; then
    echo_green "Done with OpenBLAS!"
else
    error "Installation of OpenBLAS failed!"
fi

echo ">> Installing OpenMPI..."
$EB OpenMPI-4.0.3-GCC-9.3.0.eb --robot
if [[ $? -eq 0 ]]; then
    echo_green "OpenMPI installed, w00!"
else
    error "Installation of OpenMPI failed, that's not good..."
fi

echo ">> Installing Python 3 and Qt5..."
$EB Python-3.8.2-GCCcore-9.3.0.eb Qt5-5.14.1-GCCcore-9.3.0.eb --robot
if [[ $? -eq 0 ]]; then
    echo_green "Done with Python 3 and Qt5!"
else
    error "Installation of Python 3 and Qt5 failed!"
fi

echo ">> Installing GROMACS..."
$EB GROMACS-2020.1-foss-2020a-Python-3.8.2.eb --robot
if [[ $? -eq 0 ]]; then
    echo_green "GROMACS installed, wow!"
else
    error "Installation of GROMACS failed, damned..."
fi

echo ">> Installing OpenFOAM (twice!)..."
$EB OpenFOAM-8-foss-2020a.eb OpenFOAM-v2006-foss-2020a.eb --robot
if [[ $? -eq 0 ]]; then
    echo_green "OpenFOAM installed, now we're talking!"
else
    error "Installation of OpenFOAM failed, we were so close..."
fi

echo ">> Installing R 4.0.0 (better be patient)..."
$EB --from-pr 11600 R-4.0.0-foss-2020a.eb --robot
if [[ $? -eq 0 ]]; then
    echo_green "R installed, wow!"
else
    error "Installation of R failed, so sad..."
fi

echo ">> Installing Bioconductor 3.11 bundle..."
$EB R-bundle-Bioconductor-3.11-foss-2020a-R-4.0.0.eb --robot
if [[ $? -eq 0 ]]; then
    echo_green "Bioconductor installed, enjoy!"
else
    error "Installation of Bioconductor failed, that's annoying..."
fi

echo ">> Installing TensorFlow 2.3.1..."
$EB --from-pr 11614 TensorFlow-2.3.1-foss-2020a-Python-3.8.2.eb --robot --include-easyblocks-from-pr 2218
if [[ $? -eq 0 ]]; then
    echo_green "TensorFlow 2.3.1 installed, w00!"
else
    error "Installation of TensorFlow failed, why am I not surprised..."
fi


echo ">> Cleaning up ${TMPDIR}..."
rm -r ${TMPDIR}
