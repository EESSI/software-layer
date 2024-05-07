# Software layer

The software layer of the EESSI project uses [EasyBuild](https://docs.easybuild.io), [Lmod](https://lmod.readthedocs.io) and [archspec](https://archspec.readthedocs.io).

See also https://www.eessi.io/docs/software_layer .

## Pilot software stack

You can set up your environment by sourcing the init script:

```
$ source /cvmfs/riscv.eessi.io/versions/20240402/init/bash
Found EESSI repo @ /cvmfs/riscv.eessi.io/versions/20240402!
archdetect says riscv64/generic
Using riscv64/generic as software subdirectory.
Found Lmod configuration file at /cvmfs/riscv.eessi.io/versions/20240402/software/linux/riscv64/generic/.lmod/lmodrc.lua
Found Lmod SitePackage.lua file at /cvmfs/riscv.eessi.io/versions/20240402/software/linux/riscv64/generic/.lmod/SitePackage.lua
Using /cvmfs/riscv.eessi.io/versions/20240402/software/linux/riscv64/generic/modules/all as the directory to be added to MODULEPATH.
Initializing Lmod...
Prepending /cvmfs/riscv.eessi.io/versions/20240402/software/linux/riscv64/generic/modules/all to $MODULEPATH...
Environment set up to use EESSI (20240402), have fun!
{EESSI 20240402} $
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
