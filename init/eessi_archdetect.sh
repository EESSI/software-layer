#!/usr/bin/env bash

# x86_64 CPU architecture specifications
arch_x86=()
arch_x86+=('("x86_64/intel/haswell"  "GenuineIntel"  "avx2 fma")') # Intel Haswell, Broadwell
arch_x86+=('("x86_64/intel/skylake_avx512"  "GenuineIntel"  "avx2 fma avx512f")') # Intel Skylake, Cascade Lake
arch_x86+=('("x86_64/amd/zen2"     "AuthenticAMD"  "avx2 fma")') # AMD Rome
arch_x86+=('("x86_64/amd/zen3"     "AuthenticAMD"  "avx2 fma vaes")') # AMD Milan, Milan-X

# ARM CPU architecture specifications
arch_arm=()
arch_arm+=('("aarch64/arm/neoverse-n1"      "ARM"   "asimd")') # Ampere Altra
arch_arm+=('("aarch64/arm/neoverse-n1"      ""   "asimd")') # AWS Graviton2
arch_arm+=('("aarch64/arm/neoverse-v1"      "ARM"   "asimd svei8mm")') 
arch_arm+=('("aarch64/arm/neoverse-v1"      ""   "asimd svei8mm")') # AWS Graviton3

# Power CPU architecture specifications
arch_power=()
arch_power+=('("ppc64le/power9le"      ""   "POWER9")') # IBM Power9

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

cpupath () {
  #MACHINE_TYPE=$(uname -m)
  MACHINE_TYPE=${EESSI_MACHINE_TYPE:-$(uname -m)}
  echo cpu architecture seems to be $MACHINE_TYPE >&2 
  [ "${MACHINE_TYPE}" == "x86_64" ] && CPU_ARCH_SPEC=("${arch_x86[@]}")
  [ "${MACHINE_TYPE}" == "aarch64" ] && CPU_ARCH_SPEC=("${arch_arm[@]}")
  [ "${MACHINE_TYPE}" == "ppc64le" ] && CPU_ARCH_SPEC=("${arch_power[@]}")
  [[ -z $CPU_ARCH_SPEC ]] && echo "ERROR: Unsupported CPU architecture $MACHINE_TYPE" && exit

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
    echo $(cpupath)
    exit
fi
