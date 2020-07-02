#!/usr/bin/env python
import re, sys

from easybuild.tools.options import set_up_configuration


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


def main():
    eb_go, _ = set_up_configuration(args=sys.argv, silent=True)

    if len(eb_go.args) != 2:
        error("Usage: %s <path to build list file>" % sys.argv[0])

    host_attrs = det_host_attrs()
    build_list = parse_build_list(eb_go.args[1])
    filtered_build_list = filter_build_list(build_list, host_attrs)

    for name in sorted(filtered_build_list):
        print(name)
        for key in filtered_build_list[name]:
            print("* %s" % key)


main()