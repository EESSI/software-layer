import os
import re

missing = os.environ['missing']
missing = missing.split('\n')
missing_cuda = []
missing_cpu = []
for ec in missing:
    if re.search('CUDA', ec):
        missing_cuda.append(ec)
    else:
        missing_cpu.append(ec)
if len(missing_cpu) != 0 and len(missing_cuda) != 0:
    print(f'Please open a seperate pr of the dependencies: {missing_cpu}')
    os.write(2, b'Error: CPU dependencies for CUDA build must be build in a seperate pr')
    exit(1)
elif len(missing_cuda) != 0:
    # TODO: Make this set the accelorator label?
    print(f'Have fun installing the following gpu builds: {missing_cuda}')
elif len(missing_cpu) != 0:
    print(f'Have fun installing the following gpu builds: {missing_cpu}')
else:
    print('no missing modules')
