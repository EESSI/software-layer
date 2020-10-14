#!/usr/bin/env python3
#
# Determine EESSI software subdirectory to use for current build host, using archspec
#
import os
import argparse
import archspec.cpu

software_subdir = os.getenv('EESSI_SOFTWARE_SUBDIR_OVERRIDE')
if software_subdir is None:

    parser = argparse.ArgumentParser(description='Determine EESSI software subdirectory to use for current build host.')
    parser.add_argument('--generic', dest='generic', action='store_true',
                        default=False, help='Use generic for CPU name.')
    args = parser.parse_args()

    host_cpu = archspec.cpu.host()
    vendors = {
        'GenuineIntel': 'intel',
        'AuthenticAMD': 'amd',
    }

    vendor = vendors.get(host_cpu.vendor)

    if args.generic:
        parts = (host_cpu.family.name, 'generic')
    elif vendor:
        parts = (host_cpu.family.name, vendor, host_cpu.name)
    else:
        parts = (host_cpu.family.name, host_cpu.name)

    software_subdir = os.path.join(*parts)

print(software_subdir)
