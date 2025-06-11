# Software layer

The software layer of the EESSI project uses [EasyBuild](https://docs.easybuild.io), [Lmod](https://lmod.readthedocs.io) and [archspec](https://archspec.readthedocs.io).

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

## Setting up your environment

You can set up your environment by sourcing the init script:

```
$ source /cvmfs/software.eessi.io/versions/2023.06/init/bash
Found EESSI repo @ /cvmfs/software.eessi.io/versions/2023.06!
Derived subdirectory for software layer: x86_64/intel/haswell
Using x86_64/intel/haswell subdirectory for software layer
Initializing Lmod...
Prepending /cvmfs/software.eessi.io/versions/2023.06/software/x86_64/intel/haswell/modules/all to $MODULEPATH...
Environment set up to use EESSI (2023.06), have fun!
[EESSI 2023.06] $
```

### Accessing EESSI via a container

You need Singularity version 3.7 or newer. Then, simply run

```
$ ./eessi_container.sh
```
Once you get presented the prompt `Singularity>` run the above `source` command.

If you want to build a package for the software repository, simply add the arguments `--access rw`, e.g., full command would be

```
$ ./eessi_container.sh --access rw
```
Note, not all features/arguments listed via `./eessi_container.sh --help` are implemented.

# License

The software in this repository is distributed under the terms of the
[GNU General Public License v2.0](https://opensource.org/licenses/GPL-2.0).

See [LICENSE](https://github.com/EESSI/software-layer/blob/main/LICENSE) for more information.

SPDX-License-Identifier: GPL-2.0-only
