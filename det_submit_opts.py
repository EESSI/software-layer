import os
import subprocess

from easybuild.framework.easystack import EasyStackParser

CPU_TARGET_A64FX = 'aarch64/a64fx'


def get_orig_easystack(easystack, repo_path):
    """ write the original easystack file (before the diff was applied) """
    orig_easystack = f'{easystack}.orig'
    git_cmd = f'git -C {repo_path} show HEAD:{easystack}'.split()
    with open(os.path.join(repo_path, orig_easystack), 'w', encoding='utf-8') as outfile:
        subprocess.run(git_cmd, check=True, stdout=outfile)
    return orig_easystack


def det_submit_opts(job):
    """
    determine submit options from added easyconfigs
    Args:
        job (Job): namedtuple containing all information about job to be submitted

    Returns:
        (string): string containing extra submit options
    """
    easystack = 'easystacks/software.eessi.io/2023.06/a64fx/eessi-2023.06-eb-4.9.4-2023a.yml'
    repo_path = job.working_dir
    orig_easystack = get_orig_easystack(easystack, repo_path)

    esp = EasyStackParser()
    orig_ecs = {x[0] for x in esp.parse(os.path.join(repo_path, orig_easystack)).ec_opt_tuples}
    pr_ecs = {x[0] for x in esp.parse(os.path.join(repo_path, easystack)).ec_opt_tuples}
    added_ecs = pr_ecs - orig_ecs
    print(f'added easyconfigs: {added_ecs}')

    submit_opts = [job.slurm_opts]
    for ec in added_ecs:
        # remove OS part from arch_target
        arch_name = '/'.join(job.arch_target.split('/')[1:])
        # set walltime limit to 2 days when R-bundle-CRAN should be built on a64fx
        if ec.startswith('R-bundle-CRAN-2023.12-foss-2023a') and arch_name == CPU_TARGET_A64FX:
            submit_opts.append('--time=2-00:00:00')

    return ' '.join(submit_opts)
