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
