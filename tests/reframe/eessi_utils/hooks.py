import reframe as rfm
import eessi_utils.utils as utils

def skip_cpu_test_on_gpu_nodes(test: rfm.RegressionTest):
    '''Skip test if GPUs are present, but no CUDA is required'''
    skip = ( utils.is_gpu_present(test) and not utils.is_cuda_required(test) )
    if skip:
        test.skip_if(True, "GPU is present on this partition (%s), skipping CPU-based test" % test.current_partition.name)

def skip_gpu_test_on_cpu_nodes(test: rfm.RegressionTest):
    '''Skip test if CUDA is required, but no GPU is present'''
    skip = ( utils.is_cuda_required(test) and not utils.is_gpu_present(test) )
    if skip:
        test.skip_if(True, "Test requires CUDA, but no GPU is present in this partition (%s). Skipping test..." % test.current_partition.name)

def auto_assign_num_tasks_MPI(test: rfm.RegressionTest, num_nodes: int) -> rfm.RegressionTest:
    '''Automatically sets num_tasks, tasks_per_node and cpus_per_task based on the current partitions num_cpus, number of GPUs and test.num_nodes. For GPU tests, one task per GPU is set, and num_cpus_per_task is based on the ratio of CPU cores/GPUs. For CPU tests, one task per CPU is set, and num_cpus_per_task is set to 1. Total task count is determined based on the number of nodes to be used in the test. Behaviour of this function is (usually) sensible for pure MPI tests.'''
    if utils.is_cuda_required(test):
        test.num_tasks_per_node = utils.get_num_gpus(test)
        test.num_cpus_per_task = int(test.current_partition.processor.num_cpus / test.num_tasks_per_node)
    else:
        test.num_tasks_per_node = test.current_partition.processor.num_cpus
        test.num_cpus_per_task = 1
    test.num_tasks = num_nodes * test.num_tasks_per_node
