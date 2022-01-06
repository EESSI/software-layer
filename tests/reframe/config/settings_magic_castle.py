# This is an example configuration file
site_configuration = {
    'systems': [
        {
            'name': 'Magic Castle',
            'descr': 'The Magic Castle instance as it was used in the EESSI hackathon in dec 2021, on AWS',
            'modules_system': 'lmod',
	    'hostnames': ['login', 'node'],
            'partitions': [
                {
                    'name': 'cpu',
                    'scheduler': 'slurm',
                    'launcher': 'mpirun',
                    # By default, the Magic Castle cluster only allocates a small amount of memory
                    # Thus we request the full memory explicitely
                    'access':  ['-p cpubase_bycore_b1 --exclusive --mem=94515M'],
                    'environs': ['builtin'],
                    'max_jobs': 4,
                    'processor': {
                        'num_cpus': 36,
                    },
                    'descr': 'normal CPU partition'
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
    'general': [
        {
            'remote_detect': True,
        }
    ],
}
