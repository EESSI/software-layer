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
        ('small', 4),
        ('large', 10)])
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

#    @run_after('init')
#    def set_test_scale(self):
#        scale_variant, self.num_nodes = self.scale
#        self.tags.add(scale_variant)

#     modules = ['GROMACS']
#     maintainers = ['VH', 'VK']
#     use_multithreading = False
#     extra_resources = {
#         'switches': {
#             'num_switches': 1
#         }
#     }
#     executable_opts += ['-dlb yes', '-ntomp 1', '-npme -1']
#     valid_prog_environs = ['builtin']
# 
#     # CSCS-specific parameterization
#     num_nodes = parameter([1, 2, 4, 6, 8, 16])
#     allref = {
#         1: {
#             'sm_60': {
#                 'HECBioSim/Crambin': (195.0, None, None, 'ns/day'),
#                 'HECBioSim/Glutamine-Binding-Protein': (78.0, None, None, 'ns/day'),   # noqa: E501
#                 'HECBioSim/hEGFRDimer': (8.5, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerSmallerPL': (9.2, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerPair': (3.0, None, None, 'ns/day'),
#             },
#             'broadwell': {
#                 'HECBioSim/Crambin': (116.0, None, None, 'ns/day'),
#                 'HECBioSim/Glutamine-Binding-Protein': (38.0, None, None, 'ns/day'),   # noqa: E501
#                 'HECBioSim/hEGFRDimer': (4.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerSmallerPL': (8.0, None, None, 'ns/day'),
#             },
#             'zen2': {
#                 'HECBioSim/Crambin': (320.0, None, None, 'ns/day'),
#                 'HECBioSim/Glutamine-Binding-Protein': (120.0, None, None, 'ns/day'),  # noqa: E501
#                 'HECBioSim/hEGFRDimer': (16.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerSmallerPL': (31.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerPair': (7.0, None, None, 'ns/day'),
#             },
#         },
#         2: {
#             'sm_60': {
#                 'HECBioSim/Crambin': (202.0, None, None, 'ns/day'),
#                 'HECBioSim/Glutamine-Binding-Protein': (111.0, None, None, 'ns/day'),  # noqa: E501
#                 'HECBioSim/hEGFRDimer': (15.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerSmallerPL': (18.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerPair': (6.0, None, None, 'ns/day'),
#             },
#             'broadwell': {
#                 'HECBioSim/Crambin': (200.0, None, None, 'ns/day'),
#                 'HECBioSim/Glutamine-Binding-Protein': (65.0, None, None, 'ns/day'),  # noqa: E501
#                 'HECBioSim/hEGFRDimer': (8.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerSmallerPL': (13.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerPair': (4.0, None, None, 'ns/day'),
#             },
#             'zen2': {
#                 'HECBioSim/Crambin': (355.0, None, None, 'ns/day'),
#                 'HECBioSim/Glutamine-Binding-Protein': (210.0, None, None, 'ns/day'),  # noqa: E501
#                 'HECBioSim/hEGFRDimer': (31.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerSmallerPL': (53.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerPair': (13.0, None, None, 'ns/day'),
#             },
#         },
#         4: {
#             'sm_60': {
#                 'HECBioSim/Crambin': (200.0, None, None, 'ns/day'),
#                 'HECBioSim/Glutamine-Binding-Protein': (133.0, None, None, 'ns/day'),  # noqa: E501
#                 'HECBioSim/hEGFRDimer': (22.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerSmallerPL': (28.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerPair': (10.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRtetramerPair': (5.0, None, None, 'ns/day'),
#             },
#             'broadwell': {
#                 'HECBioSim/Crambin': (260.0, None, None, 'ns/day'),
#                 'HECBioSim/Glutamine-Binding-Protein': (111.0, None, None, 'ns/day'),  # noqa: E501
#                 'HECBioSim/hEGFRDimer': (15.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerSmallerPL': (23.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerPair': (7.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRtetramerPair': (3.0, None, None, 'ns/day'),
#             },
#             'zen2': {
#                 'HECBioSim/Crambin': (340.0, None, None, 'ns/day'),
#                 'HECBioSim/Glutamine-Binding-Protein': (230.0, None, None, 'ns/day'),  # noqa: E501
#                 'HECBioSim/hEGFRDimer': (56.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerSmallerPL': (80.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerPair': (25.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRtetramerPair': (11.0, None, None, 'ns/day'),
#             },
#         },
#         6: {
#             'sm_60': {
#                 'HECBioSim/Crambin': (213.0, None, None, 'ns/day'),
#                 'HECBioSim/Glutamine-Binding-Protein': (142.0, None, None, 'ns/day'),  # noqa: E501
#                 'HECBioSim/hEGFRDimer': (28.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerSmallerPL': (35.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerPair': (13.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRtetramerPair': (8.0, None, None, 'ns/day'),
#             },
#             'broadwell': {
#                 'HECBioSim/Crambin': (308.0, None, None, 'ns/day'),
#                 'HECBioSim/Glutamine-Binding-Protein': (127.0, None, None, 'ns/day'),  # noqa: E501
#                 'HECBioSim/hEGFRDimer': (22.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerSmallerPL': (29.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerPair': (9.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRtetramerPair': (5.0, None, None, 'ns/day'),
#             },
#             'zen2': {
#                 'HECBioSim/Glutamine-Binding-Protein': (240.0, None, None, 'ns/day'),  # noqa: E501
#                 'HECBioSim/hEGFRDimer': (75.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerSmallerPL': (110.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerPair': (33.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRtetramerPair': (13.0, None, None, 'ns/day'),
#             },
#         },
#         8: {
#             'sm_60': {
#                 'HECBioSim/Crambin': (206.0, None, None, 'ns/day'),
#                 'HECBioSim/Glutamine-Binding-Protein': (149.0, None, None, 'ns/day'),  # noqa: E501
#                 'HECBioSim/hEGFRDimer': (37.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerSmallerPL': (39.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerPair': (16.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRtetramerPair': (9.0, None, None, 'ns/day'),
#             },
#             'broadwell': {
#                 'HECBioSim/Crambin': (356.0, None, None, 'ns/day'),
#                 'HECBioSim/Glutamine-Binding-Protein': (158.0, None, None, 'ns/day'),  # noqa: E501
#                 'HECBioSim/hEGFRDimer': (28.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerSmallerPL': (39.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerPair': (11.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRtetramerPair': (6.0, None, None, 'ns/day'),
#             },
#             'zen2': {
#                 'HECBioSim/Glutamine-Binding-Protein': (250.0, None, None, 'ns/day'),   # noqa: E501
#                 'HECBioSim/hEGFRDimer': (80.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerSmallerPL': (104.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerPair': (43.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRtetramerPair': (20.0, None, None, 'ns/day'),
#             },
#         },
#         16: {
#             'sm_60': {
#                 'HECBioSim/Glutamine-Binding-Protein': (154.0, None, None, 'ns/day'),  # noqa: E501
#                 'HECBioSim/hEGFRDimer': (43.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerSmallerPL': (54.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerPair': (21.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRtetramerPair': (14.0, None, None, 'ns/day'),
#             },
#             'broadwell': {
#                 'HECBioSim/Glutamine-Binding-Protein': (200.0, None, None, 'ns/day'),  # noqa: E501
#                 'HECBioSim/hEGFRDimer': (44.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerSmallerPL': (54.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerPair': (19.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRtetramerPair': (10.0, None, None, 'ns/day'),
#             },
#             'zen2': {
#                 'HECBioSim/hEGFRDimer': (82.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerSmallerPL': (70.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRDimerPair': (49.0, None, None, 'ns/day'),
#                 'HECBioSim/hEGFRtetramerPair': (25.0, None, None, 'ns/day'),
#             },
#         }
#     }
# 
#     @run_after('init')
#     def setup_filtering_criteria(self):
#         # Update test's description
#         self.descr += f' ({self.num_nodes} node(s))'
# 
#         # Setup system filtering
#         valid_systems = {
#             'cpu': {
#                 1: ['daint:mc', 'dom:mc', 'eiger:mc', 'pilatus:mc'],
#                 2: ['daint:mc', 'dom:mc', 'eiger:mc', 'pilatus:mc'],
#                 4: ['daint:mc', 'dom:mc', 'eiger:mc', 'pilatus:mc'],
#                 6: ['daint:mc', 'dom:mc', 'eiger:mc', 'pilatus:mc'],
#                 8: ['daint:mc', 'eiger:mc'],
#                 16: ['daint:mc', 'eiger:mc']
#             },
#             'gpu': {
#                 1: ['daint:gpu', 'dom:gpu', 'eiger:gpu', 'pilatus:gpu'],
#                 2: ['daint:gpu', 'dom:gpu', 'eiger:gpu', 'pilatus:gpu'],
#                 4: ['daint:gpu', 'dom:gpu', 'eiger:gpu', 'pilatus:gpu'],
#                 6: ['daint:gpu', 'dom:gpu', 'eiger:gpu', 'pilatus:gpu'],
#                 8: ['daint:gpu', 'eiger:gpu'],
#                 16: ['daint:gpu', 'eiger:gpu']
#             }
#         }
#         try:
#             self.valid_systems = valid_systems[self.nb_impl][self.num_nodes]
#         except KeyError:
#             self.valid_systems = []
# 
#         # Setup prog env. filtering
#         if self.current_system.name in ('eiger', 'pilatus'):
#             self.valid_prog_environs = ['cpeGNU']
# 
#         if self.num_nodes in (6, 16):
#             self.tags |= {'production'}
#             if (self.nb_impl == 'gpu' and
#                 self.bench_name == 'HECBioSim/hEGFRDimerSmallerPL'):
#                 self.tags |= {'maintenance'}
# 
#     @run_before('run')
#     def setup_run(self):
#         self.skip_if_no_procinfo()
# 
#         # Setup GPU run
#         if self.nb_impl == 'gpu':
#             self.num_gpus_per_node = 1
#             self.variables = {'CRAY_CUDA_MPS': '1'}
# 
#         proc = self.current_partition.processor
# 
#         # Choose arch; we set explicitly the GPU arch, since there is no
#         # auto-detection
#         arch = proc.arch
#         if self.current_partition.fullname in ('daint:gpu', 'dom:gpu'):
#             arch = 'sm_60'
# 
#         try:
#             found = self.allref[self.num_nodes][arch][self.bench_name]
#         except KeyError:
#             self.skip(f'Configuration with {self.num_nodes} node(s) of '
#                       f'{self.bench_name!r} is not supported on {arch!r}')
# 
#         # Setup performance references
#         self.reference = {
#             '*': {
#                 'perf': self.allref[self.num_nodes][arch][self.bench_name]
#             }
#         }
# 
#         # Setup parallel run
#         self.num_tasks_per_node = proc.num_cores
#         self.num_tasks = self.num_nodes * self.num_tasks_per_node
