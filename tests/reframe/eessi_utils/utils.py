import re

import reframe as rfm


gpu_dev_name = 'gpu'

def _get_gpu_list(test: rfm.RegressionTest):
    return [ dev.num_devices for dev in test.current_partition.devices if dev.device_type == gpu_dev_name ]

def get_num_gpus(test: rfm.RegressionTest) -> int:
    '''Returns the number of GPUs for the current partition'''
    gpu_list = _get_gpu_list(test)
    # If multiple devices are called 'GPU' in the current partition,
    # we don't know for which to return the device count...
    if(len(gpu_list) != 1):
        raise ValueError(f"Multiple different devices exist with the name " 
                         f"'{gpu_dev_name}' for partition '{test.current_partition.name}'. "
                         f"Cannot determine number of GPUs available for the test. "
                         f"Please check the definition of partition '{test.current_partition.name}' "
                         f"in your ReFrame config file.")

    return gpu_list[0]

def is_gpu_present(test: rfm.RegressionTest) -> bool:
    '''Checks if GPUs are present in the current partition'''
    return ( len(_get_gpu_list(test)) >= 1 )

def is_cuda_required(test: rfm.RegressionTest) -> bool:
    '''Checks if CUDA seems to be required by current module'''
    requires_cuda = False
    for module in test.modules:
        if re.search("(?i)cuda", module):
            requires_cuda = True
    return requires_cuda
