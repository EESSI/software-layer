# Copyright 2016-2021 Swiss National Supercomputing Centre (CSCS/ETH Zurich)
# ReFrame Project Developers. See the top-level LICENSE file for details.
#
# SPDX-License-Identifier: BSD-3-Clause

import reframe as rfm
from reframe.utility import find_modules

from hpctestlib.sciapps.gromacs.benchmarks import gromacs_check
import eessi_utils.hooks as hooks

@rfm.simple_test
class GROMACS_EESSI(gromacs_check):

    scale = parameter([
        ('singlenode', 1),
        ('n_small', 4),
        ('n_medium', 8),
        ('n_large', 16)])
    module_info = parameter(find_modules('GROMACS', environ_mapping={r'.*': 'builtin'}))

    executable_opts += ['-dlb yes', '-ntomp 1', '-npme -1']

    @run_after('init')
    def apply_module_info(self):
        self.s, self.e, self.m = self.module_info
        self.valid_systems = [self.s]
        self.modules = [self.m]
        self.valid_prog_environs = [self.e]

    @run_after('init')
    def set_test_scale(self):
        scale_variant, self.num_nodes = self.scale
        self.tags.add(scale_variant)

    # Set correct tags for monitoring & CI
    @run_after('init')
    def set_test_purpose(self):
        # Run all tests from the testlib for monitoring
        self.tags.add('monitoring')
        # Select one test for CI
        if self.benchmark_info[0] == 'HECBioSim/hEGFRDimer':
            self.tags.add('CI')

    # Skip testing for when nb_impl=gpu and this is not a GPU node
    @run_after('setup')
    def skip_nb_impl_gpu_on_cpu_nodes(self):
        self.skip_if(
            self.nb_impl == 'gpu') and (utils.is_gpu_present(self),
            "Skipping nb_impl=gpu variant on non-GPU nodes"
        )

    # Skip testing GPU-based modules on CPU-based nodes
    @run_after('setup')
    def skip_gpu_test_on_cpu_nodes(self):
        hooks.skip_gpu_test_on_cpu_nodes(self)

    # Assign num_tasks, num_tasks_per_node and num_cpus_per_task automatically based on current partition's num_cpus and gpus
    @run_after('setup')
    def set_num_tasks(self):
        hooks.auto_assign_num_tasks_MPI(test = self, num_nodes = self.num_nodes) 

