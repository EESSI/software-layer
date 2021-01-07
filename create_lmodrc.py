#!/usr/bin/env python3
#
# Create lmodrc.lua configuration file for Lmod.
#
import os
import sys

DOT_LMOD = '.lmod'

TEMPLATE_LMOD_RC = """propT = {
}
scDescriptT = {
    {
        ["dir"] = "%(prefix)s/%(dot_lmod)s/cache",
        ["timestamp"] = "%(prefix)s/%(dot_lmod)s/cache/timestamp",
    },
}
"""


def error(msg):
    sys.stderr.write("ERROR: %s\n" % msg)
    sys.exit(1)


if len(sys.argv) != 3:
    error("Usage: %s <EESSI pilot version> <software subdirectory>" % sys.argv[0])

eessi_version = sys.argv[1]
software_subdir = sys.argv[2]

prefix = os.path.join('/cvmfs', 'pilot.eessi-hpc.org', eessi_version, 'software', software_subdir)

if not os.path.exists(prefix):
    error("Prefix directory %s does not exist!" % prefix)

lmodrc_path = os.path.join(prefix, DOT_LMOD, 'lmodrc.lua')
lmodrc_txt = TEMPLATE_LMOD_RC % {
    'dot_lmod': DOT_LMOD,
    'prefix': prefix,
}
try:
    os.makedirs(os.path.dirname(lmodrc_path))
    with open(lmodrc_path, 'w') as fp:
        fp.write(lmodrc_txt)

except (IOError, OSError) as err:
    error("Failed to create %s: %s" % (lmodrc_path, err))

print(lmodrc_path)
