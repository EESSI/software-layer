#!/usr/bin/env bash

# Supported CPU specifications
update_arch_specs(){
    # Add contents of given spec file into an array
    # 1: array with CPU arch specs
    # 2: spec file with the additional specs

    [ -z "$1" ] && echo "[ERROR] update_arch_specs: missing array in argument list" >&2 && exit 1
    local -n arch_specs=$1

    [ ! -f "$2" ] && echo "[ERROR] update_arch_specs: spec file not found: $2" >&2 && exit 1
    local spec_file="$2"
    while read spec_line; do
       # format spec line as an array and append it to array with all CPU arch specs
       arch_specs+=("(${spec_line})")
    # remove comments from spec file
    done < <(sed -E 's/(^|[\s\t])#.*$//g;/^\s*$/d' "$spec_file")
}

# CPU specification of host system
get_cpuinfo(){
    cpuinfo_pattern="^${1}\s*:"
    #grep -i "$cpuinfo_pattern" /proc/cpuinfo | tail -n 1 | sed "s/$cpuinfo_pattern//"
    grep -i "$cpuinfo_pattern" ${EESSI_PROC_CPUINFO:-/proc/cpuinfo} | tail -n 1 | sed "s/$cpuinfo_pattern//"
}

# Find best match
check_flags(){
    for flag in "$@"; do
        [[ " ${CPU_FLAGS[*]} " == *" $flag "* ]] || return 1
    done
    return 0
}

ARGUMENT=${1:-none}

cpupath(){
  # Return the best matching CPU architecture from a list of supported specifications for the host CPU
  local CPU_ARCH_SPEC=()

  # Identify the host CPU architecture
  local MACHINE_TYPE=${EESSI_MACHINE_TYPE:-$(uname -m)}
  echo "[INFO] cpupath: Host CPU architecture identified as $MACHINE_TYPE" >&2

  # Populate list of supported specs for this architecture
  case $MACHINE_TYPE in
      "x86_64") local spec_file="eessi_arch_x86.spec";;
      "aarch64") local spec_file="eessi_arch_arm.spec";;
      "ppc64le") local spec_file="eessi_arch_ppc.spec";;
      *) echo "[ERROR] cpupath: Unsupported CPU architecture $MACHINE_TYPE" >&2 && exit 1
  esac
  # spec files are located in a subfolder with this script
  local base_dir=$(dirname $(realpath $0))
  update_arch_specs CPU_ARCH_SPEC "$base_dir/arch_specs/${spec_file}"

  #CPU_VENDOR_TAG="vendor_id"
  CPU_VENDOR_TAG="vendor[ _]id"
  CPU_VENDOR=$(get_cpuinfo "$CPU_VENDOR_TAG")
  CPU_VENDOR=$(echo ${CPU_VENDOR#*:} | xargs echo -n)
  echo "== CPU vendor of host system: $CPU_VENDOR" >&2

  CPU_FLAG_TAG='flags'
  # cpuinfo systems print different line identifiers, eg features, instead of flags
  [ "${CPU_VENDOR}" == "ARM" ] && CPU_FLAG_TAG='flags'
  [ "${MACHINE_TYPE}" == "aarch64" ] && [ "${CPU_VENDOR}x" == "x" ] && CPU_FLAG_TAG='features'
  [ "${MACHINE_TYPE}" == "ppc64le" ] && CPU_FLAG_TAG='cpu'

  CPU_FLAGS=$(get_cpuinfo "$CPU_FLAG_TAG")
  echo "== CPU flags of host system: $CPU_FLAGS" >&2

  # Default to generic CPU
  BEST_MATCH="generic"

  for arch in "${CPU_ARCH_SPEC[@]}"; do
    eval "arch_spec=$arch"
    if [ "${CPU_VENDOR}x" == "${arch_spec[1]}x" ]; then
        check_flags ${arch_spec[2]} && BEST_MATCH=${arch_spec[0]}
        echo "== got a match with $BEST_MATCH" >&2
    fi
  done

  echo "Best match is $BEST_MATCH" >&2
  echo "$BEST_MATCH"
}

if [ ${ARGUMENT} == "none" ]; then
    echo usage: $0 cpupath
    exit
elif [ ${ARGUMENT} == "cpupath" ]; then
    cpupath
    exit
fi
