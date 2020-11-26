import re
import reframe as rfm
from reframe.utility import find_modules

from testlib.applications.gromacs import Gromacs
import eessi_utils.hooks as hooks

@rfm.required_version('>=3.6.2')
@rfm.simple_test
class Gromacs_EESSI(Gromacs):
    '''EESSI Gromacs check.
    This test will run GROMACS using all modules with 'GROMACS' in the module environment it can find.
    On GPU nodes, it will only run tests if module names also contain 'cuda'.
    On CPU nodes, it will only run tests if a module name does NOT contain 'cuda'.
    Whether a nodes is CPU/GPU is determined based on if a device named 'gpu' is specified in the ReFrame settings file for the current partition.
    Number of tasks, tasks per node and cpus per task are set based on the number of GPUs and number of CPUs specified in the ReFrame config file for the current partition. 
    '''

    modules = required # Make sure that our apply_module_info hook sets a value
    scale = parameter([
        ('singlenode', 10000, 1),
        ('small', 40000, 4),
        ('large', 100000, 10)])
    module_info = parameter(find_modules('GROMACS', environ_mapping={r'.*': 'builtin'}))

    @run_after('init')
    def apply_module_info(self):
        self.s, self.e, self.m = self.module_info
        self.valid_systems = [self.s]
        self.modules = [self.m]
        self.valid_prog_environs = [self.e]

    @run_after('init')
    def set_test_scale(self):
        scale_variant, self.nsteps, self.num_nodes = self.scale
        self.tags.add(scale_variant)

    # Skip testing GPU-based modules on CPU-based nodes
    @run_after('setup')
    def skip_gpu_test_on_cpu_nodes(self):
        hooks.skip_gpu_test_on_cpu_nodes(self)

    # Skip testing CPU-based modules on GPU-based nodes
    # (though these would run fine, one is usually not interested in them)
    @run_after('setup')
    def skip_cpu_test_on_gpu_nodes(self):
       hooks.skip_cpu_test_on_gpu_nodes(self)

    # Assign num_tasks, num_tasks_per_node and num_cpus_per_task automatically based on current partition's num_cpus and gpus
    @run_after('setup')
    def set_num_tasks(self):
        hooks.auto_assign_num_tasks_MPI(test = self, num_nodes = self.num_nodes)

