import os
import reframe as rfm
import reframe.utility.sanity as sn

# TODO:

# - Split in GromacsBase parent class and GromacsContainer child class. Implement all generic things in Base
# - Add GromacsNative class, that doesn't run based on the container but on native CVMFS mount. Test @generoso
# - Make multiple scale variants of the container & native tests: single node, two nodes, and more (and tag with: single, small ,large)

@rfm.simple_test
class Gromacs(rfm.RunOnlyRegressionTest):
    def __init__(self):
        self.valid_systems = ['*']
        self.valid_prog_environs = ['container']

        self.prerun_cmds = ['source /home/casparl/EESSI/shared_alien_cache_minimal.sh > /dev/null']

        self.container_platform = 'Singularity'
        self.container_platform.image = 'docker://eessi/client-pilot:centos7-$(uname -m)-2020.10'
        self.container_platform.options = [
            '--fusemount "container:cvmfs2 cvmfs-config.eessi-hpc.org /cvmfs/cvmfs-config.eessi-hpc.org"',
            '--fusemount "container:cvmfs2 pilot.eessi-hpc.org /cvmfs/pilot.eessi-hpc.org"'
        ]
#        self.container_platform.mount_points = [
#            ("$TMPDIR/var-run-cvmfs", "/var/run/cvmfs"),
#            ("$TMPDIR/var-lib-cvmfs", "/var/lib/cvmfs")
#        ]
        self.container_platform.commands = [
            'source /cvmfs/pilot.eessi-hpc.org/2020.12/init/bash',
            'module load GROMACS',
            'which gmx_mpi',
            'gmx_mpi mdrun -s ion_channel.tpr -maxh 0.50 -resethway -noconfout -nsteps 1000'
        ]

#        self.executable = 'gmx_mpi'
#        self.executable_opts = ['mdrun', '-s ion_channel.tpr', '-maxh 0.50', '-resethway', '-noconfout', '-nsteps 1000']

#        self.sourcepath = 'mpi_hello_world.c'

        output_file = 'md.log'
        energy = sn.extractsingle(r'\s+Coul\. recip\.\s+Potential\s+Kinetic En\.\s+Total Energy\s+Conserved En.\n'
                                  r'(\s+\S+){3}\s+(?P<energy>\S+)(\s+\S+){1}\n',
                                  output_file, 'energy', float, item=-1)
        energy_reference = -1509290.0

        self.sanity_patterns = sn.all([
            sn.assert_found('Finished mdrun', output_file),
            sn.assert_reference(energy, energy_reference, -0.001, 0.001)
        ])

        self.maintainers = ['casparvl']
        self.num_tasks = 16
#       self.num_tasks_per_node = system_properties.ncorespernode
        self.num_tasks_per_node = 16
