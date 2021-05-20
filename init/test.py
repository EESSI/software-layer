import os
import pytest
import re

import eessi_software_subdir_for_host
from eessi_software_subdir_for_host import find_best_target


def prep_tmpdir(tmpdir, subdirs):
    for subdir in subdirs:
        os.makedirs(os.path.join(tmpdir, 'software', 'linux', subdir), exist_ok=True)


def test_prefix_does_not_exist(capsys, tmpdir):
    """Test whether non-existing prefix results in error."""

    with pytest.raises(SystemExit):
        find_best_target(tmpdir)

    captured = capsys.readouterr()
    assert captured.out == ''
    assert re.match('^ERROR: Specified prefix ".*/software/linux" does not exist!$', captured.err)


def test_no_targets(tmpdir, capsys):
    """Test case where no compatible targets are found for host CPU."""
    prep_tmpdir(tmpdir, [''])
    with pytest.raises(SystemExit):
        find_best_target(tmpdir)

    captured = capsys.readouterr()
    assert captured.out == ''
    assert re.match('^ERROR: No compatible targets found for .*', captured.err)


def test_broadwell_host(tmpdir, capsys, monkeypatch):
    """Test selecting of target on a Broadwell host."""

    def broadwell_host_triple():
        return ('x86_64', 'intel', 'broadwell')

    monkeypatch.setattr(eessi_software_subdir_for_host, 'det_host_triple', broadwell_host_triple)

    # if generic is there, that's always a match
    prep_tmpdir(tmpdir, ['x86_64/generic'])
    assert find_best_target(tmpdir) == 'x86_64/generic'

    # targets from other CPU familues have no impact on target picked for Intel host CPU
    prep_tmpdir(tmpdir, ['x86_64/amd/zen2', 'aarch64/graviton2', 'ppc64le/power9'])
    assert find_best_target(tmpdir) == 'x86_64/generic'

    # incompatible targets are not picked
    prep_tmpdir(tmpdir, ['x86_64/intel/skylake', 'x86_64/intel/cascadelake'])
    assert find_best_target(tmpdir) == 'x86_64/generic'

    # compatible targets are picked if no better match is available
    prep_tmpdir(tmpdir, ['x86_64/intel/nehalem'])
    assert find_best_target(tmpdir) == 'x86_64/intel/nehalem'

    prep_tmpdir(tmpdir, ['x86_64/intel/ivybridge'])
    assert find_best_target(tmpdir) == 'x86_64/intel/ivybridge'

    # unknown targets don't cause trouble (only warning)
    prep_tmpdir(tmpdir, ['x86_64/intel/no_such_intel_cpu'])
    assert find_best_target(tmpdir) == 'x86_64/intel/ivybridge'
    captured = capsys.readouterr()
    assert captured.out == ''
    assert captured.err == 'WARNING: Ignoring unknown target "no_such_intel_cpu"\n'

    # older targets have to no impact on best target (sandybridge < ivybridge)
    prep_tmpdir(tmpdir, ['x86_64/intel/sandybridge'])
    assert find_best_target(tmpdir) == 'x86_64/intel/ivybridge'

    prep_tmpdir(tmpdir, ['x86_64/intel/haswell'])
    assert find_best_target(tmpdir) == 'x86_64/intel/haswell'

    expected = ['cascadelake', 'haswell', 'ivybridge', 'nehalem', 'no_such_intel_cpu', 'sandybridge', 'skylake']
    assert sorted(os.listdir(os.path.join(tmpdir, 'software', 'linux', 'x86_64', 'intel'))) == expected

    # exact match, no better target than this
    prep_tmpdir(tmpdir, ['x86_64/intel/broadwell'])
    assert find_best_target(tmpdir) == 'x86_64/intel/broadwell'
