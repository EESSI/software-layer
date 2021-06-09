import re
import reframe as rfm
from reframe.utility import find_modules

from testlib.applications.gromacs import Gromacs

@rfm.required_version('>=3.5.0')
@rfm.simple_test
class Gromacs_EESSI(Gromacs):
    '''EESSI Gromacs check.
    This test will run GROMACS using all modules with 'GROMACS' in the module environment it can find.
    On GPU nodes, it will only run tests if module names also contain 'cuda'.
    On CPU nodes, it will only run tests if a module name does NOT contain 'cuda'.
    Whether a nodes is CPU/GPU is determined based on if a device named 'gpu' is specified in the ReFrame settings file for the current partition.
    Number of tasks, tasks per node and cpus per task are set based on the number of GPUs and number of CPUs specified in the ReFrame config file for the current partition. 
    '''

    scale = parameter(['singlenode', 'small', 'large'])
    module_info = parameter(find_modules('GROMACS', environ_mapping={r'.*': 'builtin'}))

    @rfm.run_after('init')
    def apply_module_info(self):
        self.s, self.e, self.m = self.module_info
        self.valid_systems = [self.s]
        self.modules = [self.m]
        self.valid_prog_environs = [self.e]

    @rfm.run_after('init')
    def set_test_scale(self):
        if self.scale == 'singlenode':
            self.nsteps = 10000
            self.num_nodes = 1
        elif self.scale == 'small':
            self.nsteps = 40000
            self.num_nodes = 4
        elif self.scale == 'large':
            self.nsteps = 100000
            self.num_nodes = 10
        self.tags.add(self.scale)

    @rfm.run_after('init')
    def requires_gpu(self):
        self.requires_cuda = False
        if re.search("(?i)cuda", self.m) is not None:
            self.requires_cuda = True

    @rfm.run_after('setup')
    def check_gpu_presence(self):
        self.gpu_list = [ dev.num_devices for dev in self.current_partition.devices if dev.device_type == 'gpu' ]

    # Skip testing GPU-based modules on CPU-based nodes
    @rfm.run_after('setup')
    def skip_gpu_test_on_cpu_nodes(self):
        skip = (self.requires_cuda and (len(self.gpu_list) == 0))
        if skip:
            print("Test requires CUDA, but no GPU is present in this partition. Skipping test...")
            self.skip_if(True)

    # Skip testing CPU-based modules on GPU-based nodes
    # (though these would run fine, one is usually not interested in them)
    @rfm.run_after('setup')
    def skip_cpu_tests_on_gpu_nodes(self):
        skip = ((len(self.gpu_list) >= 1) and not self.requires_cuda)
        if skip:
            print("GPU is present on this partition, skipping CPU-based test")
            self.skip_if(True)

    @rfm.run_after('setup')
    def set_num_tasks(self):
        if self.requires_cuda:
            # Test doesn't know what to do if multiple DIFFERENT GPU devices are present in a single ReFrame (virtual) partition
            assert(len(self.gpu_list) == 1)
            self.num_tasks_per_node = self.gpu_list[0]
            self.num_cpus_per_task = int(self.current_partition.processor.num_cpus / self.num_tasks_per_node)
        else:
            self.num_tasks_per_node = self.current_partition.processor.num_cpus
            self.num_cpus_per_task = 1
        self.num_tasks = self.num_nodes * self.num_tasks_per_node
