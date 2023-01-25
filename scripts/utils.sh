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
      exit $2
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

function get_path_for_tool {
    tool_name=$1
    tool_envvar_name=$2

    which_out=$(which ${tool_name} 2>&1)
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

function get_ipv4_address {
    hname=$1
    hipv4=$(grep ${hname} /etc/hosts | grep -v '^[[:space:]]*#' | cut -d ' ' -f 1)
    # TODO try other methods if the one above does not work --> tool that verifies
    #      what method can be used?
    echo "${hipv4}"
    return 0
}
