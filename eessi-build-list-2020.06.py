eessi_2020_06 = {
    'GROMACS': {
        '2020.1-foss-2020a-Python-3.8.2': {
            'except': ['gpu'],
        },
    },
    'OpenFOAM': {
        '7-foss-2019b': {},
    },
    'TensorFlow': {
        '2.2.0-foss-2019b-Python-3.7.4': {
            'except': ['gpu'],
        },
        '2.2.0-fosscuda-2019b-Python-3.7.4': {
            'only': ['gpu'],
        }
    },
}