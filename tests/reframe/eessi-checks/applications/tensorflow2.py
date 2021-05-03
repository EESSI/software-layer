# This TensorFlow2 test is intended for single node, single GPU only
# For multigpu and multinode tests, we use Horovod

import os
import reframe as rfm
import reframe.utility.sanity as sn

class TensorFlow2Base(rfm.RunOnlyRegressionTest):

    device = parameter(['cpu', 'gpu'])

    def __init__(self):
        self.valid_systems = ['*']

        self.script = 'tensorflow2_synthetic_benchmark.py'
        self.model = 'ResNet50'
        self.batch_size = 32

        self.sanity_patterns = sn.all([
            sn.assert_found('Benchmark completed', self.stdout),
        ])

        self.perf_patterns = {
            'throughput': sn.extractsingle(
                rf'Total img\/sec on [0-9]+ {self.device.upper()}\(s\): '
                rf'(?P<throughput>\S+) \S+',
                self.stdout, 'throughput', float),
            f'throughput_per_{self.device}': sn.extractsingle(
                rf'Img\/sec per {self.device.upper()}: (?P<throughput_per_{self.device}>\S+) \S+',
                self.stdout, f'throughput_per_{self.device}', float)
        }
        self.reference = {
            '*': {
                'throughput': (None, None, None, 'img/sec'),
                f'throughput_per_{self.device}': (None, None, None, 'img/sec')
            }
        }

        self.tags = {f'{self.device}'}

        self.maintainers = ['casparvl']


@rfm.simple_test
class TensorFlow2Native(TensorFlow2Base):
    def __init__(self):
        super().__init__()

        self.descr = 'TensorFlow 2.X single gpu test. Based on the Horovod tensorflow2_synthetic_benchmark.py example.'

        self.tags.add('native')
        self.valid_prog_environs = ['*']

        self.modules = ['TensorFlow']
        self.executable = 'python'

        self.executable_opts = [
            f'{self.script}',
            f'--model {self.model}',
            f'--batch-size {self.batch_size}',
            '--num-iters 5',
            '--num-batches-per-iter 5',
            '--num-warmup-batches 5',
        ]
        if self.device == 'cpu':
            self.executable_opts.append('--no-cuda')

        self.num_nodes = 1
        self.num_tasks_per_node = 1

        self.tags.add('singlenode')

    # Set OMP_NUM_THREADS based on current partition properties
    @rfm.run_before('run')
    def set_num_threads(self):
        self.num_cpus_per_task = int(self.current_partition.processor.num_cpus / self.num_tasks_per_node)
        self.variables = {
            'OMP_NUM_THREADS': f'{self.num_cpus_per_task}',
        }
        if self.current_partition.launcher_type == 'mpirun':
            self.job.launcher.options = ['-x OMP_NUM_THREADS']

class HorovodTensorFlow2Base(TensorFlow2Base):

    scale = parameter(['singlenode', 'small', 'large'])

    def __init__(self):
        super().__init__()

        if self.scale == 'singlenode':
            self.num_nodes = 1
        elif self.scale == 'small':
            self.num_nodes = 4
        elif self.scale == 'large':
            self.num_nodes = 10
        self.tags.add(self.scale)

    # Set number of tasks and threads (OMP_NUM_THREADS) based on current partition properties
    @rfm.run_before('run')
    def set_num_tasks(self):
        # On CPU nodes, start 1 task per node. On GPU nodes, start 1 task per GPU.
        if self.device == 'cpu':
            # For now, keep it simple.
            # In the future, we may want to launch 1 task per socket,
            # and bind these tasks to their respective sockets.
            self.num_tasks_per_node = 1
        elif self.device == 'gpu':
            device_count = [ dev.num_devices for dev in self.current_partition.devices if dev.device_type == 'gpu' ]
            # This test doesn't know what to do if multiple DIFFERENT GPU devices are present in a single partition, so assert that we only found one in the ReFrame config:
            assert(len(device_count) == 1)
            self.num_tasks_per_node = device_count[0]
            # On some resource schedules, you may need to request GPUs explicitely (e.g. --gpus-per-node=4).
            # The extra_resources allows that to be put in the ReFrame settings file.
            # See: https://reframe-hpc.readthedocs.io/en/stable/regression_test_api.html?highlight=num_gpus_per_node#reframe.core.pipeline.RegressionTest.extra_resources
            # If the partition in the reframe settings file doesn't contain a resource with the name 'gpu', the self.extra_resources wil be ignored.
            self.extra_resources = {
                'gpu': {'num_gpus_per_node': device_count[0]}
            }
        self.num_tasks = self.num_tasks_per_node * self.num_nodes
        self.num_cpus_per_task = int(self.current_partition.processor.num_cpus / self.num_tasks_per_node)
        # If test runs on CPU, leave one thread idle for Horovod. See https://github.com/horovod/horovod/issues/2804
        if self.device == 'cpu': 
            num_threads = max(self.num_cpus_per_task-1, 1)
        elif self.device == 'gpu':
            num_threads = self.num_cpus_per_task
        self.variables = {
            'OMP_NUM_THREADS': f'{num_threads}',
        }
        if self.current_partition.launcher_type == 'mpirun':
            self.job.launcher.options = ['-x OMP_NUM_THREADS']


@rfm.simple_test
class HorovodTensorFlow2Native(HorovodTensorFlow2Base):

    def __init__(self):
        super().__init__()

        self.descr = 'TensorFlow 2.X with Horovod multi-node and multi-GPU test. Based on the Horovod tensorflow2_synthetic_benchmark.py example.'

        self.tags.add('native')
        self.valid_prog_environs = ['*']

        self.modules = ['Horovod']
        self.executable = 'python'

        self.executable_opts = [
            f'{self.script}',
            f'--model {self.model}',
            f'--batch-size {self.batch_size}',
            '--num-iters 5',
            '--num-batches-per-iter 5',
            '--num-warmup-batches 5',
            '--use-horovod',
        ]
        if self.device == 'cpu':
            self.executable_opts.append('--no-cuda')


# @rfm.parametrized_test(['cpu'], ['gpu'])
# class TensorFlow2Container(TensorFlow2Base):
#     def __init__(self, device):
#         super().__init__(device)
#
#         self.tags.add('container')
#         self.valid_prog_environs = ['*']
#
#         self.prerun_cmds = ['source shared_alien_cache_minimal.sh > /dev/null']
#
#         self.container_platform = 'Singularity'
#         self.container_platform.image = 'docker://eessi/client-pilot:centos7-$(uname -m)'
#         self.container_platform.options = [
#             '--fusemount "container:cvmfs2 cvmfs-config.eessi-hpc.org /cvmfs/cvmfs-config.eessi-hpc.org"',
#             '--fusemount "container:cvmfs2 pilot.eessi-hpc.org /cvmfs/pilot.eessi-hpc.org"'
#         ]
#
#         self.container_platform.commands = [
#             'source /cvmfs/pilot.eessi-hpc.org/latest/init/bash',
#             'module load TensorFlow',
#             'python {self.script} --model {self.model} --batch-size {self.batch_size} --num-iters 5 --num-batches-per-iter 5 --num-warmup-batches 5'
#         ]
#         self.tags.add('singlenode')
