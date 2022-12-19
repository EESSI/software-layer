#!/bin/bash
#
# Script to install EESSI pilot software stack (version 2021.12)

# see example parsing of command line arguments at
#   https://wiki.bash-hackers.org/scripting/posparams#using_a_while_loop
#   https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

display_help() {
  echo "usage: $0 [OPTIONS]"
  echo "  -g | --generic         -  instructs script to build for generic architecture target"
  echo "  -h | --help            -  display this usage information"
  echo "  -x | --http-proxy URL  -  provides URL for the environment variable http_proxy"
  echo "  -y | --https-proxy URL -  provides URL for the environment variable https_proxy"
}

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -g|--generic)
      EASYBUILD_OPTARCH="GENERIC"
      shift
      ;;
    -h|--help)
      display_help  # Call your function
      # no shifting needed here, we're done.
      exit 0
      ;;
    -x|--http-proxy)
      export http_proxy="$2"
      shift 2
      ;;
    -y|--https-proxy)
      export https_proxy="$2"
      shift 2
      ;;
    -*|--*)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
    *)  # No more options
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"

TOPDIR=$(dirname $(realpath $0))

source $TOPDIR/utils.sh

# honor $TMPDIR if it is already defined, use /tmp otherwise
if [ -z $TMPDIR ]; then
    export WORKDIR=/tmp/$USER
else
    export WORKDIR=$TMPDIR/$USER
fi

TMPDIR=$(mktemp -d)

echo ">> Setting up environment..."

source $TOPDIR/init/minimal_eessi_env

if [ -d $EESSI_CVMFS_REPO ]; then
    echo_green "$EESSI_CVMFS_REPO available, OK!"
else
    fatal_error "$EESSI_CVMFS_REPO is not available!"
fi

# make sure we're in Prefix environment by checking $SHELL
if [[ ${SHELL} = ${EPREFIX}/bin/bash ]]; then
    echo_green ">> It looks like we're in a Gentoo Prefix environment, good!"
else
    fatal_error "Not running in Gentoo Prefix environment, run '${EPREFIX}/startprefix' first!"
fi

# avoid that pyc files for EasyBuild are stored in EasyBuild installation directory
export PYTHONPYCACHEPREFIX=$TMPDIR/pycache

DETECTION_PARAMETERS=''
GENERIC=0
EB='eb'
if [[ "$EASYBUILD_OPTARCH" == "GENERIC" ]]; then
    echo_yellow ">> GENERIC build requested, taking appropriate measures!"
    DETECTION_PARAMETERS="$DETECTION_PARAMETERS --generic"
    GENERIC=1
    EB='eb --optarch=GENERIC'
fi

echo ">> Determining software subdirectory to use for current build host..."
export EESSI_SOFTWARE_SUBDIR_OVERRIDE=$(python3 $TOPDIR/eessi_software_subdir.py $DETECTION_PARAMETERS)

# Set all the EESSI environment variables (respecting $EESSI_SOFTWARE_SUBDIR_OVERRIDE)
# $EESSI_SILENT - don't print any messages
# $EESSI_BASIC_ENV - give a basic set of environment variables
EESSI_SILENT=1 EESSI_BASIC_ENV=1 source $TOPDIR/init/eessi_environment_variables

if [[ -z ${EESSI_SOFTWARE_SUBDIR} ]]; then
    fatal_error "Failed to determine software subdirectory?!"
elif [[ "${EESSI_SOFTWARE_SUBDIR}" != "${EESSI_SOFTWARE_SUBDIR_OVERRIDE}" ]]; then
    fatal_error "Values for EESSI_SOFTWARE_SUBDIR_OVERRIDE (${EESSI_SOFTWARE_SUBDIR_OVERRIDE}) and EESSI_SOFTWARE_SUBDIR (${EESSI_SOFTWARE_SUBDIR}) differ!"
else
    echo_green ">> Using ${EESSI_SOFTWARE_SUBDIR} as software subdirectory!"
fi

echo ">> Initializing Lmod..."
source $EPREFIX/usr/share/Lmod/init/bash
ml_version_out=$TMPDIR/ml.out
ml --version &> $ml_version_out
if [[ $? -eq 0 ]]; then
    echo_green ">> Found Lmod ${LMOD_VERSION}"
else
    fatal_error "Failed to initialize Lmod?! (see output in ${ml_version_out}"
fi

echo ">> Configuring EasyBuild..."
source configure_easybuild

echo ">> Setting up \$MODULEPATH..."
# make sure no modules are loaded
module --force purge
# ignore current $MODULEPATH entirely
module unuse $MODULEPATH
module use $EASYBUILD_INSTALLPATH/modules/all
if [[ -z ${MODULEPATH} ]]; then
    fatal_error "Failed to set up \$MODULEPATH?!"
else
    echo_green ">> MODULEPATH set up: ${MODULEPATH}"
fi

REQ_EB_VERSION='4.5.0'

echo ">> Checking for EasyBuild module..."
ml_av_easybuild_out=$TMPDIR/ml_av_easybuild.out
module avail 2>&1 | grep -i easybuild/${REQ_EB_VERSION} &> ${ml_av_easybuild_out}
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
    ok_msg="Latest EasyBuild release installed, let's go!"
    fail_msg="Installing latest EasyBuild release failed, that's not good... (output: ${eb_install_out})"
    eb --install-latest-eb-release &> ${eb_install_out}
    check_exit_code $? "${ok_msg}" "${fail_msg}"

    eb --search EasyBuild-${REQ_EB_VERSION}.eb | grep EasyBuild-${REQ_EB_VERSION}.eb > /dev/null
    if [[ $? -eq 0 ]]; then
        ok_msg="EasyBuild v${REQ_EB_VERSION} installed, alright!"
        fail_msg="Installing EasyBuild v${REQ_EB_VERSION}, yikes! (output: ${eb_install_out})"
        eb EasyBuild-${REQ_EB_VERSION}.eb >> ${eb_install_out} 2>&1
        check_exit_code $? "${ok_msg}" "${fail_msg}"
    fi

    module avail easybuild/${REQ_EB_VERSION} &> ${ml_av_easybuild_out}
    if [[ $? -eq 0 ]]; then
        echo_green ">> EasyBuild module installed!"
    else
        fatal_error "EasyBuild/${REQ_EB_VERSION} module failed to install?! (output of 'pip install' in ${pip_install_out}, output of 'eb' in ${eb_install_out}, output of 'ml av easybuild' in ${ml_av_easybuild_out})"
    fi
fi

echo ">> Loading EasyBuild module..."
module load EasyBuild/$REQ_EB_VERSION
eb_show_system_info_out=${TMPDIR}/eb_show_system_info.out
$EB --show-system-info > ${eb_show_system_info_out}
if [[ $? -eq 0 ]]; then
    echo_green ">> EasyBuild seems to be working!"
    $EB --version | grep "${REQ_EB_VERSION}"
    if [[ $? -eq 0 ]]; then
        echo_green "Found EasyBuild version ${REQ_EB_VERSION}, looking good!"
    else
        $EB --version
        fatal_error "Expected to find EasyBuild version ${REQ_EB_VERSION}, giving up here..."
    fi
    $EB --show-config
else
    cat ${eb_show_system_info_out}
    fatal_error "EasyBuild not working?!"
fi

echo_green "All set, let's start installing some software in ${EASYBUILD_INSTALLPATH}..."

# install Java with fixed custom easyblock that uses patchelf to ensure right glibc is picked up,
# see https://github.com/EESSI/software-layer/issues/123
# and https://github.com/easybuilders/easybuild-easyblocks/pull/2557
ok_msg="Java installed, off to a good (?) start!"
fail_msg="Failed to install Java, woopsie..."
$EB Java-11.eb --robot --include-easyblocks-from-pr 2557
check_exit_code $? "${ok_msg}" "${fail_msg}"

# install GCC for foss/2020a
export GCC_EC="GCC-9.3.0.eb"
echo ">> Starting slow with ${GCC_EC}..."
ok_msg="${GCC_EC} installed, yippy! Off to a good start..."
fail_msg="Installation of ${GCC_EC} failed!"
# pull in easyconfig from https://github.com/easybuilders/easybuild-easyconfigs/pull/14453,
# which includes patch to fix build of GCC 9.3 when recent kernel headers are in place
$EB ${GCC_EC} --robot --from-pr 14453 GCCcore-9.3.0.eb
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
# use enhanced Perl easyblock from https://github.com/easybuilders/easybuild-easyblocks/pull/2640
# to avoid trouble when using long installation prefix (for example with EESSI pilot 2021.12 on skylake_avx512...)
$EB Perl-5.30.2-GCCcore-9.3.0.eb --robot --include-easyblocks-from-pr 2640
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

if [ ! "${EESSI_CPU_FAMILY}" = "ppc64le" ]; then
    echo ">> Installing QuantumESPRESSO..."
    ok_msg="QuantumESPRESSO installed, let's go quantum!"
    fail_msg="Installation of QuantumESPRESSO failed, did somebody observe it?!"
    $EB QuantumESPRESSO-6.6-foss-2020a.eb --robot
    check_exit_code $? "${ok_msg}" "${fail_msg}"
fi

echo ">> Installing R 4.0.0 (better be patient)..."
ok_msg="R installed, wow!"
fail_msg="Installation of R failed, so sad..."
$EB R-4.0.0-foss-2020a.eb --robot --parallel-extensions-install --experimental
check_exit_code $? "${ok_msg}" "${fail_msg}"

echo ">> Installing Bioconductor 3.11 bundle..."
ok_msg="Bioconductor installed, enjoy!"
fail_msg="Installation of Bioconductor failed, that's annoying..."
$EB R-bundle-Bioconductor-3.11-foss-2020a-R-4.0.0.eb --robot
check_exit_code $? "${ok_msg}" "${fail_msg}"

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

if [ ! "${EESSI_CPU_FAMILY}" = "ppc64le" ]; then

    echo ">> Installing code-server 3.7.3..."
    ok_msg="code-server 3.7.3 installed, now you can use VS Code!"
    fail_msg="Installation of code-server failed, that's going to be hard to fix..."
    $EB code-server-3.7.3.eb --robot
    check_exit_code $? "${ok_msg}" "${fail_msg}"
fi

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

echo ">> Installing WRF 3.9.1.1..."
ok_msg="WRF installed, it's getting hot in here!"
fail_msg="Installation of WRF failed, that's unexpected..."
OMPI_MCA_pml=ucx UCX_TLS=tcp $EB WRF-3.9.1.1-foss-2020a-dmpar.eb -r --include-easyblocks-from-pr 2648
check_exit_code $? "${ok_msg}" "${fail_msg}"

echo ">> Installing Nextflow 22.10.1..."
ok_msg="Nextflow installed, the work must flow..."
fail_msg="Installation of Nextflow failed, that's unexpected..."
$EB -r --from-pr 16531 Nextflow-22.10.1.eb
check_exit_code $? "${ok_msg}" "${fail_msg}"


echo ">> Installing EasyBuild 4.5.1..."
ok_msg="EasyBuild v4.5.1 installed"
fail_msg="EasyBuild v4.5.1 failed to install"
$EB --from-pr 14545 --include-easyblocks-from-pr 2805
check_exit_code $? "${ok_msg}" "${fail_msg}"

LMOD_IGNORE_CACHE=1 module swap EasyBuild/4.5.1
check_exit_code $? "Swapped to EasyBuild/4.5.1" "Couldn't swap to EasyBuild/4.5.1"

echo ">> Installing SciPy-bundle with foss/2021a..."
ok_msg="SciPy-bundle with foss/2021a installed, welcome to the modern age"
fail_msg="Installation of SciPy-bundle with foss/2021a failed, back to the stone age..."
# use GCCcore easyconfig from https://github.com/easybuilders/easybuild-easyconfigs/pull/14454
# which includes patch to fix installation with recent Linux kernel headers
$EB --from-pr 14454 GCCcore-10.3.0.eb --robot
# use enhanced Perl easyblock from https://github.com/easybuilders/easybuild-easyblocks/pull/2640
# to avoid trouble when using long installation prefix (for example with EESSI pilot 2021.12 on skylake_avx512...)
$EB Perl-5.32.1-GCCcore-10.3.0.eb --robot --include-easyblocks-from-pr 2640
# use enhanced CMake easyblock to patch CMake's UnixPaths.cmake script if --sysroot is set
# from https://github.com/easybuilders/easybuild-easyblocks/pull/2248
$EB CMake-3.20.1-GCCcore-10.3.0.eb --robot --include-easyblocks-from-pr 2248
# use Rust easyconfig from https://github.com/easybuilders/easybuild-easyconfigs/pull/14584
# that includes patch to fix bootstrap problem when using alternate sysroot
$EB --from-pr 14584 Rust-1.52.1-GCCcore-10.3.0.eb --robot
# use OpenBLAS easyconfig from https://github.com/easybuilders/easybuild-easyconfigs/pull/15885
# which includes a patch to fix installation on POWER
$EB --from-pr 15885 OpenBLAS-0.3.15-GCC-10.3.0.eb --robot

$EB SciPy-bundle-2021.05-foss-2021a.eb -r --buildpath /dev/shm/$USER/easybuild_build
check_exit_code $? "${ok_msg}" "${fail_msg}"

# CUDA support

# install p7zip (to be able to unpack RPMs)
p7zip_ec="p7zip-17.04-GCCcore-10.3.0.eb"
echo ">> Installing $p7zip_ec..."
ok_msg="$p7zip_ec installed, off to a good (?) start!"
fail_msg="Failed to install $p7zip_ec, woopsie..."
$EB $p7zip_ec --robot
check_exit_code $? "${ok_msg}" "${fail_msg}"

# install CUDA (uses eb_hooks.py to only install runtime)
cuda_ec="CUDA-11.3.1.eb"
echo ">> Installing $cuda_ec..."
ok_msg="$cuda_ec installed, off to a good (?) start!"
fail_msg="Failed to install $cuda_ec, woopsie..."
$EB $cuda_ec --robot
check_exit_code $? "${ok_msg}" "${fail_msg}"

# Add the host_injections CUDA so we can actually build CUDA apps
# (which unbreaks the symlinks from the runtime installation)
./install_cuda_host_injections.sh 11.3.1

# install CUDA samples (requires EESSI support for CUDA)
cuda_samples_ec="CUDA-Samples-11.3-GCC-10.3.0-CUDA-11.3.1.eb"
echo ">> Installing $cuda_samples_ec..."
ok_msg="$cuda_ec installed, off to a good (?) start!"
fail_msg="Failed to install $cuda_samples_ec, woopsie..."
$EB $cuda_samples_ec --robot --from-pr=16914
check_exit_code $? "${ok_msg}" "${fail_msg}"

### add packages here

echo ">> Creating/updating Lmod cache..."
export LMOD_RC="${EASYBUILD_INSTALLPATH}/.lmod/lmodrc.lua"
if [ ! -f $LMOD_RC ]; then
    python3 $TOPDIR/create_lmodrc.py ${EASYBUILD_INSTALLPATH}
    check_exit_code $? "$LMOD_RC created" "Failed to create $LMOD_RC"
fi

$TOPDIR/update_lmod_cache.sh ${EPREFIX} ${EASYBUILD_INSTALLPATH}

echo ">> Checking for missing installations..."
ok_msg="No missing installations, party time!"
fail_msg="On no, some installations are still missing, how did that happen?!"
eb_missing_out=$TMPDIR/eb_missing.out
$EB --easystack eessi-${EESSI_PILOT_VERSION}.yml --experimental --missing --robot $EASYBUILD_PREFIX/ebfiles_repo | tee ${eb_missing_out}
grep "No missing modules" ${eb_missing_out} > /dev/null
check_exit_code $? "${ok_msg}" "${fail_msg}"

echo ">> Cleaning up ${TMPDIR}..."
rm -r ${TMPDIR}
