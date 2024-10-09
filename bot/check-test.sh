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
    SLURM_OUTPUT_FOUND=1
    [[ ${VERBOSE} -ne 0 ]] && echo "   found slurm output file '"${job_out}"'"
else
    SLURM_OUTPUT_FOUND=0
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
if [[ ${SLURM_OUTPUT_FOUND} -eq 1 ]]; then
  GP_failed='\[\s*FAILED\s*\].*Ran .* test case'
  grep_reframe_failed=$(grep -v "^>> searching for " ${job_dir}/${job_out} | grep "${GP_failed}")
  [[ $? -eq 0 ]] && FAILED=1 || FAILED=0
  # have to be careful to not add searched for pattern into slurm out file
  [[ ${VERBOSE} -ne 0 ]] && echo ">> searching for '"${GP_failed}"'"
  [[ ${VERBOSE} -ne 0 ]] && echo "${grep_reframe_failed}"
fi

# Here, we grep for 'ERROR:', which is printed if a fatal_error is encountered when executing the test step
# I.e. this is an error in execution of the run_tests.sh itself, NOT in running the actual tests
ERROR=-1
if [[ ${SLURM_OUTPUT_FOUND} -eq 1 ]]; then
  GP_error='ERROR: '
  grep_out=$(grep -v "^>> searching for " ${job_dir}/${job_out} | grep "${GP_error}")
  [[ $? -eq 0 ]] && ERROR=1 || ERROR=0
  # have to be careful to not add searched for pattern into slurm out file
  [[ ${VERBOSE} -ne 0 ]] && echo ">> searching for '"${GP_error}"'"
  [[ ${VERBOSE} -ne 0 ]] && echo "${grep_out}"
fi

SUCCESS=-1
# Grep for the success pattern, so we can report the amount of tests run
if [[ ${SLURM_OUTPUT_FOUND} -eq 1 ]]; then
  GP_success='\[\s*PASSED\s*\].*Ran .* test case'
  grep_reframe_success=$(grep -v "^>> searching for " ${job_dir}/${job_out} | grep "${GP_success}")
  [[ $? -eq 0 ]] && SUCCESS=1 || SUCCESS=0
  # have to be careful to not add searched for pattern into slurm out file
  [[ ${VERBOSE} -ne 0 ]] && echo ">> searching for '"${GP_success}"'"
  [[ ${VERBOSE} -ne 0 ]] && echo "${grep_reframe_success}"
fi

if [[ ! -z ${grep_reframe_failed} ]]; then
    grep_reframe_result=${grep_reframe_failed}
else
    # Grep the entire output of ReFrame, so that we can report it in the foldable section of the test report
    GP_success_full='(?s)\[----------\] start processing checks.*?\[==========\] Finished on [a-zA-Z0-9 ]*'
    # Grab the full ReFrame report, than cut the irrelevant parts
    # Note that the character limit for messages in github is around 65k, so cutting is important
    grep_reframe_success_full=$( \
        grep -v "^>> searching for " ${job_dir}/${job_out} | \
        # Use -z
        grep -Pzo "${GP_success_full}" | \
        # Replace null character with newline, to undo the -z option
        sed 's/\x00/\n/g' | \
        # Remove the [ RUN     ] lines from reframe, they are not very informative
        grep -v -P '\[\s*RUN\s*]' | \
        # Remove the line '[----------] all spawned checks have finished'
        grep -v '\[-*\]' | \
        # Remove the line '[==========] Finished on Mon Oct  7 21'
        grep -v '\[=*\]' | \
        # Remove blank line(s) from the report
        grep -v '^$' | \
        # Remove warnings about the local spawner not supporting memory requests
        grep -v 'WARNING\: hooks\.req_memory_per_node does not support the scheduler you configured .local.*$' | \
        # Strip color coding characters
        sed 's/\x1B\[[0-9;]*m//g' | \
        # Replace all newline characters with <br/>
        sed ':a;N;$!ba;s/\n/<br\/>/g' | \
        # Replace % with %%. Use \%\% to interpret both %% as (non-special) characters
        sed 's/\%/\%\%/g' \
    )
    # TODO (optional): we could impose a character limit here, and truncate if too long
    # (though we should do that before inserting the <br/> statements).
    # If we do, we should probably re-append the final summary, e.g.
    # [  PASSED  ] Ran 10/10 test case(s) from 10 check(s) (0 failure(s), 0 skipped, 0 aborted)
    # so that that is always displayed
    # However, that's not implemented yet - let's see if this ever even becomes an issue
    grep_reframe_result=${grep_reframe_success_full}
fi
echo "grep_reframe_result: ${grep_reframe_result}"

echo "[TEST]" > ${job_test_result_file}
if [[ ${SLURM_OUTPUT_FOUND} -eq 0 ]]; then
    summary=":cry: FAILURE"
    reason="Job output file not found, cannot check test results."
    status="FAILURE"
# Should come before general errors: if SUCCESS==1, it indicates the test suite ran succesfully
# regardless of other things that might have gone wrong
elif [[ ${SUCCESS} -eq 1 ]]; then
    summary=":grin: SUCCESS"
    reason=""
    status="SUCCESS"
# Should come before general errors: if FAILED==1, it indicates the test suite ran
# otherwise the pattern wouldn't have been there
elif [[ ${FAILED} -eq 1 ]]; then
    summary=":cry: FAILURE"
    reason="EESSI test suite produced failures."
    status="FAILURE"
elif [[ ${ERROR} -eq 1 ]]; then
    summary=":cry: FAILURE"
    reason="EESSI test suite was not run, test step itself failed to execute."
    status="FAILURE"
else
    summary=":cry: FAILURE"
    reason="Failed for unknown reason"
    status="FAILURE"
fi


echo "[TEST]" > ${job_test_result_file}
echo -n "comment_description = " >> ${job_test_result_file}

# Use template for writing PR comment with details
# construct and write complete PR comment details: implements third alternative
comment_template="<details>__SUMMARY_FMT__<dl>__REASON_FMT____REFRAME_FMT____DETAILS_FMT__</dl></details>"
comment_success_item_fmt=":white_check_mark: __ITEM__"
comment_failure_item_fmt=":x: __ITEM__"

# Initialize comment_description
comment_description=${comment_template}

# Now, start replacing template items one by one
comment_summary_fmt="<summary>__SUMMARY__ _(click triangle for details)_</summary>"
comment_summary="${comment_summary_fmt/__SUMMARY__/${summary}}"
comment_description=${comment_description/__SUMMARY_FMT__/${comment_summary}}


# Only add if there is a reason (e.g. no reason for successful runs)
if [[ ! -z ${reason} ]]; then
    comment_reason_fmt="<dt>_Reason_</dt><dd>__REASONS__</dd>"
    reason_details="${comment_reason_fmt/__REASONS__/${reason}}"
    comment_description=${comment_description/__REASON_FMT__/${reason_details}}
else
    comment_description=${comment_description/__REASON_FMT__/""}
fi

# Only add if there is a reframe summary (e.g. no reframe summary if reframe wasn't launched succesfully)
echo "ReFrame result:"
echo "${grep_reframe_result}"
if [[ ! -z ${grep_reframe_result} ]]; then
    comment_reframe_fmt="<dt>_ReFrame Summary_</dt><dd>__REFRAME_SUMMARY__</dd>"
    reframe_summary=${comment_reframe_fmt/__REFRAME_SUMMARY__/${grep_reframe_result}}
    comment_description=${comment_description/__REFRAME_FMT__/${reframe_summary}}
else
    comment_description=${comment_description/__REFRAME_FMT__/""}
fi

# Declare functions
function print_br_item() {
    format="${1}"
    item="${2}"
    echo -n "${format//__ITEM__/${item}}<br/>"
}

function success() {
    format="${comment_success_item_fmt}"
    item="$1"
    print_br_item "${format}" "${item}"
}

function failure() {
    format="${comment_failure_item_fmt}"
    item="$1"
    print_br_item "${format}" "${item}"
}

function add_detail() {
    actual=${1}
    expected=${2}
    success_msg="${3}"
    failure_msg="${4}"
    if [[ ${actual} -eq ${expected} ]]; then
        success "${success_msg}"
    else
        failure "${failure_msg}"
    fi
}

# first construct comment_details_list, abbreviated comment_details_list
# then use it to set comment_details
comment_details_list=""

success_msg="job output file <code>${job_out}</code>"
failure_msg="no job output file <code>${job_out}</code>"
comment_details_list=${comment_details_list}$(add_detail ${SLURM_OUTPUT_FOUND} 1 "${success_msg}" "${failure_msg}")

success_msg="no message matching <code>${GP_error}</code>"
failure_msg="found message matching <code>${GP_error}</code>"
comment_details_list=${comment_details_list}$(add_detail ${ERROR} 0 "${success_msg}" "${failure_msg}")

# Add an escape character to every *, for it to be printed correctly in the comment on GitHub
GP_failed="${GP_failed//\*/\\*}"
success_msg="no message matching <code>""${GP_failed}""</code>"
failure_msg="found message matching <code>""${GP_failed}""</code>"
comment_details_list=${comment_details_list}$(add_detail ${FAILED} 0 "${success_msg}" "${failure_msg}")

comment_details_fmt="<dt>_Details_</dt><dd>__DETAILS_LIST__</dd>"
comment_details="${comment_details_fmt/__DETAILS_LIST__/${comment_details_list}}"
comment_description=${comment_description/__DETAILS_FMT__/${comment_details}}

# Actually writing the comment description to the result file
echo "${comment_description}" >> ${job_test_result_file}
echo "status = ${status}" >> ${job_test_result_file}

exit 0
