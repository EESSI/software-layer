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

echo "[TEST]" > ${job_test_result_file}
echo "comment_description = <em>(no tests yet)</em>" >> ${job_test_result_file}
echo "status = SUCCESS" >> ${job_test_result_file}

exit 0
