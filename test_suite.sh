#!/bin/bash
#
# This script creates a ReFrame config file from a template, in which CPU properties get replaced
# based on where this script is run (typically: a build node). Then, it runs the EESSI test suite.
#
# This script is part of the EESSI software layer, see
# https://github.com/EESSI/software-layer.git
#
# author: Caspar van Leeuwen (@casparvl)
#
# license: GPLv2

display_help() {
  echo "usage: $0 [OPTIONS]"
  echo "  -g | --generic         -  instructs script to test for generic architecture target"
  echo "  -h | --help            -  display this usage information"
  echo "  -x | --http-proxy URL  -  provides URL for the environment variable http_proxy"
  echo "  -y | --https-proxy URL -  provides URL for the environment variable https_proxy"
}

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -g|--generic)
      DETECTION_PARAMETERS="--generic"
      shift
      ;;
    -h|--help)
      display_help  # Call your function
      # no shifting needed here, we're done.
      exit 0
      ;;
    -x|--http-proxy)
      export http_proxy="$2"
      shift 2
      ;;
    -y|--https-proxy)
      export https_proxy="$2"
      shift 2
      ;;
    --build-logs-dir)
      export build_logs_dir="${2}"
      shift 2
      ;;
    --shared-fs-path)
      export shared_fs_path="${2}"
      shift 2
      ;;
    -*|--*)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
    *)  # No more options
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"

TOPDIR=$(dirname $(realpath $0))

source $TOPDIR/scripts/utils.sh

# honor $TMPDIR if it is already defined, use /tmp otherwise
if [ -z $TMPDIR ]; then
    export WORKDIR=/tmp/$USER
else
    export WORKDIR=$TMPDIR/$USER
fi

TMPDIR=$(mktemp -d)

echo ">> Setting up environment..."
# For this call to be succesful, it needs to be able to import archspec (which is part of EESSI)
# Thus, we execute it in a subshell where EESSI is already initialized (a bit like a bootstrap)
export EESSI_SOFTWARE_SUBDIR_OVERRIDE=$(source $TOPDIR/init/bash > /dev/null 2>&1; python3 $TOPDIR/eessi_software_subdir.py $DETECTION_PARAMETERS)
echo "EESSI_SOFTWARE_SUBDIR_OVERRIDE: $EESSI_SOFTWARE_SUBDIR_OVERRIDE"

source $TOPDIR/init/bash

# We have to ignore the LMOD cache, otherwise the software that is built in the build step cannot be found/loaded
# Reason is that the LMOD cache is normally only updated on the Stratum 0, once everything is ingested
export LMOD_IGNORE_CACHE=1

# Load the ReFrame module
# Currently, we load the default version. Maybe we should somehow make this configurable in the future?
module load ReFrame
if [[ $? -eq 0 ]]; then
    echo_green ">> Loaded ReFrame module"
else
    fatal_error "Failed to load the ReFrame module"
fi

# Check that a system python3 is available
python3_found=$(command -v python3)
if [ -z ${python3_found} ]; then
    fatal_error "No system python3 found"
else
    echo_green "System python3 found:"
    python3 -V
fi

# Check ReFrame came with the hpctestlib and we can import it
reframe_import="hpctestlib.sciapps.gromacs"
python3 -c "import ${reframe_import}"
if [[ $? -eq 0 ]]; then
    echo_green "Succesfully found and imported ${reframe_import}"
else
    fatal_error "Failed to import ${reframe_import}"
fi

# Cloning should already be done in run_tests.sh before test_suite.sh is invoked
# Check if that succeeded
export TESTSUITEPREFIX=$PWD/EESSI-test-suite
if [ -d $TESTSUITEPREFIX ]; then
    echo_green "Clone of the test suite $TESTSUITEPREFIX available, OK!"
else
    fatal_error "Clone of the test suite $TESTSUITEPREFIX is not available!"
fi
export PYTHONPATH=$TESTSUITEPREFIX:$PYTHONPATH

# Check that we can import from the testsuite
testsuite_import="eessi.testsuite"
python3 -c "import ${testsuite_import}"
if [[ $? -eq 0 ]]; then
    echo_green "Succesfully found and imported ${testsuite_import}"
else
    fatal_error "Failed to import ${testsuite_import}"
fi

# Configure ReFrame, see https://www.eessi.io/docs/test-suite/installation-configuration
export RFM_CONFIG_FILES=$TOPDIR/reframe_config_bot.py
export RFM_CONFIG_FILE_TEMPLATE=$TOPDIR/reframe_config_bot.py.tmpl
export RFM_CHECK_SEARCH_PATH=$TESTSUITEPREFIX/eessi/testsuite/tests
export RFM_CHECK_SEARCH_RECURSIVE=1
export RFM_PREFIX=$PWD/reframe_runs

echo "Configured reframe with the following environment variables:"
env | grep "RFM_"

# Inject correct CPU/memory properties into the ReFrame config file
echo "Collecting system-specific input for the ReFrame configuration file"
cpuinfo=$(lscpu)
if [[ "${cpuinfo}" =~ CPU\(s\):[^0-9]*([0-9]+) ]]; then
    cpu_count=${BASH_REMATCH[1]}
    echo "Detected CPU count: ${cpu_count}"
else
    fatal_error "Failed to get the number of CPUs for the current test hardware with lscpu."
fi
if [[ "${cpuinfo}" =~ Socket\(s\):[^0-9]*([0-9]+) ]]; then
    socket_count=${BASH_REMATCH[1]}
    echo "Detected socket count: ${socket_count}"
else
    fatal_error "Failed to get the number of sockets for the current test hardware with lscpu."
fi
if [[ "${cpuinfo}" =~ (Thread\(s\) per core:[^0-9]*([0-9]+)) ]]; then
    threads_per_core=${BASH_REMATCH[2]}
    echo "Detected threads per core: ${threads_per_core}"
else
    fatal_error "Failed to get the number of threads per core for the current test hardware with lscpu."
fi
if [[ "${cpuinfo}" =~ (Core\(s\) per socket:[^0-9]*([0-9]+)) ]]; then
    cores_per_socket=${BASH_REMATCH[2]}
    echo "Detected cores per socket: ${cores_per_socket}"
else
    fatal_error "Failed to get the number of cores per socket for the current test hardware with lscpu."
fi

# The /sys inside the container is not the same as the /sys of the host
# We want to extract the memory limit from the cgroup on the host (which is typically set by SLURM).
# Thus, bot/test.sh bind-mounts the host's /sys/fs/cgroup into /hostsys/fs/cgroup
# and that's the prefix we use to extract the memory limit from
cgroup_v1_mem_limit="/hostsys/fs/cgroup/memory/$(</proc/self/cpuset)/memory.limit_in_bytes"
cgroup_v2_mem_limit="/hostsys/fs/cgroup/$(</proc/self/cpuset)/memory.max"
if [ -f "$cgroup_v1_mem_limit" ]; then
    echo "Getting memory limit from file $cgroup_v1_mem_limit"
    cgroup_mem_bytes=$(cat "$cgroup_v1_mem_limit")
elif [ -f "$cgroup_v2_mem_limit" ]; then
    echo "Getting memory limit from file $cgroup_v2_mem_limit"
    cgroup_mem_bytes=$(cat "$cgroup_v2_mem_limit")
    if [ "$cgroup_mem_bytes" = 'max' ]; then
        # In cgroupsv2, the memory.max file may contain 'max', meaning the group can use the full system memory
        # Here, we get the system memory from /proc/meminfo. Units are supposedly always in kb, but lets match them too
        cgroup_mem_kilobytes=$(grep -oP 'MemTotal:\s+\K\d+(?=\s+kB)' /proc/meminfo)
        if [[ $? -ne 0 ]] || [[ -z "$cgroup_mem_kilobytes" ]]; then
            fatal_error "Failed to get memory limit from /proc/meminfo"
        fi
        cgroup_mem_bytes=$(("$cgroup_mem_kilobytes"*1024))
    fi
else
    fatal_error "Both files ${cgroup_v1_mem_limit} and ${cgroup_v2_mem_limit} couldn't be found. Failed to get the memory limit from the current cgroup"
fi
if [[ $? -eq 0 ]]; then
    # Convert to MiB
    cgroup_mem_mib=$(("$cgroup_mem_bytes"/(1024*1024)))
else
    fatal_error "Failed to get the memory limit in bytes from the current cgroup"
fi
echo "Detected available memory: ${cgroup_mem_mib} MiB"

# echo "Replacing detected system information in template ReFrame config file..."
# cp ${RFM_CONFIG_FILE_TEMPLATE} ${RFM_CONFIG_FILES}
# sed -i "s/__NUM_CPUS__/${cpu_count}/g" $RFM_CONFIG_FILES
# sed -i "s/__NUM_SOCKETS__/${socket_count}/g" $RFM_CONFIG_FILES
# sed -i "s/__NUM_CPUS_PER_CORE__/${threads_per_core}/g" $RFM_CONFIG_FILES
# sed -i "s/__NUM_CPUS_PER_SOCKET__/${cores_per_socket}/g" $RFM_CONFIG_FILES
# sed -i "s/__MEM_PER_NODE__/${cgroup_mem_mib}/g" $RFM_CONFIG_FILES
echo "Replacing partition name in the template ReFrame config file, to trigger CPU autodetection for this job"
cp ${RFM_CONFIG_FILE_TEMPLATE} ${RFM_CONFIG_FILES}
RFM_PARTITION="$SLURM_JOB_ID"
sed -i "s/__RFM_PARTITION__/${RFM_PARTITION}/g" $RFM_CONFIG_FILES

# Make debugging easier by printing the final config file:
echo "Final config file (after replacements):"
cat "${RFM_CONFIG_FILES}"

# Workaround for https://github.com/EESSI/software-layer/pull/467#issuecomment-1973341966
export PSM3_DEVICES='self,shm'  # this is enough, since we only run single node for now

# Check we can run reframe
reframe --version
if [[ $? -eq 0 ]]; then
    echo_green "Succesfully ran 'reframe --version'"
else
    fatal_error "Failed to run 'reframe --version'"
fi

# List the tests we want to run
export REFRAME_ARGS='--tag CI --tag 1_node --nocolor'
echo "Listing tests: reframe ${REFRAME_ARGS} --list"
reframe ${REFRAME_ARGS} --list
if [[ $? -eq 0 ]]; then
    echo_green "Succesfully listed ReFrame tests with command: reframe ${REFRAME_ARGS} --list"
else
    fatal_error "Failed to list ReFrame tests with command: reframe ${REFRAME_ARGS} --list"
fi

# Run all tests
echo "Running tests: reframe ${REFRAME_ARGS} --run"
reframe ${REFRAME_ARGS} --run
reframe_exit_code=$?
if [[ ${reframe_exit_code} -eq 0 ]]; then
    echo_green "ReFrame runtime ran succesfully with command: reframe ${REFRAME_ARGS} --run."
else
    fatal_error "ReFrame runtime failed to run with command: reframe ${REFRAME_ARGS} --run."
fi

echo ">> Cleaning up ${TMPDIR}..."
rm -r ${TMPDIR}

RFM_SYSTEM=$(python3 -c "import ${RFM_CONFIG_FILES}; site_configuration['systems'][0]['name']")
RFM_TOPOLOGY_FILE="${HOME}/.reframe/topology/${RFM_SYSTEM}-${RFM_PARTITION}/processor.json"
echo ">> Cleaning up ReFrame CPU topology file"

exit ${reframe_exit_code}
