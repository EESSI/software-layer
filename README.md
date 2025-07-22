# Software layer

The software layer of the EESSI project uses [EasyBuild](https://docs.easybuild.io),
[Lmod](https://lmod.readthedocs.io) and `archdetect` (a custom bash script to do architecture detection for both CPU
and GPU).

See also https://www.eessi.io/docs/software_layer .

## Recent changes

**Wed 11 June 2025**

- Code & scripts that are used to build the EESSI software layer have been relocated to a separate repository:
  [`EESSI/software-layer-scripts`](https://github.com/EESSI/software-layer-scripts).

- The minimal `bot/build.sh` script in this repository pulls in the latest `main` branch of the `EESSI/software-layer-scripts` repository,
  symlinks the files in there, and then calls out to the `bot/build.sh` script located in that separate repository.

- The default branch of this repository has been changed to `main` (was `2023.06-software.eessi.io`),
  and houses [easystack files](https://docs.easybuild.io/easystack-files) for all versions of EESSI (not just `2023.06`).

For more details, see https://gitlab.com/eessi/support/-/issues/139 .

## Contributing to the EESSI software layer

Please see the documentation on [adding software to EESSI](https://www.eessi.io/docs/adding_software/overview/).

## Setting up EESSI in your environment

Please refer the EESSI documentation for instructions on how to
[install EESSI](https://www.eessi.io/docs/getting_access/native_installation/) and
[set up the EESSI environment](https://www.eessi.io/docs/using_eessi/setting_up_environment/).

### Accessing EESSI via a container

Again, for the latest information for this supported use case it is recommended that you refer to the
[documentation of the EESSI container script](https://www.eessi.io/docs/getting_access/eessi_container/).

# License

The software in this repository is distributed under the terms of the
[GNU General Public License v2.0](https://opensource.org/licenses/GPL-2.0).

See [LICENSE](https://github.com/EESSI/software-layer/blob/main/LICENSE) for more information.

SPDX-License-Identifier: GPL-2.0-only
