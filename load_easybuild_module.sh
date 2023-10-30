# Script to load the environment module for a specific version of EasyBuild.
# If that module is not available yet, the current latest EasyBuild version of EasyBuild will be installed,
# and used to install the specific EasyBuild version being specified.
#
# This script must be sourced, since it makes changes in the current environment, like loading an EasyBuild module.
#
# This script is part of the EESSI software layer, see
# https://github.com/EESSI/software-layer.git
#
# author: Kenneth Hosye (@boegel, HPC-UGent)
#
# license: GPLv2
#
#
set -o pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <EasyBuild version>" >&2
    exit 1
fi

# don't use $EASYBUILD_VERSION, since that enables always running 'eb --version'
EB_VERSION=${1}

# make sure that environment variables that we expect to be set are indeed set
if [ -z "${TMPDIR}" ]; then
    echo "\$TMPDIR is not set" >&2
    exit 2
fi

# ${EB} is used to specify which 'eb' command should be used;
# can potentially be more than just 'eb', for example when using 'eb --optarch=GENERIC'
if [ -z "${EB}" ]; then
    echo "\$EB is not set" >&2
    exit 2
fi

# make sure that utility functions are defined (cfr. scripts/utils.sh script in EESSI/software-layer repo)
type check_exit_code
if [ $? -ne 0 ]; then
    echo "check_exit_code function is not defined" >&2
    exit 3
fi

echo ">> Checking for EasyBuild module..."

ml_av_easybuild_out=${TMPDIR}/ml_av_easybuild.out
module avail 2>&1 | grep -i easybuild/${EB_VERSION} &> ${ml_av_easybuild_out}

if [[ $? -eq 0 ]]; then
    echo_green ">> Module for EasyBuild v${EB_VERSION} found!"
else
    echo_yellow ">> No module yet for EasyBuild v${EB_VERSION}, installing it..."

    EB_TMPDIR=${TMPDIR}/ebtmp
    echo ">> Temporary installation (in ${EB_TMPDIR})..."
    pip_install_out=${TMPDIR}/pip_install.out
    pip3 install --prefix ${EB_TMPDIR} easybuild &> ${pip_install_out}

    # keep track of original $PATH and $PYTHONPATH values, so we can restore them
    ORIG_PATH=${PATH}
    ORIG_PYTHONPATH=${PYTHONPATH}

    echo ">> Final installation in ${EASYBUILD_INSTALLPATH}..."
    export PATH=${EB_TMPDIR}/bin:${PATH}
    export PYTHONPATH=$(ls -d ${EB_TMPDIR}/lib/python*/site-packages):${PYTHONPATH}
    eb_install_out=${TMPDIR}/eb_install.out
    ok_msg="Latest EasyBuild release installed, let's go!"
    fail_msg="Installing latest EasyBuild release failed, that's not good... (output: ${eb_install_out})"
    ${EB} --install-latest-eb-release 2>&1 | tee ${eb_install_out}
    check_exit_code $? "${ok_msg}" "${fail_msg}"

    # maybe the module obtained with --install-latest-eb-release is exactly the EasyBuild version we wanted?
    module avail 2>&1 | grep -i easybuild/${EB_VERSION} &> ${ml_av_easybuild_out}
    if [[ $? -eq 0 ]]; then
        echo_green ">> Module for EasyBuild v${EB_VERSION} found!"
    else
        module avail --ignore_cache 2>&1 | grep -i easybuild/${EB_VERSION} &> ${ml_av_easybuild_out}
        if [[ $? -eq 0 ]]; then
            echo_green ">> Module for EasyBuild v${EB_VERSION} found!"
        else
            eb_ec=EasyBuild-${EB_VERSION}.eb
            echo_yellow ">> Still no module for EasyBuild v${EB_VERSION}, trying with easyconfig ${eb_ec}..."
            ${EB} --search ${eb_ec} | grep ${eb_ec} > /dev/null
            if [[ $? -eq 0 ]]; then
                echo "Easyconfig ${eb_ec} found for EasyBuild v${EB_VERSION}, so installing it..."
                ok_msg="EasyBuild v${EB_VERSION} installed, alright!"
                fail_msg="Installing EasyBuild v${EB_VERSION}, yikes! (output: ${eb_install_out})"
                ${EB} EasyBuild-${EB_VERSION}.eb 2>&1 | tee -a ${eb_install_out}
                check_exit_code $? "${ok_msg}" "${fail_msg}"
            else
                fatal_error "No easyconfig found for EasyBuild v${EB_VERSION}"
            fi
        fi
    fi

    # restore origin $PATH and $PYTHONPATH values, and clean up environment variables that are no longer needed
    export PATH=${ORIG_PATH}
    export PYTHONPATH=${ORIG_PYTHONPATH}
    unset EB_TMPDIR ORIG_PATH ORIG_PYTHONPATH

    module avail easybuild/${EB_VERSION} &> ${ml_av_easybuild_out}
    if [[ $? -eq 0 ]]; then
        echo_green ">> EasyBuild/${EB_VERSION} module installed!"
    else
        fatal_error "EasyBuild/${EB_VERSION} module failed to install?! (output of 'pip install' in ${pip_install_out}, output of 'eb' in ${eb_install_out}, output of 'module avail easybuild' in ${ml_av_easybuild_out})"
    fi
fi

echo ">> Loading EasyBuild v${EB_VERSION} module..."
module load EasyBuild/${EB_VERSION}
eb_show_system_info_out=${TMPDIR}/eb_show_system_info.out
${EB} --show-system-info > ${eb_show_system_info_out}
if [[ $? -eq 0 ]]; then
    echo_green ">> EasyBuild seems to be working!"
    ${EB} --version | grep "${EB_VERSION}"
    if [[ $? -eq 0 ]]; then
        echo_green "Found EasyBuild version ${EB_VERSION}, looking good!"
    else
        ${EB} --version
        fatal_error "Expected to find EasyBuild version ${EB_VERSION}, giving up here..."
    fi
    ${EB} --show-config
else
    cat ${eb_show_system_info_out}
    fatal_error "EasyBuild not working?!"
fi

unset EB_VERSION
