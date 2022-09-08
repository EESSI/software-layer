#!/usr/bin/env python3
#
# Determine EESSI software subdirectory to use for current build host, using archspec
#
import os
import argparse
from archspec.cpu.detect import compatible_microarchitectures, raw_info_dictionary

software_subdir = os.getenv('EESSI_SOFTWARE_SUBDIR_OVERRIDE')
if software_subdir is None:

    parser = argparse.ArgumentParser(description='Determine EESSI software subdirectory to use for current build host.')
    parser.add_argument('--generic', dest='generic', action='store_true',
                        default=False, help='Use generic for CPU name.')
    args = parser.parse_args()

    # we can't directly use archspec.cpu.host(), because we may get back a virtual microarchitecture like x86_64_v3...
    def sorting_fn(item):
        """Helper function to sort compatible microarchitectures."""
        return len(item.ancestors), len(item.features)

    raw_cpu_info = raw_info_dictionary()
    compat_targets = compatible_microarchitectures(raw_cpu_info)

    # filter out generic targets
    non_generic_compat_targets = [t for t in compat_targets if t.vendor != "generic"]

    # Filter the candidates to be descendant of the best generic candidate
    best_generic = max([t for t in compat_targets if t.vendor == "generic"], key=sorting_fn)
    best_compat_targets = [t for t in non_generic_compat_targets if t > best_generic]

    if best_compat_targets:
        host_cpu = max(best_compat_targets, key=sorting_fn)
    else:
        host_cpu = max(non_generic_compat_targets, key=sorting_fn)

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
