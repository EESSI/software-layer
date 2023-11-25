#!/bin/bash

set -e

EESSI_ROOT=/cvmfs/data.eessi-hpc.org/
TMP_DIR=/tmp/$USER

# checking if all requirements are here
if [ -z `which yq` ]; then
	echo "missing yq, can not continue without..." && exit -1
fi

if [ ! -f eessi-datasets.yml ]; then
	echo "missing eessi-datasets.yml, can not continue without..." && exit -1
fi

if [ ! -f ${EESSI_ROOT}/test ]; then
# if [ ! -d ${EESSI_ROOT}/ ]; then #used for testing while datasets was not in eessi repo
	echo "missing EESSI cvmfs mount, can not continue without..." && exit -1
fi


if [ -f ${TMP_DIR}/dataset_filelist.txt ]; then 
  rm ${TMP_DIR}/dataset_filelist.txt 
fi
if [ -d ${TMP_DIR}/${EESSI_ROOT} ]; then 
  rm -rf ${TMP_DIR}/${EESSI_ROOT}
fi

#looping over yaml file:
#WRF:
# versions:
#  "3.9.1.1":
#    - conus12km_v3911


# read in the application list, for which to ingest datasets
SOFTWARE=`yq e '. | keys' eessi-datasets.yml | awk {'print $2'}`
for APPLICATION in ${SOFTWARE}; do
    echo "checking path for ${APPLICATION}"
    if [ ! -d ${EESSI_ROOT}/${APPLICATION} ]; then
        mkdir -p ${TMP_DIR}/${EESSI_ROOT}/${APPLICATION} || echo "failure to create tmp dir" 
    fi
  
    SOFTWARE_VERSIONS=`yq e ".${APPLICATION}.versions | keys" eessi-datasets.yml | awk {'print $2'}`
    for VERSION in ${SOFTWARE_VERSIONS}; do
        echo "checking path for version ${VERSION:1:-1}"
        if [ ! -d ${EESSI_ROOT}/${APPLICATION}/${VERSION:1:-1} ]; then
	    mkdir -p ${TMP_DIR}/${EESSI_ROOT}/${APPLICATION}/${VERSION:1:-1} || echo "failure to create tmp dir" 
        fi

        DATASETS=`yq e ".${APPLICATION}.versions[${VERSION}]" eessi-datasets.yml | awk {'print $2'}`
        for DATASET in ${DATASETS}; do
            echo "checking path for dataset ${DATASET}"
            if [ -d ${EESSI_ROOT}/${APPLICATION}/${VERSION:1:-1}/${DATASET} ]; then
                echo "path for dataset ${DATASET} seems to exists; skipping...."
	        continue	
	    else
	        mkdir -p ${TMP_DIR}/${EESSI_ROOT}/${APPLICATION}/${VERSION:1:-1}/${DATASET} || echo "failure to create tmp dir" 
            fi
            if [ ! -f datasets/${APPLICATION}/${VERSION:1:-1}/${DATASET}/download.sh ]; then
                echo "download script for ${DATASET} does not seem to exist....please fix repo first"
		exit -1
            fi
	    # running download script with target dir as variable
	    datasets/${APPLICATION}/${VERSION:1:-1}/${DATASET}/download.sh ${TMP_DIR}/${EESSI_ROOT}/${APPLICATION}/${VERSION:1:-1}/${DATASET} ${PWD}/datasets/${APPLICATION}/${VERSION:1:-1}/${DATASET}/

	    # generating filelist
            pushd ${TMP_DIR}/${EESSI_ROOT}
            find ${APPLICATION}/${VERSION:1:-1}/${DATASET} -type f >> ${TMP_DIR}/dataset_filelist.txt
	    popd

        done #DATASET
    done #VERSION
done #APPLICATION

tar cfvz eessi-dataset-$(date +%s).tgz -C ${TMP_DIR}/${EESSI_ROOT} --files-from=${TMP_DIR}/dataset_filelist.txt

# cleaning up afterwards
rm ${TMP_DIR}/dataset_filelist.txt
rm -rf ${TMP_DIR}/${EESSI_ROOT}

