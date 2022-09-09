# Software layer

The software layer of the EESSI project uses [EasyBuild](https://easybuild.readthedocs.io), [Lmod](https://lmod.readthedocs.io) and [archspec](https://archspec.readthedocs.io).

See also https://eessi.github.io/docs/software_layer.

## Pilot software stack

You can set up your environment by sourcing the init script:

```
$ source /cvmfs/pilot.eessi-hpc.org/versions/2021.12/init/bash
Found EESSI pilot repo @ /cvmfs/pilot.eessi-hpc.org/versions/2021.12!
Derived subdirectory for software layer: x86_64/intel/haswell
Using x86_64/intel/haswell subdirectory for software layer (HARDCODED)
Initializing Lmod...
Prepending /cvmfs/pilot.eessi-hpc.org/versions/2021.12/software/x86_64/intel/haswell/modules/all to $MODULEPATH...
Environment set up to use EESSI pilot software stack, have fun!
[EESSI pilot 2021.12] $
```

# License

The software in this repository is distributed under the terms of the
[GNU General Public License v2.0](https://opensource.org/licenses/GPL-2.0).

See [LICENSE](https://github.com/EESSI/software-layer/blob/main/LICENSE) for more information.

SPDX-License-Identifier: GPL-2.0-only
