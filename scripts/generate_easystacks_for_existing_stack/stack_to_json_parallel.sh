#!/bin/bash

# Usage: ./script.sh [MAX_JOBS]
MAX_JOBS=${1:-4}  # Default to 4 concurrent jobs if not specified
DEBUG=0
BASE_STACK=/cvmfs/software.eessi.io/versions/2023.06/software/linux/x86_64/intel/haswell/software
EB_BOOTSTRAP=5.0.0
TMPDIR=$(mktemp -d)

declare -A gcc_to_foss=( ["12.2.0"]="2022b" ["12.3.0"]="2023a" ["13.2.0"]="2023b" )

if [[ ! -d ${BASE_STACK} ]]; then
  echo "The given base stack (${BASE_STACK}) is not a directory."
  exit 1
fi

apps=$(find ${BASE_STACK} -mindepth 2 -maxdepth 2 -type d)

# Job limiter
job_count=0
run_limited() {
  ((job_count++))
  if (( job_count >= MAX_JOBS )); then
    wait -n  # wait for one job to finish
    ((job_count--))
  fi
}

for app_dir in $apps; do
run_limited
(
  app_version=$(basename "${app_dir}")
  app_name=$(basename "$(dirname "${app_dir}")")

  if [[ ${app_name} == "EESSI-extend" ]]; then
    exit 0
  fi

  easyblocks=${app_dir}/easybuild/reprod/easyblocks/*.py
  easyconfig=${app_dir}/easybuild/${app_name}-${app_version}.eb

  if [[ ! -f ${easyconfig} ]]; then
    echo "ERROR: cannot find easyconfig for ${app_name}/${app_version}" >&2
    exit 1
  fi

  log_file=$(ls -1 ${app_dir}/easybuild/easybuild-${app_name}*.log* 2>/dev/null | tail -n 1)
  build_time_start=$(bzcat "${log_file}" | head -n 1 | awk '{print $2 "T" $3}' | cut -d, -f1)
  build_time_end=$(bzcat "${log_file}" | tail -n 1 | awk '{print $2 "T" $3}' | cut -d, -f1)
  build_duration=$(( ($(date +%s -d "${build_time_end}") - $(date +%s -d "${build_time_start}")) / 60 ))

  eb_version=$(bzgrep -oP "This is EasyBuild \K([0-9]+\.[0-9]+\.[0-9]+)" "${log_file}" | head -n 1)
  if [[ ${app_name} == "EasyBuild" ]] && [[ ${app_version} == ${eb_version} ]]; then
    eb_version=${EB_BOOTSTRAP}
  fi

  if [[ ${app_version} != *-* ]]; then
    toolchain="SYSTEM"
  else
    if [[ ${app_version} == *-GCC* ]]; then
      gcc_ver=$(echo ${app_version} | grep -oP "(GCC|GCCcore)-\K.*?(?=-|$)")
      toolchain=${gcc_to_foss[$gcc_ver]}
    else
      toolchain=$(echo ${app_version} | grep -oP "(foss|gfbf|gompi)-\K.*?(?=-|$)")
    fi
  fi

  jq --null-input \
    --arg build_time "${build_time_start}" \
    --arg build_duration_minutes "${build_duration}" \
    --arg name "${app_name}" \
    --arg version "${app_version}" \
    --arg easybuild "${eb_version}" \
    --arg toolchain  "${toolchain}" \
    --arg easyconfig  "${easyconfig}" \
    --arg easyblocks  "${easyblocks}" \
    '$ARGS.named' > "${TMPDIR}/${app_name}_${app_version}.json"

  [[ ${DEBUG} -ne 0 ]] && echo "Processed ${app_name}/${app_version}" >&2
) &
done

wait

# Combine all results and sort by build time
jq -s 'sort_by(.build_time)' "${TMPDIR}"/*.json

# Optional cleanup
rm -r "${TMPDIR}"

