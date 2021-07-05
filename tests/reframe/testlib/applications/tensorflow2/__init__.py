import os
import reframe as rfm
import reframe.utility.sanity as sn

class TensorFlow2(rfm.RunOnlyRegressionTest, pin_prefix=True):

    num_tasks = required
    num_tasks_per_node = required
    num_cpus_per_task = required

    # Can be 'gpu' or 'cpu'
    device = variable(str)
    batch_size = variable(int, value = 32) # Smaller batch sizes may be used if running out of memory

    # For multinode runs, Horovod is used. Horovod may perform better on CPU if one thread is left idle
    # See https://github.com/horovod/horovod/issues/2804
    omp_num_threads = variable(int)

    descr = 'TensorFlow 2 synthetic benchmark'
    executable = 'python'
    script = 'tensorflow2_synthetic_benchmark.py'
    model = 'ResNet50'

    maintainers = ['casparvl']

    @run_before('performance')
    def set_reference(self):
        self.reference = {
            '*': {
                'throughput': (None, None, None, 'img/sec'),
                f'throughput_per_{self.device}': (None, None, None, 'img/sec')
            }
        }

    @run_before('run')
    def set_executable_opts(self):
        '''Set the executable opts, with correct batch_size'''
        self.executable_opts = [
            f'{self.script}',
            f'--model {self.model}',
            f'--batch-size {self.batch_size}',
            '--num-iters 2',
            '--num-batches-per-iter 2',
            '--num-warmup-batches 1',
        ]
        if self.device == 'cpu':
            self.executable_opts.append('--no-cuda')
        # Use horovod for parallelism
        if self.num_tasks > 1:
            self.executable_opts.append('--use-horovod')

    @run_before('run')
    def set_omp_num_threads_env(self):
        self.variables = {
            'OMP_NUM_THREADS': f'{self.omp_num_threads}',
        }
        if self.current_partition.launcher_type == 'mpirun':
            self.job.launcher.options = ['-x OMP_NUM_THREADS']

    @sn.sanity_function
    def get_throughput(self):
        throughput_sn = sn.extractsingle(
            rf'Total img\/sec on [0-9]+ {self.device.upper()}\(s\): '
            rf'(?P<throughput>\S+) \S+',
            self.stdout, 'throughput', float)
        return throughput_sn

    @sn.sanity_function
    def get_throughput_per_dev(self):
        throughput_dev_sn = sn.extractsingle(
            rf'Img\/sec per {self.device.upper()}: '
            rf'(?P<throughput>\S+) \S+',
            self.stdout, 'throughput', float)
        return throughput_dev_sn

    @run_before('sanity')
    def set_sanity_patterns(self):
        self.sanity_patterns = sn.all([
            sn.assert_found('Benchmark completed', self.stdout),
        ])

    @run_before('performance')
    def set_perf_patterns(self):
        self.perf_patterns = {
            'throughput': self.get_throughput(),
            f'throughput_per_{self.device}': self.get_throughput_per_dev()
        }

