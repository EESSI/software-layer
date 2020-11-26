# Bash initialisation for EESSI

This directory contains the default initialisation script for a bash shell used to
configure Lmod and use the EESSI software modules. The (bash)
file `eessi_environment_variables` is used to set and export the full set of EESSI
environment variables:

- `EESSI_PREFIX`: The base directory of the entire software stack.
- `EESSI_EPREFIX`: The location of Gentoo Prefix compatability layer (for the architecture).
- `EESSI_EPREFIX_PYTHON`: Path to `python3` in the Gentoo Prefix layer.
- `EESSI_SOFTWARE_SUBDIR`: Hardware specific software subdirectory. 
- `EESSI_SOFTWARE_PATH`: Full path to EESSI software stack.
- `EESSI_MODULEPATH`: Path to be added to the `MODULEPATH`. This can be influenced by two
  externally defined environment varialbes:
    - `EESSI_CUSTOM_MODULEPATH`: defines a fully custom directory to be added to
      `MODULEPATH`, the end user is entirely responsible for what this directory contains.
    - `EESSI_MODULE_SUBDIR`: EESSI may ship with a number of possible module naming schemes.
      This variable can be used to point to a non-default module naming scheme.

All scripts respect the environment variable `EESSI_SILENT` which, if defined to any
value, will make them produce no (non-error) output.

## `Magic_Castle` subdirectory

The `Magic_Castle` subdirectory is home to the bash initialisation that we use for
[Magic Castle](https://github.com/ComputeCanada/magic_castle).

It also contains a wrapper a hardware optimised EESSI Python 3 installation that is used
by Magic Castle to properly configure JupyterHub.