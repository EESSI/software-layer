#!/bin/bash

# current pathways implemented in EESSI 2021.12 pilot version
# x86_64/generic
# x86_64/intel/haswell
# x86_64/intel/skylake_avx512
# x86_64/amd/zen2
# x86_64/amd/zen3
# aarch64/generic
# aarch64/graviton2
# aarch64/graviton3
# ppc64le/generic
# ppc64le/power9le

ARGUMENT=${1:-none}

cpupath () {
  # let the kernel tell base machine type
  MACHINE_TYPE=${EESSI_MACHINE_TYPE:-$(uname -m)}
  PROC_CPUINFO=${EESSI_PROC_CPUINFO:-/proc/cpuinfo}
  
  # clean up any existing pointers to cpu features
  unset $(env | grep EESSI_HAS | cut -f1 -d=)
  unset EESSI_CPU_VENDOR

  # fallback path
  CPU_PATH="${MACHINE_TYPE}/generic"

  if [ ${MACHINE_TYPE} == "aarch64" ]; then
    CPUINFO_VENDOR_FLAG=$(grep -m 1 -i ^vendor ${PROC_CPUINFO})
    [[ $CPUINFO_VENDOR_FLAG =~ "ARM" ]] && EESSI_CPU_VENDOR=arm

    if [ ${EESSI_CPU_VENDOR} == "arm" ]; then
      CPU_FLAGS=$(grep -m 1 -i ^flags ${PROC_CPUINFO} | sed 's/$/ /g')
    else
      CPU_FLAGS=$(grep -m 1 -i ^features ${PROC_CPUINFO} | sed 's/$/ /g')
    fi

    [[ $CPU_FLAGS =~ " asimd " ]] && EESSI_HAS_ASIMD=true
    [[ $CPU_FLAGS =~ " svei8mm " ]] && EESSI_HAS_SVEI8MM=true

    [[ ${EESSI_HAS_ASIMD} ]] && EESSI_CPU_TYPE=neoverse-n1 #Ampere Altra
    [[ ${EESSI_HAS_SVEI8MM} ]] && EESSI_CPU_TYPE=neoverse-v1
    [[ $EESSI_CPU_TYPE ]] && CPU_PATH="${MACHINE_TYPE}/${EESSI_CPU_VENDOR}/${EESSI_CPU_TYPE}"

    echo ${CPU_PATH}
    exit
  fi

  if [ ${MACHINE_TYPE} == "ppc64le" ]; then
    CPU_FLAGS=$(grep -m 1 -i ^cpu ${PROC_CPUINFO})
    [[ $CPU_FLAGS =~ " POWER9 " ]] && EESSI_HAS_POWER9=true

    [[ ${EESSI_HAS_POWER9} ]] && EESSI_CPU_TYPE=power9le #Power9

    [[ $EESSI_CPU_TYPE ]] && CPU_PATH="${MACHINE_TYPE}/${EESSI_CPU_TYPE}"
    echo ${CPU_PATH}
    exit
  fi

  if [ ${MACHINE_TYPE} == "x86_64" ]; then
    # check for vendor info, if available, for x86_64
    CPUINFO_VENDOR_FLAG=$(grep -m 1 -i ^vendor ${PROC_CPUINFO})
    [[ $CPUINFO_VENDOR_FLAG =~ "GenuineIntel" ]] && EESSI_CPU_VENDOR=intel
    [[ $CPUINFO_VENDOR_FLAG =~ "AuthenticAMD" ]] && EESSI_CPU_VENDOR=amd

    CPU_FLAGS=$(grep -m 1 -i ^flags ${PROC_CPUINFO} | sed 's/$/ /g')
    [[ $CPU_FLAGS =~ " avx2 " ]] && EESSI_HAS_AVX2=true
    [[ $CPU_FLAGS =~ " fma " ]] && EESSI_HAS_FMA=true
    [[ $CPU_FLAGS =~ " avx512f " ]] && EESSI_HAS_AVX512F=true
    [[ $CPU_FLAGS =~ " avx512vl " ]] && EESSI_HAS_AVX512VL=true
    [[ $CPU_FLAGS =~ " avx512ifma " ]] && EESSI_HAS_AVX512IFMA=true
    [[ $CPU_FLAGS =~ " avx512_vbmi2 " ]] && EESSI_HAS_AVX512_VBMI2=true
    [[ $CPU_FLAGS =~ " avx512_vnni " ]] && EESSI_HAS_AVX512_VNNI=true
    [[ $CPU_FLAGS =~ " avx512fp16 " ]] && EESSI_HAS_AVX512FP16=true
    [[ $CPU_FLAGS =~ " vaes " ]] && EESSI_HAS_VAES=true

    if [ ${EESSI_CPU_VENDOR} == "intel" ]; then
      [[ ${EESSI_HAS_AVX2} ]] && [[ ${EESSI_HAS_FMA} ]] && EESSI_CPU_TYPE=haswell #Haswell, Broadwell
      [[ ${EESSI_HAS_AVX512F} ]] && EESSI_CPU_TYPE=skylake_avx512 #Skylake, Cascade Lake
      # [[ ${HAS_AVX512IFMA} ]] && [[ ${HAS_AVX512_VBMI2} ]] && CPU_TYPE=icelake_avx512
      # [[ ${HAS_AVX512_VNNI} ]] && [[ ${HAS_AVX512VL} ]] && [[ ${HAS_AVX512FP16} ]] && CPU_TYPE=sapphire_rapids_avx512
    elif [ ${EESSI_CPU_VENDOR} == "amd" ]; then
      [[ ${EESSI_HAS_AVX2} ]] && [[ ${EESSI_HAS_FMA} ]] && EESSI_CPU_TYPE=zen2 #Rome
      [[ ${EESSI_HAS_AVX2} ]] && [[ ${EESSI_HAS_FMA} ]] && [[ ${EESSI_HAS_VAES} ]] && EESSI_CPU_TYPE=zen3 #Milan, Milan-X
    fi

    [[ ${EESSI_CPU_VENDOR} ]] && [[ $EESSI_CPU_TYPE ]] && CPU_PATH="${MACHINE_TYPE}/${EESSI_CPU_VENDOR}/${EESSI_CPU_TYPE}"

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
