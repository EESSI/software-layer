#!/bin/bash

input_file=$1
duration_threshold=${2:-180}  # Default threshold to 180 minutes if not given

prev_eb_version="0.0.0"
easystack_num=0
current_duration_sum=0
total_duration_sum=0
current_stack_name=""

while read app; do
  # Extract JSON keys to shell variables
  eval $(echo $app | jq -r '. | to_entries | .[] | .key + "=" + (.value | @sh)')

  # Check if we need to start a new easystack
  if [[ ${prev_eb_version} != ${easybuild} ]] || (( current_duration_sum + build_duration_minutes > duration_threshold )); then
    if [[ ${current_stack_name} != "" ]]; then
      { echo "# ${current_stack_name}: total build duration = ${current_duration_sum} minutes"; cat "${easystack}"; } > temp && mv temp "${easystack}"
    fi
    easystack_num=$(( easystack_num + 1 ))
    prev_eb_version=${easybuild}
    current_duration_sum=0
    current_stack_name="$(printf '%03d\n' ${easystack_num})-eb-${easybuild}.yml"
  fi

  easystack="${current_stack_name}"
  if [[ ! -f "${easystack}" ]]; then
    echo "easyconfigs:" > "${easystack}"
  fi

  echo "  - ${easyconfig}:" >> "${easystack}"
  echo "      options:" >> "${easystack}"
  echo "        include-easyblocks: ${easyblocks}" >> "${easystack}"

  current_duration_sum=$(( current_duration_sum + build_duration_minutes ))
  total_duration_sum=$(( total_duration_sum + build_duration_minutes ))

done < <(jq -c '.[]' "${input_file}")

# Print final stack duration
if [[ ${current_stack_name} != "" ]]; then
  { echo "# ${current_stack_name}: total build duration = ${current_duration_sum} minutes"; cat "${easystack}"; } > temp && mv temp "${easystack}"
fi

for file in *.yml; do
  cat "$file" | head -n 1
done

# Print overall total
echo "Overall total build duration = ${total_duration_sum} minutes"
