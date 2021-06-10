site_configuration = {
    'systems': [
        {
            'name': 'example_system',
            'descr': 'This is just an example system',
            'modules_system': 'tmod',
	    'hostnames': ['login', 'int'],
            'partitions': [
                {
                    'name': 'cpu',
                    'scheduler': 'slurm',
                    'launcher': 'srun',
                    'access':  ['-p cpu'],
                    'environs': ['builtin'],
                    'processor': {
                        'num_cpus': 24,
                    },
                    'descr': 'normal CPU partition'
                },
                {
                    'name': 'gpu',
                    'descr': 'GPU partition',
                    'scheduler': 'slurm',
                    'access':  ['-p gpu'],
                    'environs': ['builtin'],
                    'max_jobs': 100,
                    'launcher': 'srun',
                    'processor': {
                        'num_cpus': 16,
                    },
                    'devices': [
                        {
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
            'name': 'builtin',
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
