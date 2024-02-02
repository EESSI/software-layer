#!/bin/bash
#
# Dummy script that only creates test result file for the bot, without actually checking anything
#
# This script is part of the EESSI software layer, see
# https://github.com/EESSI/software-layer.git
#
# author: Kenneth Hoste (HPC-UGent)
#
# license: GPLv2
#
job_dir=${PWD}
job_out="slurm-${SLURM_JOB_ID}.out"
job_test_result_file="_bot_job${SLURM_JOB_ID}.test"

# ReFrame prints e.g.
#[----------] start processing checks
#[ RUN      ] GROMACS_EESSI %benchmark_info=HECBioSim/Crambin %nb_impl=cpu %scale=2_nodes %module_name=GROMACS/2021.3-foss-2021a /d597cff4 @snellius:rome+default
#[ RUN      ] GROMACS_EESSI %benchmark_info=HECBioSim/Crambin %nb_impl=cpu %scale=2_nodes %module_name=GROMACS/2021.3-foss-2021a /d597cff4 @snellius:genoa+default
#[ RUN      ] GROMACS_EESSI %benchmark_info=HECBioSim/Crambin %nb_impl=cpu %scale=1_cpn_2_nodes %module_name=GROMACS/2021.3-foss-2021a /f4194106 @snellius:genoa+default
#[     FAIL ] (1/3) GROMACS_EESSI %benchmark_info=HECBioSim/Crambin %nb_impl=cpu %scale=2_nodes %module_name=GROMACS/2021.3-foss-2021a /d597cff4 @snellius:genoa+default
#==> test failed during 'sanity': test staged in '/scratch-shared/casparl/reframe_output/staging/snellius/genoa/default/GROMACS_EESSI_d597cff4'
#[       OK ] (2/3) GROMACS_EESSI %benchmark_info=HECBioSim/Crambin %nb_impl=cpu %scale=2_nodes %module_name=GROMACS/2021.3-foss-2021a /d597cff4 @snellius:rome+default
#P: perf: 8.441 ns/day (r:0, l:None, u:None)
#[     FAIL ] (3/3) GROMACS_EESSI %benchmark_info=HECBioSim/Crambin %nb_impl=cpu %scale=1_cpn_2_nodes %module_name=GROMACS/2021.3-foss-2021a /f4194106 @snellius:genoa+default
#==> test failed during 'sanity': test staged in '/scratch-shared/casparl/reframe_output/staging/snellius/genoa/default/GROMACS_EESSI_f4194106'
#[----------] all spawned checks have finished
#[  FAILED  ] Ran 3/3 test case(s) from 2 check(s) (2 failure(s), 0 skipped, 0 aborted)

# We will grep for the last and final line, since this reflects the overall result
# Specifically, we grep for FAILED, since this is also what we print if a step in the test script itself fails
error_pattern="FAILED"
grep_out=$(grep "${error_pattern}" ${job_dir}/${job_out})
[[ $? -eq 0 ]] && ERROR=1 || ERROR=0

# Write the result to the job_test_result_file
echo "[TEST]" > ${job_test_result_file}
if [[ ${ERROR} -eq 1 ]]; then
    echo "comment_description = Test suite failed" >> ${job_test_result_file}
    echo "status = FAILURE" >> ${job_test_result_file}
else
    echo "comment_description = <em>(no tests yet)</em>" >> ${job_test_result_file}
    echo "status = SUCCESS" >> ${job_test_result_file}
fi

exit 0
