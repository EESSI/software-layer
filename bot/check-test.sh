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

# Check that job output file is found
[[ ${VERBOSE} -ne 0 ]] && echo ">> searching for job output file(s) matching '"${job_out}"'"
if  [[ -f ${job_out} ]]; then
    SLURM=1
    [[ ${VERBOSE} -ne 0 ]] && echo "   found slurm output file '"${job_out}"'"
else
    SLURM=0
    [[ ${VERBOSE} -ne 0 ]] && echo "   Slurm output file '"${job_out}"' NOT found"
fi


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
FAILED=-1
if [[ ${SLURM} -eq 1 ]]; then
  GP_failed='\[\s*FAILED\s*\]'
  grep_out=$(grep -v "^>> searching for " ${job_dir}/${job_out} | grep "${GP_failed}")
  [[ $? -eq 0 ]] && FAILED=1 || FAILED=0
  # have to be careful to not add searched for pattern into slurm out file
  [[ ${VERBOSE} -ne 0 ]] && echo ">> searching for '"${GP_failed}"'"
  [[ ${VERBOSE} -ne 0 ]] && echo "${grep_out}"
fi

# Here, we grep for 'ERROR:', which is printed if a fatal_error is encountered when executing the test step
# I.e. this is an error in execution of the run_tests.sh itself, NOT in running the actual tests
ERROR=-1
if [[ ${SLURM} -eq 1 ]]; then
  GP_error='ERROR: '
  grep_out=$(grep -v "^>> searching for " ${job_dir}/${job_out} | grep "${GP_error}")
  [[ $? -eq 0 ]] && ERROR=1 || ERROR=0
  # have to be careful to not add searched for pattern into slurm out file
  [[ ${VERBOSE} -ne 0 ]] && echo ">> searching for '"${GP_error}"'"
  [[ ${VERBOSE} -ne 0 ]] && echo "${grep_out}"
fi

echo "[TEST]" > ${job_test_result_file}
if [[ ${SLURM} -eq 0 ]]; then
    echo "comment_description = :cry: FAILED (job output file not found, cannot check test results)" >> ${job_test_result_file}
elif [[ ${ERROR} -eq 1 ]]; then
    echo "comment_description = :cry: FAILED (EESSI test suite was not run, test step itself failed to execute)" >> ${job_test_result_file}
    echo "status = FAILURE" >> ${job_test_result_file}
elif [[ ${FAILED} -eq 1 ]]; then
    echo "comment_description = :cry: FAILED (EESSI test suite produced failures)" >> ${job_test_result_file}
else
    echo "comment_description = :grin: SUCCESS" >> ${job_test_result_file}
    echo "status = SUCCESS" >> ${job_test_result_file}
fi

exit 0
