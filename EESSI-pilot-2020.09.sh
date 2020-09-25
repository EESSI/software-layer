#!/bin/bash
#
# Script to install EESSI pilot software stack (version 2020.09)
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

TMPDIR=$(mktemp -d)

echo ">> Setting up environment..."
export CVMFS_REPO="/cvmfs/pilot.eessi-hpc.org"
export EESSI_PILOT_VERSION="2020.09"
export ARCH=$(uname -m)
export EESSI_PREFIX=${CVMFS_REPO}/${EESSI_PILOT_VERSION}
export EPREFIX=${EESSI_PREFIX}/compat/${ARCH}

# make sure that $PATH starts with $CVMFS_REPO
# (if not, we're not running in the environment set up by 'startprefix')
if [[ $PATH = ${CVMFS_REPO}* ]]; then
    echo_green ">> It looks like we're in a Gentoo Prefix environment, good!"
else
    error "Not running in Gentoo Prefix environment, run '${EPREFIX}/startprefix' first!"
fi

echo ">> Initializing Lmod..."
source $EPREFIX/usr/lmod/*/init/bash
ml_version_out=$TMPDIR/ml.out
ml --version &> $ml_version_out
if [[ $? -eq 0 ]]; then
    echo_green ">> Found Lmod ${LMOD_VERSION}"
else
    error "Failed to initialize Lmod?! (see output in ${ml_version_out}"
fi

echo ">> Determining software subdirectory to use for current build host..."
export EESSI_SOFTWARE_SUBDIR=$(python3 $TOPDIR/eessi_software_subdir.py)
if [[ -z ${EESSI_SOFTWARE_SUBDIR} ]]; then
    error "Failed to determine software subdirectory?!"
else
    echo_green ">> Using ${EESSI_SOFTWARE_SUBDIR} as software subdirectory!"
fi

echo ">> Configuring EasyBuild..."
export EASYBUILD_PREFIX=/tmp/${USER}/easybuild
export EASYBUILD_INSTALLPATH=${EESSI_PREFIX}/software/${EESSI_SOFTWARE_SUBDIR}
export EASYBUILD_SOURCEPATH=/tmp/$USER/easybuild/sources:${EESSI_SOURCEPATH}

# just ignore OS dependencies for now, see https://github.com/easybuilders/easybuild-framework/issues/3430
export EASYBUILD_IGNORE_OSDEPS=1

export EASYBUILD_SYSROOT=${EPREFIX}

export EASYBUILD_DEBUG=1
export EASYBUILD_TRACE=1

export EASYBUILD_RPATH=1
export EASYBUILD_FILTER_ENV_VARS=LD_LIBRARY_PATH

export EASYBUILD_FILTER_DEPS=Autoconf,Automake,Autotools,binutils,bzip2,gettext,libreadline,libtool,M4,ncurses,XZ,zlib

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

echo ">> Loading EasyBuild module..."
module load EasyBuild
eb --version
if [[ $? -eq 0 ]]; then
    echo_green ">> Looking good!"
    eb --show-config
else
    error "EasyBuild not working?!"
fi

echo_green "All set, let's start installing some software in ${EASYBUILD_INSTALLPATH}..."

export GCC_EC="GCC-9.3.0.eb"
echo ">> Starting slow with ${GCC_EC}..."
eb ${GCC_EC} --robot
if [[ $? -eq 0 ]]; then
    echo_green "${GCC_EC} installed, yippy! Off to a good start..."
else
    error "Installation of ${GCC_EC} failed!"
fi

# side-step to fix missing build dependency for Perl,
# see https://github.com/easybuilders/easybuild-easyconfigs/pull/11200
export PERL_EC="Perl-5.30.2-GCCcore-9.3.0.eb"
echo ">> Taking a small side step to install ${PERL_EC}..."
eb --from-pr 11368 makeinfo-6.7-GCCcore-9.3.0.eb --robot && eb --from-pr 11200 --robot
if [[ $? -eq 0 ]]; then
    echo_green "${PERL_EC} installed via easyconfigs PR #11200, that was just a small side step, don't worry..."
else
    error "Installation of ${PERL_EC} failed!"
fi

echo ">> Installing OpenBLAS, Python 3 and Qt5..."
eb OpenBLAS-0.3.9-GCC-9.3.0.eb Python-3.8.2-GCCcore-9.3.0.eb Qt5-5.14.1-GCCcore-9.3.0.eb --robot
if [[ $? -eq 0 ]]; then
    echo_green "Done with OpenBLAS, Python 3 and Qt5!"
else
    error "Installation of OpenBLAS, Python 3 and Qt5 failed!"
fi

# FIXME: customized installation of OpenMPI, that supports high speed interconnects properly...
#        see https://github.com/EESSI/software-layer/issues/14
eb GROMACS-2020.1-foss-2020a-Python-3.8.2.eb OpenFOAM-8-foss-2020a.eb OpenFOAM-v2006-foss-2020a.eb --missing

echo ">> Cleaning up ${TMPDIR}..."
rm -r ${TMPDIR}
