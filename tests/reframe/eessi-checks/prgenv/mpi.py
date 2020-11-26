import os
import reframe as rfm
import reframe.utility.sanity as sn

# Try to use an import to define all site-specific things
import system_properties

@rfm.simple_test
class MpiHelloWorld(rfm.RegressionTest):
    def __init__(self):
        # We don't define these here to keep tests generic
        # Sensible systems & programming environments should be defined in your site configuration file
        self.valid_systems = ['*']
        self.valid_prog_environs = ['*']

        self.sourcepath = 'mpi_hello_world.c'
        self.maintainers = ['casparvl']
        self.num_tasks_per_node = system_properties.ncorespernode
        self.num_tasks = system_properties.ncorespernode
#       self.num_tasks_per_node = system_properties.ncorespernode
#        self.num_tasks_per_node = 16

        num_processes = sn.extractsingle(
            r'Received correct messages from (?P<nprocs>\d+) processes',
            self.stdout, 'nprocs', int)
        self.sanity_patterns = sn.assert_eq(num_processes,
                                            self.num_tasks_assigned-1)

    @property
    @sn.sanity_function
    def num_tasks_assigned(self):
        return self.job.num_tasks 
