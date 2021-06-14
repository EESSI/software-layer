import os
import reframe as rfm
import reframe.utility.sanity as sn

# 3.5.0 Required for using current_partition.processor
#@rfm.required_version('>=3.5.0')
class Gromacs(rfm.RunOnlyRegressionTest, pin_prefix=True):
    '''Gromacs benchmark based on Prace Benchmark Suite GROMACS case A.

    Derived tests must specify the variables ``num_tasks``, ``num_tasks_per_node``, ``num_cpus_per_task``, ``nsteps`` and ``modules``.
    Note that a sufficiently large ``nsteps`` needs to be defined in order for GROMACS to pass the load balancing phase.
    As a rough estimate: 10000 steps would generally be ok for 24 tasks, a 100000 steps for 240 tasks, etc.
    '''

    num_tasks = required
    num_tasks_per_node = required
    num_cpus_per_task = required
    nsteps = variable(int)

    descr = 'GROMACS Prace Benchmark Suite case A'
    use_multithreading = False
    executable = 'gmx_mpi'
    output_file = 'md.log'
    energy_reference = -1509290.0
    reference = {
        '*': {
            'perf': (None, None, None, 'ns/day')
        }
    }
    maintainers = ['casparvl']

    @run_before('run')
    def set_executable_opts(self):
        '''Set the executable opts, with correct nsteps'''
        self.executable_opts = ['mdrun', '-s ion_channel.tpr', '-maxh 0.50',
                '-resethway', '-noconfout', '-nsteps %s ' % self.nsteps]

    @run_before('run')
    def set_omp_num_threads(self):
        self.variables = {
            'OMP_NUM_THREADS': f'{self.num_cpus_per_task}',
    }

    @run_before('performance')
    def set_perf_patterns(self):
        '''Set the perf patterns to report'''
        self.perf_patterns = {
            'perf': sn.extractsingle(r'Performance:\s+(?P<perf>\S+)',
                                     self.output_file, 'perf', float)
        }

    @sn.sanity_function
    def get_energy(self):
        return sn.extractsingle(r'\s+Coul\. recip\.\s+Potential\s+Kinetic En\.\s+Total Energy\s+Conserved En.\n'
                                  r'(\s+\S+){3}\s+(?P<energy>\S+)(\s+\S+){1}\n',
                                  self.output_file, 'energy', float, item=-1)

    @run_before('sanity')
    def set_sanity_patterns(self):
        self.sanity_patterns = sn.all([
            sn.assert_found('Finished mdrun', self.output_file,
                            msg = "Run seems to not have finished succesfully"),
            sn.assert_reference(self.get_energy(), self.energy_reference, -0.001, 0.001,
                                msg = "Final energy reference not within expected limits")
        ])

