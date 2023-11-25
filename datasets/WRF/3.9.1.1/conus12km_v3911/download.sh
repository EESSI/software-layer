#!/bin/bash

echo starting download script
TARGET_DIR=$1
SCRIPT_DIR=$2

if [ ! -d ${TARGET_DIR} ]; then
  echo ${TARGET_DIR} does not exist, exiting....
  exit
fi
if [ ! -d ${SCRIPT_DIR} ]; then
  echo ${SCRIPT_DIR} does not exist, exiting....
  exit
fi
cd $TARGET_DIR
wget http://www2.mmm.ucar.edu/wrf/bench/conus12km_v3911/bench_12km.tar.bz2
sha256sum -c ${SCRIPT_DIR}/bench_12km.tar.bz2.sha256 || exit "sha256sum incorrrect"
bunzip2 bench_12km.tar.bz2
tar -xf bench_12km.tar
rm -rf bench_12km.tar
