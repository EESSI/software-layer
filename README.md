# Software layer

The software layer of the EESSI project uses [EasyBuild](https://easybuild.readthedocs.io), [Lmod](https://lmod.readthedocs.io) and [archspec](https://archspec.readthedocs.io).

See also https://eessi.github.io/docs/software_layer.

## Pilot software stack

A script that sets up your environment to start using the 2020.08 version of the EESSI pilot software stack
is available at `EESSI-pilot-2020.08_init.sh`.

This script should be copied to `/cvmfs/pilot.eessi-hpc.org/2020.08/init/bash` if it is not available there already,
and sourced to set up your environment:

```
$ source /cvmfs/pilot.eessi-hpc.org/2020.08/init/bash
Found EESSI pilot repo @ /cvmfs/pilot.eessi-hpc.org/2020.08!
Derived subdirectory for software layer: x86_64/intel/haswell
Using x86_64/intel/haswell subdirectory for software layer (HARDCODED)
Initializing Lmod...
Prepending /cvmfs/pilot.eessi-hpc.org/2020.08/software/x86_64/intel/haswell/modules/all to $MODULEPATH...
Environment set up to use EESSI pilot software stack, have fun!
[EESSI pilot 2020.08] $
```

# License

The software in this repository is distributed under the terms of the
[GNU General Public License v2.0](https://opensource.org/licenses/GPL-2.0).

See [LICENSE](https://github.com/EESSI/filesystem-layer/blob/master/LICENSE) for more information.

SPDX-License-Identifier: GPL-2.0-only
