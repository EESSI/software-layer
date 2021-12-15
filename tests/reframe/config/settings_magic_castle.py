site_configuration = {
    'systems': [
        {
            'name': 'example_system',
            'descr': 'This is just an example system',
            'modules_system': 'lmod',
	    'hostnames': ['login', 'node'],
            'partitions': [
                {
                    'name': 'cpu',
                    'scheduler': 'slurm',
                    'launcher': 'mpirun',
                    'access':  ['-p cpubase_bycore_b1 --exclusive --mem=94515M'],
                    'environs': ['builtin'],
                    'max_jobs': 4,
                    'processor': {
                        'num_cpus': 36,
                    },
                    'descr': 'normal CPU partition'
                },
#                 {
#                     'name': 'gpu',
#                     'descr': 'GPU partition',
#                     'scheduler': 'slurm',
#                     'access':  ['-p gpu --gpus-per-node 4 --exclusive'],
#                     'environs': ['builtin'],
#                     'max_jobs': 10,
#                     'launcher': 'srun',
#                     'processor': {
#                         'num_cpus': 72,
#                     },
#                     'devices': [
#                         {
#                             'type': 'gpu',
#                             'num_devices': 4,
#                         },
#                     ],
#                 },
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
    'general': [
        {
            'remote_detect': True,
        }
    ],
}
