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


if len(sys.argv) != 2:
    error("Usage: %s <software prefix>" % sys.argv[0])

prefix = sys.argv[1]

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
