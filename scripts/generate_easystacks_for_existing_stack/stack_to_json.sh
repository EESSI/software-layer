#!/bin/bash

DEBUG=0
BASE_STACK=/cvmfs/software.eessi.io/versions/2023.06/software/linux/x86_64/intel/haswell/software
EB_BOOTSTRAP=4.9.4

declare -A gcc_to_foss=( ["12.2.0"]="2022b" ["12.3.0"]="2023a" ["13.2.0"]="2023b" )

if [[ ! -d ${BASE_STACK} ]]; then
  echo "The given base stack (${BASE_STACK}) is not a directory."
  exit 1
fi

apps=$(find ${BASE_STACK} -mindepth 2 -maxdepth 2 -type d)

json_output="["
for app_dir in $apps; do
  app_version=$(basename ${app_dir})
  app_name=$(basename $(dirname ${app_dir}))

  if [[ ${app_name} == "EESSI-extend" ]]; then
    # Skip EESSI-extend, as it will be installed automatically.
    continue
  fi

  easyblocks=${app_dir}/easybuild/reprod/easyblocks/*.py
  easyconfig=${app_dir}/easybuild/reprod/${app_name}-${app_version}.eb
  if [[ ! -f ${easyconfig} ]]; then
    echo "ERROR: cannot find easyconfig for ${app_name}/${app_version}"
  fi
  # If rebuilds would not remove the original log file, we should take the build time from the first log.
  # As we cannot guarantee that at the moment, we are cautious and use the last one.
  log_file=$(ls -1 ${app_dir}/easybuild/easybuild-${app_name}*.log* | tail -n 1)
  build_time_start=$(bzcat ${log_file} | head -n 1 | awk '{print $2 "T" $3}' | cut -d, -f1)
  build_time_end=$(bzcat ${log_file} | tail -n 1 | awk '{print $2 "T" $3}' | cut -d, -f1)
  #build_time_unix=$( date +%s -d ${build_time})
  build_duration=$(( ($(date +%s -d ${build_time_end}) - $(date +%s -d ${build_time_start}))/60 ))

  eb_version=$(bzgrep -oP "This is EasyBuild \K([0-9].[0-9].[0-9])" ${log_file} | head -n 1)
  # Some EB versions have been installed with a temporary EB installation of the same version.
  # If that's the case, use the version specified with ${EB_BOOTSTRAP} instead.
  # This needs to correspond to the version that gets installed initially by EESSI-install-software.sh,
  # which should be the latest EB version available when that script is being run.
  if [[ ${app_name} == "EasyBuild" ]] && [[ ${app_version} == ${eb_version} ]]; then
    eb_version=${EB_BOOTSTRAP}
  fi

  if [[ ${app_version} != *-* ]]; then
    toolchain=SYSTEM
  else
    if [[ ${app_version} == *-GCC* ]]; then
      gcc_ver=$(echo ${app_version} | grep -oP "(GCC|GCCcore)-\K.*?(?=-|$)")
      toolchain=${gcc_to_foss[$gcc_ver]}
    else
      toolchain=$(echo ${app_version} | grep -oP "(foss|gfbf|gompi)-\K.*?(?=-|$)")
    fi
  fi

  json=$(
    jq --null-input \
      --arg build_time "${build_time_start}" \
      --arg build_duration_minutes "${build_duration}" \
      --arg name "${app_name}" \
      --arg version "${app_version}" \
      --arg easybuild "${eb_version}" \
      --arg toolchain  "${toolchain}" \
      --arg easyconfig  "${easyconfig}" \
      --arg easyblocks  "${easyblocks}" \
      '$ARGS.named' # requires jq 1.7 or newer
      #'{build_time: $build_time, build_duration_minutes: $build_duration, name: $name, version: $version, easybuild: $easybuild,
      #  toolchain: $toolchain, easyconfig: $easyconfig, easyblocks: $easyblocks}'
  )

  if [[ ${json_output} == "[" ]]; then
    json_output="${json_output}${json}"
  else
    json_output="${json_output},${json}"
  fi
  [[ ${DEBUG} -ne 0 ]] && echo ${build_time_unix} ${app_name} ${app_version} ${eb_version} ${toolchain} ${easyconfig} ${easyblocks}
done #| sort -nu
json_output="${json_output}]"

[[ ${DEBUG} -ne 0 ]] && echo ${json_output}
echo ${json_output} | jq 'sort_by(.build_time)'
