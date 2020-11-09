import os
import reframe as rfm
import reframe.utility.sanity as sn

# Try to use an import to define all site-specific things
# import system_properties

@rfm.simple_test
class MpiHelloWorld(rfm.RegressionTest):
    def __init__(self):
        # We don't define these here to keep tests generic
        # Sensible systems & programming environments should be defined in your site configuration file
        self.valid_systems = ['*']
        self.valid_prog_environs = ['*']

        self.sourcepath = 'mpi_hello_world.c'
        self.maintainers = ['casparvl']
        self.num_tasks_per_node = -2
#       self.num_tasks_per_node = system_properties.ncorespernode
        self.num_tasks_per_node = 16
