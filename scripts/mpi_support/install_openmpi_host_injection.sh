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
source "$TOPDIR"/../utils.sh


# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --help                           Display this help message"
    echo "  --mpi-path /path/to/mpi          Specify the path to the MPI host installation (Required)"
    echo "  -t, --temp-dir /path/to/tmpdir   Specify a location to use for temporary"
    echo "                                   storage during the mpi injection"
    echo "  --noclean                        Do not remove the temporary directory after finishing injection"
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
                    readonly MPI_PATH="$2"
                    shift 2
                else
                    echo_red "Error: Argument required for $1"
                    show_help
                    exit 1
                fi
                ;;
            --pmix-path)
                if [ -n "$2"]; then
                    readonly PMIX_PATH="$2"
                    shift 2
                else
                    echo_red "Error: Argument required for $1"
                    show_help
                    exit 1
                fi
                ;;
            -t|--temp-dir)
                if [ -n "$2" ]; then
                    readonly TEMP_DIR="$2"
                    shift 2
                else
                    echo_red "Error: Argument required for $1"
                    show_help
                    exit 1
                fi
                ;;
            --noclean)
                CLEAN=false
                shift 1
                ;;
            *)
                echo_red "Error: Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    if [ -z "${MPI_PATH}" ]; then
        echo_yellow "MPI path was not specified and it is required"
        show_help
        exit 0
    fi

    if [ -z "${PMIX_PATH}" ]; then
        echo_yellow "PMIX path was not specified"
        echo_yellow "Assuming it is the directory where libpmix is found"
    fi

    readonly CLEAN=${CLEAN:=true}
}


# ****Warning: patchelf v0.18.0 (currently shipped with EESSI) does not work.****
# We get v0.17.2
download_patchelf() {
    # Temporary directory to save patchelf
    local tmpdir=$1

    local patchelf_version="0.17.2"
    local url
    local curl_opts="-L --silent --show-error --fail"

    url="https://github.com/NixOS/patchelf/releases/download/${patchelf_version}/"
    url+="patchelf-${patchelf_version}-${EESSI_CPU_FAMILY}.tar.gz"

    local patchelf_path=${tmpdir}/patchelf
    mkdir ${patchelf_path}

    curl ${url} ${curl_opts} -o ${patchelf_path}/patchelf.tar.gz
    tar -xf ${patchelf_path}/patchelf.tar.gz -C ${patchelf_path}
    PATCHELF_BIN=${patchelf_path}/bin/patchelf
}


inject_mpi() {
    # Temporary directory for injection
    local tmpdir=$1

    local eessi_ldd="${EESSI_EPREFIX}/usr/bin/ldd"
    local system_ldd="/usr/bin/ldd"

    local host_injection_mpi_path

    host_injection_mpi_path=${EESSI_SOFTWARE_PATH/versions/host_injections}
    host_injection_mpi_path+="/rpath_overrides/OpenMPI/system/lib"

    if [ -d ${host_injection_mpi_path} ]; then
        if [ -n "$(ls -A ${host_injection_mpi_path})" ]; then
            echo "MPI was already injected"
            return 0
        fi
    fi

    mkdir -p ${host_injection_mpi_path}

    local temp_inject_path="${tmpdir}/mpi_inject"
    mkdir ${temp_inject_path}

    # Get all library files from openmpi dir
    find ${MPI_PATH} -maxdepth 1 -type f -name "*.so*" -exec cp {} ${temp_inject_path} \;

    # Copy library links to host injection path
    find ${MPI_PATH} -maxdepth 1 -type l -name "*.so*" -exec cp -P {} ${host_injection_mpi_path} \;

    # Get MPI libs dependencies from system ldd
    local libname libpath pmixpath
    local -A libs_dict
    local -a dlopen_libs

    readarray -d '' dlopen_libs < <(find ${MPI_PATH} -mindepth 2 -name "*.so*")

    # Get all library names and paths in associative array
    # If library is libfabric, libpmix, or from the MPI path
    # modify libpath in assoc array to point to host_injection_mpi_path
    while read -r libname libpath; do
        if [[ ${libname} =~ libfabric\.so ]] && [[ ! -f ${temp_inject_path}/${libname} ]]; then
            local libdir="$(dirname ${libpath})/"     # without trailing slash the find does not work
            find ${libdir} -maxdepth 1 -type f -name "libfabric.so*" -exec cp {} ${temp_inject_path} \;
            find ${libdir} -maxdepth 1 -type l -name "libfabric.so*" -exec cp -P {} ${host_injection_mpi_path} \;

            local depname deppath
            while read -r depname deppath; do
                libs_dict[${depname}]=${deppath}
            done < <(${system_ldd} ${libpath} | awk '/=>/ {print $1, $3}' | sort | uniq)

            libpath=${host_injection_mpi_path}/$(basename ${libpath})
        fi

        if [[ ${libname} =~ libpmix\.so ]] && [[ ! -f ${temp_inject_path}/${libname} ]]; then
            local libdir="$(dirname ${libpath})/"     # without trailing slash the find does not work
            [ -n "${PMIX_PATH}" ] && pmixpath="${PMIX_PATH}/pmix" || pmixpath="$(dirname ${libpath})/pmix"
            find ${libdir} -maxdepth 1 -type f -name "libpmix.so*" -exec cp {} ${temp_inject_path} \;
            find ${libdir} -maxdepth 1 -type l -name "libpmix.so*" -exec cp -P {} ${host_injection_mpi_path} \;

            local depname deppath
            while read -r depname deppath; do
                libs_dict[${depname}]=${deppath}
            done < <(find ${pmixpath} -maxdepth 1 -name "*.so*" -exec ${system_ldd} {} \; | awk '/=>/ {print $1, $3}' | sort | uniq)

            libpath=${host_injection_mpi_path}/$(basename ${libpath})
        fi

        if [[ ${libpath} =~ ${MPI_PATH} ]]; then
            libpath=${host_injection_mpi_path}/$(basename ${libpath})
        fi
        
        libs_dict[${libname}]=${libpath}

    done < <(cat <(find ${temp_inject_path} -maxdepth 1 -type f -name "*.so*" -exec ${system_ldd} {} \;) \
                 <(for dlopen in ${dlopen_libs[@]}; do ${system_ldd} ${dlopen}; done) \
            | awk '/=>/ {print $1, $3}' | sort | uniq)

    # Do library injection to openmpi libs, libfabric and libpmix
    local lib
    while read -r lib; do
        local dep

        # Force system libefa, librdmacm, libibverbs and libpsm2 (present in the EESSI compat layer)
        # Must be done before the injection of unresolved dependencies
        if [[ ${lib} =~ libfabric\.so ]]; then
            while read -r dep; do
                ${PATCHELF_BIN} --replace-needed ${dep} ${libs_dict[${dep}]} ${lib}
            done < <(${system_ldd} ${lib} | awk '/libefa/ || /libibverbs/ || /libpsm2/ || /librdmacm/ {print $1}' | sort | uniq)
        fi

        # Do injection of unresolved libraries
        ${PATCHELF_BIN} --set-rpath "${host_injection_mpi_path}" ${lib}
        while read -r dep; do
            ${PATCHELF_BIN} --replace-needed ${dep} ${libs_dict[${dep}]} ${lib}
        done < <(${eessi_ldd} ${lib} | awk '/not found/ {print $1}' | sort | uniq)

        # Inject into libmpi.so non resolved dependencies from dlopen libraries that are not already present in libmpi.so
        if [[ ${lib} =~ libmpi\.so ]]; then
            while read -r dep; do
                if ! ${PATCHELF_BIN} --print-needed ${lib} | grep -q "${dep}"; then
                    ${PATCHELF_BIN} --add-needed ${libs_dict[${dep}]} ${lib}
                fi
            done < <(for dlopen in ${dlopen_libs[@]}; do ${eessi_ldd} ${dlopen}; done \
                     | grep -e "=> not found" -e "=> ${MPI_PATH}" | awk '!/libmpi\.so.*/ {print $1}' | sort | uniq)
        fi

        # Inject into libpmix.so non resolved dependencies from dlopen libraries in the PMIX path
        if [[ ${lib} =~ libpmix\.so ]]; then            
            while read -r dep; do
                if ! ${PATCHELF_BIN} --print-needed ${lib} | grep -q "${dep}"; then
                    ${PATCHELF_BIN} --add-needed ${libs_dict[${dep}]} ${lib}
                fi
            done < <(find ${pmixpath} -maxdepth 1 -type f -name "*.so*" -exec ${eessi_ldd} {} \; | awk '/not found/ && !/libpmix\.so.*/ {print $1}' | sort | uniq)
        fi

    done < <(find ${temp_inject_path} -type f)

    # Sanity check MPI injection
    if ${eessi_ldd} ${temp_inject_path}/* &> /dev/null; then
        cp ${temp_inject_path}/* -t ${host_injection_mpi_path}
        echo_green "MPI injection was successful"
        return 0
    else
        fatal_error "MPI host injection failed. EESSI will use its own MPI libraries"
    fi
}


main() {
    parse_cmdline "$@"
    check_eessi_initialised

    # Create directory linked by host_injections
    local inject_dir=$(readlink -f /cvmfs/software.eessi.io/host_injections)
    [[ ! -d ${inject_dir} ]] && mkdir -p ${inject_dir}

    # we need a directory we can use for temporary storage
    if [[ -z "${TEMP_DIR}" ]]; then
        tmpdir=$(mktemp -d)
    else
        tmpdir="${TEMP_DIR}"/temp
        if ! mkdir -p "$tmpdir" ; then
            fatal_error "Could not create directory ${tmpdir}"
        fi
    fi

    echo "Temporary directory for injection: ${tmpdir}"

    download_patchelf ${tmpdir}
    inject_mpi ${tmpdir}

    if ${CLEAN}; then
        rm -rf "${tmpdir}"
    fi
}

main "$@"
