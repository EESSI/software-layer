#!/usr/bin/env bash

# This script can be used to install the host MPI libraries under the `.../host_injections` directory.
# It allows EESSI software to use the MPI stack from the host.
#
# The `host_injections` directory is a variant symlink that by default points to
# `/opt/eessi`, unless otherwise defined in the local CVMFS configuration (see
# https://cvmfs.readthedocs.io/en/stable/cpt-repo.html#variant-symlinks). For the
# installation to be successful, this directory needs to be writeable by the user
# executing this script.

# Initialise our bash functions
TOPDIR=$(dirname $(realpath $BASH_SOURCE))
source "$TOPDIR"/../../utils.sh


# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --help                           Display this help message"
    echo "  --mpi-path /path/to/mpi          Specify the path to the MPI host installation"
    echo "  --pmix-path /path/to/mpi         Specify the path to the PMIX host installation"
    echo "  -t, --temp-dir /path/to/tmpdir   Specify a location to use for temporary"
    echo "                                   storage during the mpi injection"
    echo "                                   (must have >10GB available)"
}


# Global associative array with os-release info
declare -A OS_RELEASE

get_os_release() {
    local key
    local value

    while read -r key value; do
    OS_RELEASE[${key}]="${value}"
    done < <(awk -F = 'gsub(/"/, "", $2); {print $1, $2}' /etc/os-release)
}


parse_cmdline() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help)
                show_help
                exit 0
                ;;
            --mpi-path)
                if [ -n "$2" ]; then
                    MPI_PATH="$2"
                    shift 2
                else
                    echo "Error: Argument required for $1"
                    show_help
                    exit 1
                fi
                ;;
            --pmix-path)
                if [ -n "$2" ]; then
                    PMIX_PATH="$2"
                    shift 2
                else
                    echo "Error: Argument required for $1"
                    show_help
                    exit 1
                fi
                ;;
            -t|--temp-dir)
                if [ -n "$2" ]; then
                    TEMP_DIR="$2"
                    shift 2
                else
                    echo "Error: Argument required for $1"
                    show_help
                    exit 1
                fi
                ;;
            *)
                show_help
                fatal_error "Error: Unknown option: $1"
                ;;
        esac
    done
}


# ****Warning: patchelf v0.18.0 (currently shipped with EESSI) does not work.****
# We get v0.17.2
download_patchelf() {
    local patchelf_version="0.17.2"
    local url

    url="https://github.com/NixOS/patchelf/releases/download/${patchelf_version}/"
    url+="patchelf-${patchelf_version}-${EESSI_CPU_FAMILY}.tar.gz"

    curl ${url} ${CURL_OPTS} -o ${TEMP_DIR}/patchelf.tar.gz
    tar -xf ${TEMP_DIR}/patchelf.tar.gz -C ${TEMP_DIR}
    PATCHELF_BIN=${TEMP_DIR}/bin/patchelf
}


inject_mpi() {
    local efa_path="${AMAZON_PATH}/efa"
    local openmpi_path="${MPI_PATH}"
    local pmix_path="${PMIX_PATH}"

    local eessi_ldd="${EESSI_EPREFIX}/usr/bin/ldd"
    local system_ldd="/usr/bin/ldd"

    (( OPENMPI_VERSION == 5 )) && openmpi_path+=5

    local host_injection_mpi_path

    host_injection_mpi_path=${EESSI_SOFTWARE_PATH/versions/host_injections}
    host_injection_mpi_path+="/software/${EESSI_OS_TYPE}/${EESSI_SOFTWARE_SUBDIR}"
    host_injection_mpi_path+="/rpath_overrides/OpenMPI/system/lib"

    if [ -d ${host_injection_mpi_path} ]; then
        echo "MPI was already injected"
        return 0
    fi

    sudo mkdir -p ${host_injection_mpi_path}

    local temp_inject_path="${TEMP_DIR}/mpi_inject"
    mkdir ${temp_inject_path}

    # Get all library files from efa and openmpi dirs
    find ${efa_path} ${openmpi_path} ${pmix_path} -maxdepth 2 -type f -name "*.so*" -exec cp {} ${temp_inject_path} \;

    # Copy library links to host injection path
    sudo find ${efa_path} ${openmpi_path} ${pmix_path} -maxdepth 2 -type l -name "*.so*" -exec cp -P {} ${host_injection_mpi_path} \;

    # Get system libefa.so and libibverbs.so
    find /lib/ /lib64/ \( -name "libefa.so*" -or -name "libibverbs.so*" \) -type f -exec cp {} ${temp_inject_path} \;
    sudo find /lib/ /lib64/ \( -name "libefa.so*" -or -name "libibverbs.so*" \) -type l -exec cp -P {} ${host_injection_mpi_path} \;


    # Get MPI libs dependencies from system ldd
    local libname libpath
    local -A libs_arr

    while read -r libname libpath; do
        [[ ${libpath} =~ ${AMAZON_PATH}/.* ]] && libpath=${host_injection_mpi_path}/$(basename ${libpath})
        [[ ${libname} =~ libefa\.so\.?.* ]] && libpath=${host_injection_mpi_path}/$(basename ${libpath})
        [[ ${libname} =~ libibverbs\.so\.?.* ]] && libpath=${host_injection_mpi_path}/$(basename ${libpath})
        libs_arr[${libname}]=${libpath}
    done < <(cat <(${system_ldd} ${temp_inject_path}/*) <(find ${openmpi_path} -mindepth 3 -name "*.so*" -print0 | xargs -0 ${system_ldd}) | awk '/=>/{print $1, $3}' | sort | uniq)

    # Get MPI related lib dependencies not resolved by EESSI ldd
    local lib

    while read -r lib; do
        local dep

        ${PATCHELF_BIN} --set-rpath "" ${lib}

        while read -r dep; do
            if ${PATCHELF_BIN} --print-needed ${lib} | grep -q "${dep}"; then
                ${PATCHELF_BIN} --replace-needed ${dep} ${libs_arr[${dep}]} ${lib}
            fi
        done < <(${eessi_ldd} ${lib} | awk '/not found/ || /libefa/ || /libibverbs/ {print $1}' | sort | uniq)

        # Inject into libmpi.so non resolved dependencies from dlopen libraries that are not already present in libmpi.so
        if [[ ${lib} =~ libmpi\.so ]]; then
            while read -r dep; do
                ${PATCHELF_BIN} --add-needed ${libs_arr[${dep}]} ${lib}
            done < <(comm -23 <(find ${openmpi_path} -mindepth 3 -name "*.so*" -print0 | xargs -0 ${eessi_ldd} | awk '/not found/ {print $1}' | sort | uniq) <(${PATCHELF_BIN} --print-needed ${lib} | sort))
        fi

    done < <(find ${temp_inject_path} -type f)

    # Sanity check MPI injection
    if ${eessi_ldd} ${temp_inject_path}/* &> /dev/null; then
        sudo cp ${temp_inject_path}/* -t ${host_injection_mpi_path}
        echo_green "MPI injection was successful"
        return 0
    else
        fatal_error "MPI host injection failed. EESSI will use its own MPI libraries"
    fi
}


main() {
    process_cmdline "$@"
    get_os_release
    check_eessi_initialised

    # we need a directory we can use for temporary storage
    if [[ -z "${TEMP_DIR}" ]]; then
        tmpdir=$(mktemp -d)
    else
        tmpdir="${TEMP_DIR}"/temp
        if ! mkdir -p "$tmpdir" ; then
            fatal_error "Could not create directory ${tmpdir}"
        fi
    fi

    echo "OpenMPI version to inject: ${OPENMPI_VERSION}"
    download_patchelf
    inject_mpi

    rm -rf "${tmpdir}"
    echo "EESSI setup completed with success"
}

main "$@"
