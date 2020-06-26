# Determine subdirectory of EESSI prefix to use, based on CPU microarchitecture of host
import os
import archspec.cpu

host_cpu = archspec.cpu.host()

cpu_family = host_cpu.family.name
cpu_codename = host_cpu.name

print(os.path.join(cpu_family, cpu_codename))
