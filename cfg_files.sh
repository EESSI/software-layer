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
declare -A cfg_file_map


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
      #cur_key=$(echo $val | cut -f1 -d'=' | sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//')
      cur_key=$(echo $val | cut -f1 -d'=' | cfg_trim_spaces)
      #cur_val=$(echo $val | cut -f2 -d'=' | sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//')
      cur_val=$(echo $val | cut -f2 -d'=' | cfg_trim_spaces)
      if [[ -n "$cur_key" ]]; then
        # section + key is the associative in bash array, the field separator is space
        cfg_repos[${cur_section} ${cur_key}]=$cur_val
      fi
    fi
  done <$1
}

function cfg_print {
  for index in "${!cfg_repos[@]}"
  do
    # split the associative key in to section and key
    echo -n "section  : $(echo $index | cut -f1 -d ' ');"
    echo -n "key  : $(echo $index | cut -f2 -d ' ');"
    echo  "value: ${cfg_repos[$index]}"
  done
}

function cfg_get_value {
  section=$1
  key=$2
  echo "${cfg_repos[$section $key]}"
}

function cfg_trim_spaces {
  # reads from argument $1 or stdin
  if [[ $# -gt 0 ]]; then
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<< ${1}
  else
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' < /dev/stdin
  fi
}

function cfg_trim_quotes {
  # reads from argument $1 or stdin
  if [[ $# -gt 0 ]]; then
    sed -e 's/^"*//' -e 's/"*$//' <<< ${1}
  else
    sed -e 's/^"*//' -e 's/"*$//' < /dev/stdin
  fi
}

function cfg_trim_curly_brackets {
  # reads from argument $1 or stdin
  if [[ $# -gt 0 ]]; then
    sed -e 's/^{*//' -e 's/}*$//' <<< ${1}
  else
    sed -e 's/^{*//' -e 's/}*$//' < /dev/stdin
  fi
}

function cfg_get_all_sections {
  # first field in keys
  # 1. get first field in all keys, 2. filter duplicates, 3. return them as string
  declare -A all_sections
  for key in "${!cfg_repos[@]}"
  do
    section=$(echo "$key" | cut -f1 -d' ')
    all_sections[${section}]=1
  done
  sections=
  for sec_key in "${!all_sections[@]}"
  do
    sections="${sections} ${sec_key}"
  done
  echo "${sections}" | cfg_trim_spaces
}

function cfg_init_file_map {
  # strip '{' and '}' from config_map
  # split config_map at ','
  # for each item: split at ':' use first as key, second as value

  # reset global variable
  cfg_file_map=()

  # expects a string containing the config_map from the cfg file
  # trim leading and trailing curly brackets
  cm_trimmed=$(cfg_trim_curly_brackets "$1")

  # split into elements along ','
  declare -a cm_mappings
  IFS=',' read -r -a cm_mappings <<< "${cm_trimmed}"

  for index in "${!cm_mappings[@]}"
  do
    # split mapping into key and value
    map_key=$(echo ${cm_mappings[index]} | cut -f1 -d':')
    map_value=$(echo ${cm_mappings[index]} | cut -f2 -d':')
    # trim spaces and double quotes at start and end
    tr_key=$(cfg_trim_spaces "${map_key}" | cfg_trim_quotes)
    tr_value=$(cfg_trim_spaces "${map_value}" | cfg_trim_quotes)
    cfg_file_map[${tr_key}]=${tr_value}
  done
}

function cfg_print_map {
  for index in "${!cfg_file_map[@]}"
  do
    echo "${index} --> ${cfg_file_map[${index}]}"
  done
}

