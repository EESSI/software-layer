# functions for working with ini/cfg files
#
# This file is part of the EESSI software layer, see
# https://github.com/EESSI/software-layer.git
#
# author: Thomas Roeblitz (@trz42)
#
# license: GPLv2
#


# global variables
# -a -> indexed array
# -A -> associative array
declare -A cfg_repos


# functions
function cfg_get_section {
  if [[ "$1" =~ ^(\[)(.*)(\])$ ]]; then
    echo ${BASH_REMATCH[2]}
  else
    echo ""
  fi
}

function cfg_get_key_value {
  if [[ "$1" =~ ^([^=]+)=([^=]+)$ ]]; then
    echo "${BASH_REMATCH[1]}=${BASH_REMATCH[2]}"
  else
    echo ""
  fi
}

function cfg_load {
  local cur_section=""
  local cur_key=""
  local cur_val=""
  IFS=
  while read -r line; do
    new_section=$(cfg_get_section $line)
    # got a new section
    if [[ -n "$new_section" ]]; then
      cur_section=$new_section
    # not a section, try a key value
    else
      val=$(cfg_get_key_value $line)
      # trim leading and trailing spaces as well
      cur_key=$(echo $val | cut -f1 -d'=' | sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//')
      cur_val=$(echo $val | cut -f2 -d'=' | sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//')
      if [[ -n "$cur_key" ]]; then
        # section + key is the associative in bash array, the field separator is space
        repo_cfg[${cur_section} ${cur_key}]=$cur_val
      fi
    fi
  done <$1
}

function cfg_print {
    for i in "${!repo_cfg[@]}"
    do
    # split the associative key in to section and key
       echo -n "section  : $(echo $i | cut -f1 -d ' ');"
       echo -n "key  : $(echo $i | cut -f2 -d ' ');"
       echo  "value: ${repo_cfg[$i]}"
    done
}

function cfg_get_value {
    section=$1
    key=$2
    echo "${repo_cfg[$section $key]}"
}
