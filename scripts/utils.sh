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

# Reimplement 'mkdir -p' with reporting on where permissions break down
function create_directory_structure() {
  # Ensure we are given a single path argument
  if [ $# -ne 1 ]; then
    echo "Function requires a single (relative or absolute) path argument" >&2
    return 1
  fi

  # set a persistent variable that knows the full structure
  # (i.e., retains the value upon recursive calls)
  full_structure="${full_structure:="$1"}"

  local directory_structure="$1"

  # Check if directory exists and is writeable
  if [ -d "${directory_structure}" ]; then
    if [ "${directory_structure}" = "${full_structure}" ]; then
        # release our (unneeded) global variable
        unset full_structure
    fi
    if [ -w "${directory_structure}" ]; then
      # Nothing to be done
      return 0
    else
      echo "Directory ${directory_structure} exists but is not writeable" >&2
      return 1
    fi
  fi

  local directory_structure_parent=$(dirname "${directory_structure}")

  # If the parent doesn't exist we need to create it
  if [ ! -d "${directory_structure_parent}" ]; then
    # Create the parent via a recursive call to this function
    # (if this doesn't succeed we need to return the error code)
    if ! create_directory_structure "${directory_structure_parent}"; then
      if [ "${directory_structure}" = "${full_structure}" ]; then
        # release our (unneeded) global variable
        unset full_structure
      fi
      return 1
    fi
  fi

  # Check the parent is writeable, and create the new subdir
  if [ -w "${directory_structure_parent}" ]; then
    if [ "${directory_structure}" = "${full_structure}" ]; then
      # release our (unneeded) global variable
      unset full_structure
    fi
    if ! mkdir "${directory_structure}"; then
      echo "'mkdir ${directory_structure}' failed for an unknown reason!" >&2
      return 1
    else
      # Success!
      return 0
    fi
  else
    echo "Attempt to create ${full_structure} failed," \
      "${directory_structure_parent} exists but you don't have write permissions." >&2
    if [ "${directory_structure}" = "${full_structure}" ]; then
      # release our global variable
      unset full_structure
    fi
    return 1
  fi
}
