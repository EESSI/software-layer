#!/usr/bin/env python3
#
# Determine EESSI software subdirectory to use for current build host, using archspec
#
import os
import archspec.cpu

host_cpu = archspec.cpu.host()
vendors = {
    'GenuineIntel': 'intel',
    'AuthenticAMD': 'amd',
}

vendor = vendors.get(host_cpu.vendor)
if vendor:
    parts = (host_cpu.family.name, vendor, host_cpu.name)
else:
    parts = (host_cpu.family.name, host_cpu.name)

print(os.path.join(*parts))
