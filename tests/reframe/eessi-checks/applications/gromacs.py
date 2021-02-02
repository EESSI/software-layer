import os
import reframe as rfm
import reframe.utility.sanity as sn

# TODO:

# - Split in GromacsBase parent class and GromacsContainer child class. Implement all generic things in Base
# - Add GromacsNative class, that doesn't run based on the container but on native CVMFS mount. Test @generoso
# - Make multiple scale variants of the container & native tests: single node, two nodes, and more (and tag with: single, small ,large)

class GromacsBase(rfm.RunOnlyRegressionTest):
    def __init__(self, nsteps):
        self.valid_systems = ['*']
        self.valid_prog_environs = ['container']

        self.prerun_cmds = ['source shared_alien_cache_minimal.sh > /dev/null']

        self.container_platform = 'Singularity'
        self.container_platform.image = 'docker://eessi/client-pilot:centos7-$(uname -m)-2020.10'
        self.container_platform.options = [
            '--fusemount "container:cvmfs2 cvmfs-config.eessi-hpc.org /cvmfs/cvmfs-config.eessi-hpc.org"',
            '--fusemount "container:cvmfs2 pilot.eessi-hpc.org /cvmfs/pilot.eessi-hpc.org"'
        ]

        self.container_platform.commands = [
            'source /cvmfs/pilot.eessi-hpc.org/2020.12/init/bash',
            'module load GROMACS',
            'which gmx_mpi',
            'gmx_mpi mdrun -s ion_channel.tpr -maxh 0.50 -resethway -noconfout -nsteps ' + nsteps
        ]

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


@rfm.parameterized_test(['single'], ['small'], ['large'])
class Gromacs(GromacsBase):
    def __init__(self, scale):
         
        if scale == 'single':
            super().__init__('10000')
            self.num_nodes = 1
        elif scale == 'small':
            super().__init__('40000')
            self.num_nodes = 4
        elif scale == 'large':
            super().__init__('100000')
            self.num_nodes = 10

        self.num_tasks = 24 * self.num_nodes
        self.num_tasks_per_node = 24
        self.tags = {scale}
