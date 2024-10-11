# This can be leveraged by the source_sh() feature of Lmod
export EESSI_ACCEL_SUBDIR=$($(dirname $(readlink -f $BASH_SOURCE))/eessi_archdetect.sh accelpath)
