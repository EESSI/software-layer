PREPEND = 1
APPEND = 2
REPLACE = 3
APPEND_LIST = 4
DROP = 5

opts_changes = {
    'GCCcore': {
        # build EPREFIX-aware GCCcore
        'preconfigopts': (
                    "if [ -f ../gcc/gcc.c ]; then sed -i 's/--sysroot=%R//' ../gcc/gcc.c; " +
                    "for h in ../gcc/config/*/*linux*.h; do " +
                    r'sed -i -r "/_DYNAMIC_LINKER/s,([\":])(/lib),\1${EPREFIX}\2,g" $h; done; fi; ',
                    PREPEND ),
        'configopts': ("--with-sysroot=$EPREFIX", PREPEND),
        # remove .la files, as they mess up rpath when libtool is used
        'postinstallcmds': (["find %(installdir)s -name '*.la' -delete"], REPLACE),
    },
}

def modify_all_opts(ec, opts_changes,
        opts_to_skip=['builddependencies', 'dependencies', 'modluafooter', 'toolchainopts', 'version', 'multi_deps'],
        opts_to_change='ALL'):
    if 'modaltsoftname' in ec and ec['modaltsoftname'] in opts_changes:
        name = ec['modaltsoftname']
    else:
        name = ec['name']

    possible_keys = [(name, ec['version']), name]

    for key in possible_keys:
        if key in opts_changes.keys():
            for opt, value in opts_changes[key].items():
                # we don't modify those in this stage
                if opt in opts_to_skip:
                    continue
                if opts_to_change == 'ALL' or opt in opts_to_change:
                    if isinstance(value, list):
                        values = value
                    else:
                        values = [value]

                    for v in values:
                        update_opts(ec, v[0], opt, v[1])
            break

def parse_hook(ec, *args, **kwargs):
    """Example parse hook to inject a patch file for a fictive software package named 'Example'."""
    modify_all_opts(ec, opts_changes, opts_to_skip=[], opts_to_change=['dependencies', 'builddependencies', 'license_file', 'version', 'multi_deps'])
