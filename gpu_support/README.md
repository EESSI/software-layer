# How to add GPU support
The collection of scripts in this directory enables you to add GPU support to your setup.
Note that currently this means that CUDA support can be added for Nvidia GPUs. AMD GPUs are not yet supported (feel free to contribute that though!).
To enable the usage of CUDA in your setup, simply run the following script:
```
./add_nvidia_gpu_support.sh
```
## Prerequisites and tips
* You need write permissions to `/cvmfs/pilot.eessi-hpc.org/host_injections` (which by default is a symlink to `/opt/eessi` but can be configured in your CVMFS config file to point somewhere else). If you would like to make a system-wide installation you should change this in your configuration to point somewhere on a shared filesystem.
* If you want to install CUDA on a node without GPUs (e.g. on a login node where you want to be able to compile your CUDA-enabled code), you should `export INSTALL_WO_GPU=true` in order to skip checks and tests that can only succeed if you have access to a GPU. This approach is not recommended as there is a chance the CUDA compatibility library installed is not compatible with the existing CUDA driver on GPU nodes (and this will not be detected).