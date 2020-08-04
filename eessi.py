#!/usr/bin/env python
import re, sys

from easybuild.tools.options import set_up_configuration
import easybuild.main as ebmain
from easybuild.tools.robot import resolve_dependencies
from easybuild.tools.modules import modules_tool
from easybuild.framework.easyconfig.tools import det_easyconfig_paths
from easybuild.framework.easyconfig.tools import parse_easyconfigs

def error(msg):
    """Print error message and exit."""
    sys.stderr.write("ERROR: %s\n" % msg)
    sys.exit(1)


def det_host_attrs():
    """Determine attributes for current host system."""
    attrs = {
        # FIXME figure out whether host has a GPU (leverage archspec for this?)
        'gpu': False,
    }
    return attrs


def parse_build_list(path):
    """Parse build list at specified path and return result."""
    res = None

    orig_locals = sorted(locals().keys())
    with open(path) as fp:
        exec(fp.read())

    key_regex = re.compile('^eessi_[0-9]')
    for key in locals():
        if key not in orig_locals and key_regex.search(key):
            res = locals()[key]
            break

    if res is None:
        error("No variable matching '%s' found in %s" % (key_regex.pattern, path))

    return res


def filter_build_list(build_list, host_attrs):
    """Filter provided build list based on specified host attributes."""
    filtered_build_list = {}

    for name in build_list:
        filtered_build_list[name] = {}
        for key in build_list[name]:
            # make sure all 'only' attributes are set for current host;
            # if not, filter out the key
            only_attrs = build_list[name][key].get('only', [])
            if not all(host_attrs.get(x, False) for x in only_attrs):
                continue

            # make sure no 'except' attributes are set for current host;
            # if so, filter out the key
            except_attrs = build_list[name][key].get('except', [])
            if any(host_attrs.get(x, False) for x in except_attrs):
                continue

            filtered_build_list[name][key] = build_list[name][key]

    return filtered_build_list

# Get EasyBuilds robot functionality to give us back an ordered list that we
# can use to build without robot
def unroll_robot(easyconfig):
    print("Unrolling %s (WIP)" % easyconfig)
    # unrolled result will be stored here
    easyconfiglist = [easyconfig]
    return easyconfiglist

def main():
    eb_go, _ = set_up_configuration(args=sys.argv, silent=True)

    if len(eb_go.args) != 2:
        error("Usage: %s <path to build list file>" % sys.argv[0])

    host_attrs = det_host_attrs()
    build_list = parse_build_list(eb_go.args[1])
    filtered_build_list = filter_build_list(build_list, host_attrs)

    modtool = modules_tool()

    ec_list = [ "{0}-{1}.eb".format(name, version)
            for name in sorted(filtered_build_list)
            for version in filtered_build_list[name] ]

    print("EasyConfig names extracted from build list:")
    print(ec_list)

    ec_paths = det_easyconfig_paths(ec_list)
    ecs, _ = parse_easyconfigs([(p, False) for p in ec_paths], validate=False)
    ordered_ecs = resolve_dependencies(ecs, modtool, retain_all_deps=True)

    print("Ordered list of resolved dependencies")
    for ec in ordered_ecs:
        print(ec['spec'])

    # TODO: loop still fails after one iteration, because the first build removes the tmpdir after completing succesfully. I guess we need to re-initialize before calling main again or something?
    print("Start building")
    for ec in ordered_ecs:
        print(ec['spec'])
        # Just to see if we can call EB like this, do -D to not actually build anything for now
        ebargs=["{}".format(ec['spec'])]
        #print(ebargs)
        ebmain.main(ebargs)
    print("Building completed")

main()
