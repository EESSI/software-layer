#!/bin/bash

# current pathways implemented in EESSI
# x86_64/generic
# x86_64/intel/haswell
# x86_64/intel/skylake_avx512
# x86_64/amd/zen2
# x86_64/amd/zen3
# aarch64/generic
# ppc64le/generic
# ppc64le/power9le

ARGUMENT=${1:-none}

cpupath () {
  # let the kernel tell base machine type
  MACHINE_TYPE=$(uname -m)

  # fallback path
  CPU_PATH="${MACHINE_TYPE}/generic"

  if [ ${MACHINE_TYPE} == "aarch64" ]; then
    echo ${CPU_PATH}
    exit
  fi

  if [ ${MACHINE_TYPE} == "ppc64le" ]; then
    echo ${CPU_PATH} "not sure what to do next..."
    echo "please mail output of lscpu to me..."
    exit
  fi

  if [ ${MACHINE_TYPE} == "x86_64" ]; then
    # check for vendor info, if available, for x86_64
    CPUINFO_VENDOR_FLAG=$(grep -m 1 ^vendor_id /proc/cpuinfo)
    [[ $CPUINFO_VENDOR_FLAG =~ .*GenuineIntel* ]] && CPU_VENDOR=intel
    [[ $CPU_VENDOR_FLAG =~ .*AuthenticAMD* ]] && CPU_VENDOR=amd

    CPU_FLAGS=$(grep -m 1 ^flags /proc/cpuinfo)
    [[ $CPU_FLAGS =~ .*avx2* ]] && HAS_AVX2=true
    [[ $CPU_FLAGS =~ .*fma* ]] && HAS_FMA=true
    [[ $CPU_FLAGS =~ .*avx512f* ]] && HAS_AVX512F=true
    [[ $CPU_FLAGS =~ .*avx512vl* ]] && HAS_AVX512VL=true
    [[ $CPU_FLAGS =~ .*avx512ifma* ]] && HAS_AVX512IFMA=true
    [[ $CPU_FLAGS =~ .*avx512_vbmi2* ]] && HAS_AVX512_VBMI2=true
    [[ $CPU_FLAGS =~ .*avx512_vnni* ]] && HAS_AVX512_VNNI=true
    [[ $CPU_FLAGS =~ .*avx512fp16* ]] && HAS_AVX512FP16=true

    [[ ${CPU_VENDOR} == "intel" ]] && [[ ${HAS_AVX2} ]] && [[ ${HAS_FMA} ]] && CPU_TYPE=haswell 
    [[ ${CPU_VENDOR} == "intel" ]] && [[ ${HAS_AVX512F} ]] && CPU_TYPE=skylake_avx512
    # [[ ${HAS_AVX512IFMA} ]] && [[ ${HAS_AVX512_VBMI2} ]] && CPU_TYPE=icelake_avx512
    # [[ ${HAS_AVX512_VNNI} ]] && [[ ${HAS_AVX512VL} ]] && [[ ${HAS_AVX512FP16} ]] && CPU_TYPE=sapphire_rapids_avx512

    [[ ${CPU_VENDOR} ]] && [[ $CPU_TYPE ]] && CPU_PATH="${MACHINE_TYPE}/${CPU_VENDOR}/${CPU_TYPE}"

    echo ${CPU_PATH}
    exit
  fi

  echo "should not see this...something weird going on..."
  echo "please mail output of lscpu to me..."
}

if [ ${ARGUMENT} == "none" ]; then
  echo usage: $0 cpupath
  exit
elif [ ${ARGUMENT} == "cpupath" ]; then
  echo $(cpupath)
  exit
fi
