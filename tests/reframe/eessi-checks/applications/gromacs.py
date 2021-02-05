import os
import reframe as rfm
import reframe.utility.sanity as sn

class GromacsBase(rfm.RunOnlyRegressionTest):
    def __init__(self):
        self.valid_systems = ['*']

        output_file = 'md.log'
        energy = sn.extractsingle(r'\s+Coul\. recip\.\s+Potential\s+Kinetic En\.\s+Total Energy\s+Conserved En.\n'
                                  r'(\s+\S+){3}\s+(?P<energy>\S+)(\s+\S+){1}\n',
                                  output_file, 'energy', float, item=-1)
        energy_reference = -1509290.0

        self.sanity_patterns = sn.all([
            sn.assert_found('Finished mdrun', output_file),
            sn.assert_reference(energy, energy_reference, -0.001, 0.001)
        ])

        self.perf_patterns = {
            'perf': sn.extractsingle(r'Performance:\s+(?P<perf>\S+)',
                                     output_file, 'perf', float)
        }
        self.reference = {
            '*': {
                'perf': (None, None, None, 'ns/day')
            }
        }

        self.tags = {'cpu'}

        self.maintainers = ['casparvl']

class GromacsSizedTests(GromacsBase):
    def __init__(self, scale):

        super().__init__()

        if scale == 'singlenode':
            self.nsteps = '10000'
            self.num_nodes = 1
        elif scale == 'small':
            self.nsteps = '40000'
            self.num_nodes = 4
        elif scale == 'large':
            self.nsteps = '100000'
            self.num_nodes = 10

        self.num_tasks_per_node = 16
        self.num_tasks = self.num_tasks_per_node * self.num_nodes
        self.tags.add(scale)


@rfm.parameterized_test(['singlenode'], ['small'], ['large'])
class GromacsNative(GromacsSizedTests):
    def __init__(self, scale):

        super().__init__(scale)

        self.tags.add('native')
        self.valid_prog_environs = ['*']

        self.modules = ['GROMACS']
        self.executable = 'gmx_mpi'
        self.executable_opts = ['mdrun', '-s ion_channel.tpr', '-maxh 0.50',
                '-resethway', '-noconfout', '-nsteps ' + self.nsteps]

@rfm.parameterized_test(['single'], ['small'], ['large'])
class GromacsContainer(GromacsSizedTests):
    def __init__(self, scale):

        super().__init__(scale)

        self.tags.add('container')
        self.valid_prog_environs = ['container']

        self.prerun_cmds = ['source shared_alien_cache_minimal.sh > /dev/null']

        self.container_platform = 'Singularity'
        self.container_platform.image = 'docker://eessi/client-pilot:centos7-$(uname -m)'
        self.container_platform.options = [
            '--fusemount "container:cvmfs2 cvmfs-config.eessi-hpc.org /cvmfs/cvmfs-config.eessi-hpc.org"',
            '--fusemount "container:cvmfs2 pilot.eessi-hpc.org /cvmfs/pilot.eessi-hpc.org"'
        ]

        self.container_platform.commands = [
            'source /cvmfs/pilot.eessi-hpc.org/latest/init/bash',
            'module load GROMACS',
            'which gmx_mpi',
            'gmx_mpi mdrun -s ion_channel.tpr -maxh 0.50 -resethway -noconfout -nsteps ' + self.nsteps
        ]
