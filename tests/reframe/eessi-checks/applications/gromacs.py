import reframe as rfm
from reframe.utility import find_modules

from testlib.applications.gromacs import Gromacs

# TODO: we use the programming environment as a surrogate for selecting the partitions
# that have e.g. GPU support (since they have fosscuda as valid programming env).
# We'd like to set valid_prog_environs to builtin and use another selection mechanism
# such as by specifying which resources are required from the current_partition
#find_modules_partial = functools.partial(find_modules, environ_mapping={
#    r'.*-foss-.*': 'foss',
#    r'.*-fosscuda-.*': 'fosscuda',
#})

@rfm.required_version('>=3.5.0')
@rfm.simple_test
class Gromacs_EESSI(Gromacs):
    '''EESSI Gromacs check'''

    scale = parameter(['singlenode', 'small', 'large'])
    module_info = parameter(find_modules('GROMACS', environ_mapping={r'.*': 'builtin'}))

    valid_systems = ['*']

    @rfm.run_after('init')
    def apply_module_info(self):
        s, e, m = self.module_info
        self.modules = [m]
        self.valid_prog_environs = [e]

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

    @rfm.run_after('setup')
    def set_num_tasks(self):
        self.num_tasks_per_node = self.current_partition.processor.num_cpus
        self.num_tasks = self.num_nodes * self.num_tasks_per_node

    @rfm.run_after('setup')
    def skip_if_no_gpu(self):
        device_count = [ dev.num_devices for dev in self.current_partition.devices if dev.device_type == 'gpu' ]
        loaded_modules = self.current_system.modules_system.loaded_modules()
        print(f"loaded_modules: {loaded_modules}")
        self.skip_if(device_count == 0)
