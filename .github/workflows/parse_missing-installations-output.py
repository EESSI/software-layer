import os
import re

eb_missing_out = os.environ['eb_missing_out']
missing = re.findall("\([A-Z_a-z0-9_\-_\.]*.eb\)", eb_missing_out)
missing_cuda = []
missing_cpu = []
for ec in missing:
    if re.search('CUDA', ec):
        missing_cuda.append(ec)
    else:
        missing_cpu.append(ec)
if len(missing_cpu) != 0:
    os.environ['MISSING_CPU'] = str(missing_cpu)
if len(missing_cuda) != 0:
    os.environ['MISSING_CUDA'] = str(missing_cuda)
