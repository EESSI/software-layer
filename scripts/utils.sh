## THIS COMMENT IS ONLY TO RETRIGGER #517
## IT SHOULD NEVER BE MERGED

function echo_green() {
    echo -e "\e[32m$1\e[0m"
}

function echo_red() {
    echo -e "\e[31m$1\e[0m"
}

function echo_yellow() {
    echo -e "\e[33m$1\e[0m"
}

ANY_ERROR_EXITCODE=1
function fatal_error() {
    echo_red "ERROR: $1" >&2
    if [[ $# -gt 1 ]]; then
      exit "$2"
    else
      exit "${ANY_ERROR_EXITCODE}"
    fi
}

function check_exit_code {
    ec=$1
    ok_msg=$2
    fail_msg=$3

    if [[ $ec -eq 0 ]]; then
        echo_green "${ok_msg}"
    else
        fatal_error "${fail_msg}"
    fi
}

function check_eessi_initialised() {
  if [[ -z "${EESSI_SOFTWARE_PATH}" ]]; then
    fatal_error "EESSI has not been initialised!"
  else
    return 0
  fi
}

function check_in_prefix_shell() {
  # Make sure EPREFIX is defined
  if [[ -z "${EPREFIX}" ]]; then
    fatal_error "This script cannot be used without having first defined EPREFIX"
  fi
  if [[ ! ${SHELL} = ${EPREFIX}/bin/bash ]]; then
    fatal_error "Not running in Gentoo Prefix environment, run '${EPREFIX}/startprefix' first!"
  fi
}

function create_directory_structure() {
  # Ensure we are given a single path argument
  if [ $# -ne 1 ]; then
    echo_red "Function requires a single (relative or absolute) path argument" >&2
    return $ANY_ERROR_EXITCODE
  fi
  dir_structure="$1"

  # Attempt to create the directory structure
  error_message=$(mkdir -p "$dir_structure" 2>&1)
  return_code=$?
  # If it fails be explicit about the error
  if [ ${return_code} -ne 0 ]; then
    real_dir=$(realpath -m "$dir_structure")
    echo_red "Creating ${dir_structure} (real path ${real_dir}) failed with:\n ${error_message}" >&2
  else
    # If we're creating it, our use case is that we want to be able to write there
    # (this is a check in case the directory already existed)
    if [ ! -w "${dir_structure}" ]; then
      real_dir=$(realpath -m "$dir_structure")
      echo_red "You do not have (required) write permissions to ${dir_structure} (real path ${real_dir})!"
      return_code=$ANY_ERROR_EXITCODE
    fi
  fi

  return $return_code
}

function get_path_for_tool {
    tool_name=$1
    tool_envvar_name=$2

    which_out=$(which "${tool_name}" 2>&1)
    exit_code=$?
    if [[ ${exit_code} -eq 0 ]]; then
        echo "INFO: found tool ${tool_name} in PATH (${which_out})" >&2
        echo "${which_out}"
        return 0
    fi
    if [[ -z "${tool_envvar_name}" ]]; then
        msg="no env var holding the full path to tool '${tool_name}' provided"
        echo "${msg}" >&2
        return 1
    else
        tool_envvar_value=${!tool_envvar_name}
        if [[ -x "${tool_envvar_value}" ]]; then
            msg="INFO: found tool ${tool_envvar_value} via env var ${tool_envvar_name}"
            echo "${msg}" >&2
            echo "${tool_envvar_value}"
            return 0
        else
            msg="ERROR: tool '${tool_name}' not in PATH\n"
            msg+="ERROR: tool '${tool_envvar_value}' via '${tool_envvar_name}' not in PATH"
            echo "${msg}" >&2
            echo ""
            return 2
        fi
    fi
}

function get_host_from_url {
    url=$1
    re="(http|https)://([^/:]+)"
    if [[ $url =~ $re ]]; then
        echo "${BASH_REMATCH[2]}"
        return 0
    else
        echo ""
        return 1
    fi
}

function get_port_from_url {
    url=$1
    re="(http|https)://[^:]+:([0-9]+)"
    if [[ $url =~ $re ]]; then
        echo "${BASH_REMATCH[2]}"
        return 0
    else
        echo ""
        return 1
    fi
}

function get_ipv4_address {
    hname=$1
    hipv4=$(grep "${hname}" /etc/hosts | grep -v '^[[:space:]]*#' | cut -d ' ' -f 1)
    # TODO try other methods if the one above does not work --> tool that verifies
    #      what method can be used?
    echo "${hipv4}"
    return 0
}
