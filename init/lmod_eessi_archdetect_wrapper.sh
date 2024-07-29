# This can be leveraged by the source_sh() feature of Lmod
export EESSI_ARCHDETECT_OPTIONS=$($(dirname $(readlink -f $BASH_SOURCE))/eessi_archdetect.sh -a cpupath)
