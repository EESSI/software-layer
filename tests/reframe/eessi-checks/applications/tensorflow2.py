import os
import reframe as rfm
from reframe.utility import find_modules

from testlib.applications.tensorflow2 import TensorFlow2
import eessi_utils.hooks as hooks
import eessi_utils.utils as utils

@rfm.required_version('>=3.6.2')
@rfm.simple_test
class TensorFlow2_EESSI(TensorFlow2):
    '''EESSI TensorFlow 2 check, for pure TensorFlow. This test does not support running on multiple nodes'''

    modules = required # Make sure that our apply_module_info hook sets a value
    module_info = parameter(find_modules('TensorFlow', environ_mapping={r'.*': 'builtin'}))
    # This test is singlenode and should be run in CI
    tags = {'singlenode', 'CI'}

    @run_after('init')
    def apply_module_info(self):
        hooks.apply_module_info(test = self, module_info = self.module_info)

    # Skip testing GPU-based modules on CPU-based nodes
    @run_after('setup')
    def skip_gpu_test_on_cpu_nodes(self):
        hooks.skip_gpu_test_on_cpu_nodes(self)

    # Skip testing with device == gpu on CPU based nodes
    @run_after('setup')
    def skip_device_gpu_on_cpu_nodes(self):
        self.skip_if(
            (self.device == 'gpu' and not utils.is_gpu_present(self)),
            "Skipping test variant where tf.device is GPU, since this partition contains non-GPU nodes"
        )

    # This test uses only OpenMP for parallelism, so simply run on all cores
    @run_after('setup')
    def set_num_tasks(self):
        self.num_tasks = 1
        self.num_tasks_per_node = 1
        self.num_cpus_per_task = self.current_partition.processor.num_cpus
        self.omp_num_threads = self.num_cpus_per_task

    @run_before('run')
    def bind_to_none(self):
        hooks.bind_to_none(self)

@rfm.required_version('>=3.6.2')
@rfm.simple_test
class TensorFlow2_Horovod_EESSI(TensorFlow2):
    '''EESSI TensorFlow 2 check, with multiprocessing support through Horovod.
    This test will run TensorFlow2 using all modules with 'TensorFlow' in the module environment it can find.
    On GPU nodes, it will only run tests if the module names also contain 'cuda'.
    On CPU nodes, it will only run tests if a module name does NOT contain 'cuda'.
    Whether a node is CPU/GPU is determined based on if a device named 'gpu' is specified in the ReFrame settings file for the current partition.
    Number of tasks, tasks per node and cpus per task are set based on the number of GPUs and number of CPUs specified in the ReFrame config file for the current partition.
    When using multiple CPU nodes, the number of OMP_NUM_THREADS is set to the core count minus 1, to leave one dedicated thread for Horovod.
    '''

    modules = required # Make sure that our apply_module_info hook sets a value
    scale = parameter([
        ('singlenode', 1),
        ('n_small', 2),
        ('n_medium', 8),
        ('n_large', 16)
    ])
    module_info = parameter(find_modules('Horovod', environ_mapping={r'.*': 'builtin'}))

    @run_after('init')
    def apply_module_info(self):
        hooks.apply_module_info(test = self, module_info = self.module_info)

    @run_after('init')
    def set_test_scale(self):
        scale_variant, self.num_nodes = self.scale
        self.tags.add(scale_variant)

    # Skip testing GPU-based modules on CPU-based nodes
    @run_after('setup')
    def skip_gpu_test_on_cpu_nodes(self):
        hooks.skip_gpu_test_on_cpu_nodes(self)

    # Skip testing with device == gpu on CPU based nodes
    @run_after('setup')
    def skip_device_gpu_on_cpu_nodes(self):
        self.skip_if(
            (self.device == 'gpu' and not utils.is_gpu_present(self)),
            "Skipping test variant where tf.device is GPU, since this partition contains non-GPU nodes"
        )

    # Skip testing CPU-based modules on GPU-based nodes
    # (though these would run fine, one is usually not interested in them)
    @run_after('setup')
    def skip_cpu_test_on_gpu_nodes(self):
       hooks.skip_cpu_test_on_gpu_nodes(self)

    # Assign num_tasks, num_tasks_per_node and num_cpus_per_task automatically based on current partition's num_cpus and gpus
    @run_after('setup')
    def set_num_tasks(self):
        hooks.auto_assign_num_tasks_hybrid(test = self, num_nodes = self.num_nodes)

    @run_after('setup')
    def set_omp_num_threads(self):
        # For CPU runs on more than 4 cores, leave one thread idle for Horovod
        if self.device == 'cpu' and self.num_cpus_per_task > 4:
            self.omp_num_threads = self.num_cpus_per_task - 1
        else:
            self.omp_num_threads = self.num_cpus_per_task
        print("Set omp_num_threads to: %s" % self.omp_num_threads)

