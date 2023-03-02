#!/bin/bash

install_p7zip_version=$1
cuda_install_dir=$2

# Install p7zip, this will be used to install the CUDA compat libraries from rpm.
# The rpm and deb files contain the same libraries, so we just stick to the rpm version.
# If p7zip is missing from the software layer (for whatever reason), we need to install it.
# This has to happen in host_injections, so we check first if it is already installed there.
if [ -d ${cuda_install_dir}/modules/all ]; then
  module use ${cuda_install_dir}/modules/all/
fi
module avail 2>&1 | grep -i p7zip &> /dev/null
if [[ $? -eq 0 ]]; then
  echo "p7zip module found! No need to install p7zip again, proceeding with installation of compat libraries"
else
  # install p7zip in host_injections
  export EASYBUILD_IGNORE_OSDEPS=1
  export EASYBUILD_SYSROOT=${EPREFIX}
  export EASYBUILD_RPATH=1
  export EASYBUILD_FILTER_ENV_VARS=LD_LIBRARY_PATH
  export EASYBUILD_FILTER_DEPS=Autoconf,Automake,Autotools,binutils,bzip2,cURL,DBus,flex,gettext,gperf,help2man,intltool,libreadline,libtool,Lua,M4,makeinfo,ncurses,util-linux,XZ,zlib
  export EASYBUILD_MODULE_EXTENSIONS=1
  module load EasyBuild
  eb --robot --installpath=${cuda_install_dir}/ p7zip-${install_p7zip_version}.eb
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "p7zip installation failed, please check EasyBuild logs..."
    exit 1
  fi
fi
