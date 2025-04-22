#!/bin/bash

input_file=$1

prev_eb_version="0.0.0"
#prev_toolchain="none"
easystack_num=0

while read app
do
  eval $(echo $app | jq -r '. | to_entries | .[] | .key + "=" + (.value | @sh)')

  #if [[ ${prev_toolchain} != ${toolchain} ]] || [[ ${prev_eb_version} != ${easybuild} ]]; then
  if [[ ${prev_eb_version} != ${easybuild} ]]; then
    easystack_num=$(( easystack_num + 1))
    #prev_toolchain=${toolchain}
    prev_eb_version=${easybuild}
  fi

  #easystack="$(printf '%03d\n' ${easystack_num})-eb-${easybuild}-${toolchain}.yml"
  easystack="$(printf '%03d\n' ${easystack_num})-eb-${easybuild}.yml"
  if [ ! -f "${easystack}" ]; then
    echo "easyconfigs:" > ${easystack}
  fi
  echo "  - ${easyconfig}:" >> ${easystack}
  echo "      options:" >> ${easystack}
  echo "        include-easyblocks: ${easyblocks}" >> ${easystack}
done < <(jq -c '.[]' ${input_file})
