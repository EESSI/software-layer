import reframe as rfm
import eessi_utils.utils as utils
from typing import Tuple

def apply_module_info(test: rfm.RegressionTest, module_info: Tuple[str, str, str]):
    '''Apply module info that was obtained with a find_modules.
    To work with this hook, module_info should store the return of parameter(find_modules(...))'''
    sys, env, mod = module_info
    test.valid_systems = [sys]
    test.modules = [mod]
    test.valid_prog_environs = [env]

def skip_cpu_test_on_gpu_nodes(test: rfm.RegressionTest):
    '''Skip test if GPUs are present, but no CUDA is required'''
    skip = ( utils.is_gpu_present(test) and not utils.is_cuda_required(test) )
    if skip:
        print("GPU is present on this partition, skipping CPU-based test")
        test.skip_if(True)

def skip_gpu_test_on_cpu_nodes(test: rfm.RegressionTest):
    '''Skip test if CUDA is required, but no GPU is present'''
    skip = ( utils.is_cuda_required(test) and not utils.is_gpu_present(test) )
    if skip:
        print("Test requires CUDA, but no GPU is present in this partition. Skipping test...")
        test.skip_if(True)

def auto_assign_num_tasks_MPI(test: rfm.RegressionTest, num_nodes: int) -> rfm.RegressionTest:
    '''Automatically sets num_tasks, tasks_per_node and cpus_per_task based on the current partitions num_cpus, number of GPUs and test.num_nodes. For GPU tests, one task per GPU is set, and num_cpus_per_task is based on the ratio of CPU cores/GPUs. For CPU tests, one task per CPU is set, and num_cpus_per_task is set to 1. Total task count is determined based on the number of nodes to be used in the test. Behaviour of this function is (usually) sensible for pure MPI tests.'''
    if utils.is_cuda_required(test):
        test.num_tasks_per_node = utils.get_num_gpus(test)
        test.num_cpus_per_task = int(test.current_partition.processor.num_cpus / test.num_tasks_per_node)
    else:
        test.num_tasks_per_node = test.current_partition.processor.num_cpus
        test.num_cpus_per_task = 1
    test.num_tasks = num_nodes * test.num_tasks_per_node

def auto_assign_num_tasks_hybrid(test: rfm.RegressionTest, num_nodes: int) -> rfm.RegressionTest:
    '''Automatically sets num_tasks, tasks_per_node and cpus_per_task based on the current partitions num_cpus, num_sockets, number of GPUs and test.num_nodes. For GPU tests, one task per GPU is set, and num_cpus_per_task is based on the ratio of CPU cores/GPUs. For CPU tests, one task per CPU socket is set, and num_cpus_per_task is set to #CPU cores / #sockets. Total task count is determined based on the number of nodes to be used in the test. Behaviour of this function is (usually) sensible for hybrid OpenMP-MPI tests. For sockets with very large core counts (i.e. where OpenMP cannot exploit sufficient parallelism), this approach may be inefficient and more than 1 task per socket may be desirable.'''
    if utils.is_cuda_required(test):
        test.num_tasks_per_node = utils.get_num_gpus(test)
        test.num_cpus_per_task = int(test.current_partition.processor.num_cpus / test.num_tasks_per_node)
    else:
        test.num_tasks_per_node = test.current_partition.processor.num_sockets
        test.num_cpus_per_task = test.current_partition.processor.num_cpus_per_socket
    test.num_tasks = num_nodes * test.num_tasks_per_node
