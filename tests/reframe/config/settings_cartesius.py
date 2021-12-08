site_configuration = {
    'systems': [
        {
            'name': 'example_system',
            'descr': 'This is just an example system',
            'modules_system': 'tmod4',
	    'hostnames': ['login', 'int', 'tcn', 'gcn'],
	    'partitions': [
		{
                    'name': 'short',
                    'scheduler': 'slurm',
	            'launcher': 'srun',
                    'access':  ['-p short --constraint=haswell'],
                    'environs': ['builtin', 'foss', 'container'],
                    'container_platforms': [
                        {
                            'type': 'Singularity',
                            'modules': [],
                            'variables': [['SLURM_MPI_TYPE', 'pmix']]
                        }
                    ],
                    'processor': {
                        'num_cpus': 24,
                        'num_sockets': 2,
                        'num_cpus_per_socket': 12,
                    },
                    'descr': 'normal partition'
                },
                {
                    'name': 'gpu',
                    'descr': 'GPU nodes (K40) ',
                    'scheduler': 'slurm',
                    'access':  ['-p gpu'],
                    'environs': ['builtin', 'fosscuda'],
                    'max_jobs': 100,
                    'launcher': 'srun',
                    'processor': {
                        'num_cpus': 16,
                        'num_sockets': 2,
                        'num_cpus_per_socket': 8,
                        'arch': 'ivybridge',
                    },
                    'devices': [
                        {
                            # on Cartesius it is not allowed to select the number of gpus with gres
                            # the nodes are always allocated exclusively
                            'type': 'gpu',
                            'num_devices': 2,
                        },
                    ],
                },
             ]
         },
     ],
    'environments': [
        {
            'name': 'foss',
	    'modules': ['foss/2020a'],
            'cc': 'mpicc',
            'cxx': 'mpicxx',
            'ftn': 'mpifort',
        },
        {
            'name': 'fosscuda',
            'modules': ['fosscuda/2020a'],
            'cc': 'mpicc',
            'cxx': 'mpicxx',
            'ftn': 'mpifort',
        },
        {
            'name': 'container',
            'modules': [],
        },
        {
            'name': 'builtin',
            'modules': ['2020'],
            'cc': 'cc',
            'cxx': '',
            'ftn': '',
        },
     ],
     'logging': [
        {
            'level': 'debug',
            'handlers': [
                {
                    'type': 'stream',
                    'name': 'stdout',
                    'level': 'info',
                    'format': '%(message)s'
                },
                {
                    'type': 'file',
                    'name': 'reframe.log',
                    'level': 'debug',
                    'format': '[%(asctime)s] %(levelname)s: %(check_info)s: %(message)s',   # noqa: E501
                    'append': False
                }
            ],
            'handlers_perflog': [
                {
                    'type': 'filelog',
                    'prefix': '%(check_system)s/%(check_partition)s',
                    'level': 'info',
                    'format': (
                        '%(check_job_completion_time)s|reframe %(version)s|'
                        '%(check_info)s|jobid=%(check_jobid)s|'
                        '%(check_perf_var)s=%(check_perf_value)s|'
                        'ref=%(check_perf_ref)s '
                        '(l=%(check_perf_lower_thres)s, '
                        'u=%(check_perf_upper_thres)s)|'
                        '%(check_perf_unit)s'
                    ),
                    'append': True
                }
            ]
        }
    ],
}
