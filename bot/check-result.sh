#!/bin/bash
#
# Script to check the result of building the EESSI software layer.
# Intended use is that it is called by a (batch) job running on a compute
# node.
#
# This script is part of the EESSI compatibility layer, see
# https://github.com/EESSI/compatibility-layer.git
#
# author: Thomas Roeblitz (@trz42)
#
# license: GPLv2
#

# result cases

#  - SUCCESS (all of)
#    - working directory contains slurm-JOBID.out file
#    - working directory contains eessi*tar.gz
#    - no message ERROR
#    - no message FAILED
#    - no message ' required modules missing:'
#    - one or more of 'No missing modules!'
#    - message regarding created tarball
#  - FAILED (one of ... implemented as NOT SUCCESS)
#    - no slurm-JOBID.out file
#    - no tarball
#    - message with ERROR
#    - message with FAILED
#    - message with ' required modules missing:'
#    - no message regarding created tarball

# stop as soon as something fails
# set -e

TOPDIR=$(dirname $(realpath $0))

source ${TOPDIR}/../scripts/utils.sh
source ${TOPDIR}/../scripts/cfg_files.sh

display_help() {
  echo "usage: $0 [OPTIONS]"
  echo " OPTIONS:"
  echo "  -h | --help    - display this usage information [default: false]"
  echo "  -v | --verbose - display more information [default: false]"
}

# set defaults for command line arguments
VERBOSE=0

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      display_help
      exit 0
      ;;
    -v|--verbose)
      VERBOSE=1
      shift 1
      ;;
    --)
      shift
      POSITIONAL_ARGS+=("$@") # save positional args
      break
      ;;
    -*|--*)
      fatal_error "Unknown option: $1" "${CMDLINE_ARG_UNKNOWN_EXITCODE}"
      ;;
    *)  # No more options
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"

job_dir=${PWD}

[[ ${VERBOSE} -ne 0 ]] && echo ">> analysing job in directory ${job_dir}"

GP_slurm_out="slurm-${SLURM_JOB_ID}.out"
[[ ${VERBOSE} -ne 0 ]] && echo ">> searching for job output file(s) matching '"${GP_slurm_out}"'"
job_out=$(ls ${job_dir} | grep "${GP_slurm_out}")
[[ $? -eq 0 ]] && SLURM=1 || SLURM=0
[[ ${VERBOSE} -ne 0 ]] && echo "   found slurm output file '"${job_out}"'"

GP_error='ERROR: '
[[ ${VERBOSE} -ne 0 ]] && echo ">> searching for '"${GP_error}"'"
grep_out=$(grep "${GP_error}" ${job_dir}/${job_out})
[[ $? -eq 0 ]] && ERROR=1 || ERROR=0
[[ ${VERBOSE} -ne 0 ]] && echo "${grep_out}"

GP_failed='FAILED: '
[[ ${VERBOSE} -ne 0 ]] && echo ">> searching for '"${GP_failed}"'"
grep_out=$(grep "${GP_failed}" ${job_dir}/${job_out})
[[ $? -eq 0 ]] && FAILED=1 || FAILED=0
[[ ${VERBOSE} -ne 0 ]] && echo "${grep_out}"

GP_req_missing=' required modules missing:'
[[ ${VERBOSE} -ne 0 ]] && echo ">> searching for '"${GP_req_missing}"'"
grep_out=$(grep "${GP_req_missing}" ${job_dir}/${job_out})
[[ $? -eq 0 ]] && MISSING=1 || MISSING=0
[[ ${VERBOSE} -ne 0 ]] && echo "${grep_out}"

GP_no_missing='No missing modules!'
[[ ${VERBOSE} -ne 0 ]] && echo ">> searching for '"${GP_no_missing}"'"
grep_out=$(grep "${GP_no_missing}" ${job_dir}/${job_out})
[[ $? -eq 0 ]] && NO_MISSING=1 || NO_MISSING=0
[[ ${VERBOSE} -ne 0 ]] && echo "${grep_out}"

GP_tgz_created="tar.gz created!"
[[ ${VERBOSE} -ne 0 ]] && echo ">> searching for '"${GP_tgz_created}"'"
grep_out=$(grep "${GP_tgz_created}" ${job_dir}/${job_out})
TARBALL=
if [[ $? -eq 0 ]]; then
    TGZ=1
    TARBALL=$(echo ${grep_out} | sed -e 's@^.*\(eessi[^/ ]*\) .*$@\1@')
else
    TGZ=0
fi
[[ ${VERBOSE} -ne 0 ]] && echo "${grep_out}"

echo "SUMMARY: ${job_dir}/${job_out}"
echo "  test name  : result (expected result)"
echo "  ERROR......: $([[ $ERROR -eq 1 ]] && echo 'yes' || echo 'no') (no)"
echo "  FAILED.....: $([[ $FAILED -eq 1 ]] && echo 'yes' || echo 'no') (no)"
echo "  REQ_MISSING: $([[ $MISSING -eq 1 ]] && echo 'yes' || echo 'no') (no)"
echo "  NO_MISSING.: $([[ $NO_MISSING -eq 1 ]] && echo 'yes' || echo 'no') (yes)"
echo "  TGZ_CREATED: $([[ $TGZ -eq 1 ]] && echo 'yes' || echo 'no') (yes)"

job_result_file=_bot_job${SLURM_JOB_ID}.result

if [[ ${SLURM} -eq 1 ]] && \
   [[ ${ERROR} -eq 0 ]] && \
   [[ ${FAILED} -eq 0 ]] && \
   [[ ${MISSING} -eq 0 ]] && \
   [[ ${NO_MISSING} -eq 1 ]] && \
   [[ ${TGZ} -eq 1 ]] && \
   [[ ! -z ${TARBALL} ]]; then
    # SUCCESS
    echo "[RESULT]" > ${job_result_file}
    echo "summary = :grin: SUCCESS" >> ${job_result_file}
    echo "details =" >> ${job_result_file}
else
    # FAILURE
    echo "[RESULT]" > ${job_result_file}
    echo "summary = :cry: FAILURE" >> ${job_result_file}
    echo "details =" >> ${job_result_file}
fi

function succeeded() {
    echo "    :heavy_check_mark: ${1}"
}

function failed() {
    echo "    :heavy_multiplication_x: ${1}"
}

if [[ ${SLURM} -eq 1 ]]; then
    succeeded "job output file <code>${job_out}</code>" >> ${job_result_file}
else
    failed "no job output file matching <code>${GP_slurm_out}</code>" >> ${job_result_file}
fi

if [[ ${ERROR} -eq 0 ]]; then
    succeeded "no message matching <code>${GP_error}</code>" >> ${job_result_file}
else
    failed "found message matching <code>${GP_error}</code>" >> ${job_result_file}
fi

if [[ ${FAILED} -eq 0 ]]; then
    succeeded "no message matching <code>${GP_failed}</code>" >> ${job_result_file}
else
    failed "found message matching <code>${GP_failed}</code>" >> ${job_result_file}
fi

if [[ ${MISSING} -eq 0 ]]; then
    succeeded "no message matching <code>${GP_req_missing}</code>" >> ${job_result_file}
else
    failed "found message matching <code>${GP_req_missing}</code>" >> ${job_result_file}
fi

if [[ ${NO_MISSING} -eq 1 ]]; then
    succeeded "found message(s) matching <code>${GP_no_missing}</code>" >> ${job_result_file}
else
    failed "no message matching <code>${GP_no_missing}</code>" >> ${job_result_file}
fi

if [[ ${TGZ} -eq 1 ]]; then
    succeeded "found message matching <code>${GP_tgz_created}</code>" >> ${job_result_file}
else
    failed "no message matching <code>${GP_tgz_created}</code>" >> ${job_result_file}
fi

echo "artefacts =" >> ${job_result_file}

if [[ ! -z ${TARBALL} ]]; then
    echo "    ${TARBALL}" >> ${job_result_file}
fi

exit 0
