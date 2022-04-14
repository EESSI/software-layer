# Drop into the prefix shell or pipe this script into a Prefix shell with
#   $EPREFIX/startprefix <<< /path/to/this_script.sh

# verify existence of nvidia-smi or this is a waste of time
# Check if nvidia-smi exists and can be executed without error
if command -v nvidia-smi > /dev/null 2>&1; then
  nvidia-smi > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "nvidia-smi was found but returned error code, exiting now..." >&2
    exit 1
  fi
  echo "nvidia-smi found, continue setup."
else
  echo "nvidia-smi not found, exiting now..." >&2
  exit 1
fi

# set up basic environment variables, EasyBuild and Lmod
# TODO: copied necessary parts from EESSI-pilot-install-software.sh, trim further down?
source setup.sh

# Get arch type from EESSI environment
eessi_cpu_family="${EESSI_CPU_FAMILY:-x86_64}"

# Get OS family
# TODO: needs more thorough testing
os_family=$(uname | tr '[:upper:]' '[:lower:]')

# Get OS version
# TODO: needs more thorough testing, taken from https://unix.stackexchange.com/a/6348
if [ -f /etc/os-release ]; then
  # freedesktop.org and systemd
  . /etc/os-release
  os=$NAME
  ver=$VERSION_ID
  if [[ "$os" == *"Rocky"* ]]; then
    os="rhel"
  fi
  if [[ "$os" == *"Debian"* ]]; then
    os="debian"
  fi
elif type lsb_release >/dev/null 2>&1; then
  # linuxbase.org
  os=$(lsb_release -si)
  ver=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
  # For some versions of Debian/Ubuntu without lsb_release command
  . /etc/lsb-release
  os=$DISTRIB_ID
  ver=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
  # Older Debian/Ubuntu/etc.
  os=Debian
  ver=$(cat /etc/debian_version)
else
  # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
  os=$(uname -s)
  ver=$(uname -r)
fi
# Convert OS version to major versions, e.g. rhel8.5 -> rhel8
# TODO: needs testing for e.g. Ubuntu 20.04
ver=${ver%.*}

##############################################################################################
# Check that the CUDA driver version is adequate
# (
#  needs to be r450 or r470 which are LTS, other production branches are acceptable but not
#  recommended, below r450 is not compatible [with an exception we will not explore,see
#  https://docs.nvidia.com/datacenter/tesla/drivers/#cuda-drivers]
# )
# only check first number in case of multiple GPUs
driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | tail -n1)
driver_version="${driver_version%%.*}"
# Now check driver_version for compatability
# Check driver is at least LTS driver R450, see https://docs.nvidia.com/datacenter/tesla/drivers/#cuda-drivers
if (( $driver_version < 450 )); then
  echo "Your NVIDIA driver version is too old, please update first.."
  exit 1
fi


# Check if the CUDA compat libraries are installed and compatible with the target CUDA version
# if not find the latest version of the compatibility libraries and install them

# get URL to latest CUDA compat libs, exit if URL is invalid
latest_cuda_compat_url="$(./get_latest_cuda_compatlibs.sh ${os} ${ver} ${eessi_cpu_family})"
ret=$?
if [ $ret -ne 0 ]; then
  echo $latest_cuda_compat_url
  exit 1
fi

# Create a general space for our NVIDIA compat drivers
if [ -w /cvmfs/pilot.eessi-hpc.org/host_injections ]; then
  mkdir -p /cvmfs/pilot.eessi-hpc.org/host_injections/nvidia
  cd /cvmfs/pilot.eessi-hpc.org/host_injections/nvidia
else
  echo "Cannot write to eessi host_injections space, exiting now..." >&2
  exit 1
fi

# Check if we have any version installed by checking for the existence of /cvmfs/pilot.eessi-hpc.org/host_injections/nvidia/latest

driver_cuda_version=$(nvidia-smi  -q --display=COMPUTE | grep CUDA | awk 'NF>1{print $NF}' | sed s/\\.//)
eessi_cuda_version=$(LD_LIBRARY_PATH=/cvmfs/pilot.eessi-hpc.org/host_injections/nvidia/latest/compat/:$LD_LIBRARY_PATH nvidia-smi  -q --display=COMPUTE | grep CUDA | awk 'NF>1{print $NF}' | sed s/\\.//)
if [ "$driver_cuda_version" -gt "$eessi_cuda_version" ]; then  echo "You need to update your CUDA compatability libraries"; fi

# Check if our target CUDA is satisfied by what is installed already
# TODO: Find required CUDA version and see if we need an update

# If not, grab the latest compat library RPM or deb
# download and unpack in temporary directory, easier cleanup after installation
mkdir -p tmp
cd tmp
compat_file=${latest_cuda_compat_url##*/}
wget ${latest_cuda_compat_url}

# Unpack it
# (the requirements here are OS dependent, can we get around that?)
# (for rpms looks like we can use https://gitweb.gentoo.org/repo/proj/prefix.git/tree/eclass/rpm.eclass?id=d7fc8cf65c536224bace1d22c0cd85a526490a1e)
# (deb files can be unpacked with ar and tar)
file_extension=${compat_file##*.}
if [[ ${file_extension} == "rpm" ]]; then
  rpm2cpio ${compat_file} | cpio -idmv
elif [[ ${file_extension} == "deb" ]]; then
  ar x ${compat_file}
  tar xf data.tar.*
else
  echo "File extension of cuda compat lib not supported, exiting now..." >&2
  exit 1
fi
cd ..
# TODO: This would prevent error messages if folder already exists, but could be problematic if only some files are missing in destination dir
mv -n tmp/usr/local/cuda-* .
rm -r tmp

# Add a symlink that points to the latest version
latest_cuda_dir=$(find . -maxdepth 1 -type d | grep -i cuda | sort | tail -n1)
echo $latest_cuda_dir
ln -sf ${latest_cuda_dir} latest

if [ ! -e latest ] ; then
  echo "Symlink to latest cuda compat lib version is broken, exiting now..."
  exit 1
fi

# Create the space to host the libraries
mkdir -p /cvmfs/pilot.eessi-hpc.org/host_injections/${EESSI_PILOT_VERSION}/compat/${os_family}/${eessi_cpu_family}
# Symlink in the path to the latest libraries
if [ ! -d "/cvmfs/pilot.eessi-hpc.org/host_injections/${EESSI_PILOT_VERSION}/compat/${os_family}/${eessi_cpu_family}/lib" ]; then
  ln -s /cvmfs/pilot.eessi-hpc.org/host_injections/nvidia/latest/compat /cvmfs/pilot.eessi-hpc.org/host_injections/${EESSI_PILOT_VERSION}/compat/${os_family}/${eessi_cpu_family}/lib
fi

# return to initial dir
cd $current_dir

###############################################################################################
###############################################################################################
# Install CUDA
# TODO: Can we do a trimmed install?
# if modules dir exists, load it for usage within Lmod
if [ -d /cvmfs/pilot.eessi-hpc.org/host_injections/nvidia/modules/all ]; then
  module use /cvmfs/pilot.eessi-hpc.org/host_injections/nvidia/modules/all
fi
# only install CUDA if specified version is not found
install_cuda_version="11.3.1"
module avail 2>&1 | grep -i CUDA/${install_cuda_version} &> ${ml_av_easybuild_out}
if [[ $? -eq 0 ]]; then
    echo_green ">> CUDA module found!"
else
  # - as an installation location just use $EESSI_SOFTWARE_PATH but replacing `versions` with `host_injections`
  #   (CUDA is a binary installation so no need to worry too much about this)
  # TODO: The install is pretty fat, you need lots of space for download/unpack/install (~3*5GB), need to do a space check before we proceed
  avail_space=$(df --output=avail /cvmfs/pilot.eessi-hpc.org/host_injections/nvidia/ | tail -n 1 | awk '{print $1}')
  if (( ${avail_space} < 16000000 )); then
    echo "Need more disk space to install CUDA, exiting now..."
    exit 1
  fi
  # install cuda in host_injections
  eb --installpath=/cvmfs/pilot.eessi-hpc.org/host_injections/nvidia/ CUDA-${install_cuda_version}.eb
fi

source test_cuda
