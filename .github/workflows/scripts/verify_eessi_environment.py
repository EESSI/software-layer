import os

import os
import sys

class EnvVarError(Exception):
    """Custom exception for environment variable comparison errors."""
    def __init__(self, message):
        super().__init__(f"ENV VALIDATION ERROR: {message}")

def get_env_vars(var1, var2):
    val1 = os.environ.get(var1)
    val2 = os.environ.get(var2)

    if val1 is None:
        raise EnvVarError(f"Missing environment variable: '{var1}'")
    if val2 is None:
        raise EnvVarError(f"Missing environment variable: '{var2}'")

    return val1, val2

def check_env_equals(var1, var2):
    val1, val2 = get_env_vars(var1, var2)
    if val1 != val2:
        raise EnvVarError(f"'{var1}' must equal '{var2}':\n{var1}='{val1}'\n{var2}='{val2}'")

def check_env_contains(var1, var2):
    val1, val2 = get_env_vars(var1, var2)
    if val2 not in val1:
        raise EnvVarError(f"'{var1}' must contain '{var2}':\n{var1}='{val1}'\n{var2}='{val2}'")

def check_env_endswith(var1, var2):
    val1, val2 = get_env_vars(var1, var2)
    if not val1.endswith(val2):
        raise EnvVarError(f"'{var1}' must end with '{var2}':\n{var1}='{val1}'\n{var2}='{val2}'")

if __name__ == "__main__":
    try:
        # accelerator stuff is not guaranteed to exist
        expected_eessi_accel_arch = os.getenv("EESSI_ACCELERATOR_TARGET_OVERRIDE", default=None)

        # Verify the software and accelerator targets are set correctly
        if os.getenv("EESSI_SOFTWARE_SUBDIR_OVERRIDE", default=None):
            check_env_equals("EESSI_SOFTWARE_SUBDIR_OVERRIDE", "EESSI_SOFTWARE_SUBDIR")
        if expected_eessi_accel_arch:
            # EESSI_ACCEL_SUBDIR is what is detected by archdetect (or respects EESSI_ACCELERATOR_TARGET_OVERRIDE)
            check_env_equals("EESSI_ACCELERATOR_TARGET_OVERRIDE", "EESSI_ACCEL_SUBDIR")
            # special case is where EESSI_ACCELERATOR_TARGET_OVERRIDE may not match the final
            # accelerator architecture chosen (in CI we deliberately choose a non-existent CUDA
            # compute cabability for one case)
            os.environ["EESSI_FINAL_CC"] = expected_eessi_accel_arch[:-1] + "0"
            check_env_equals("EESSI_ACCELERATOR_TARGET", "EESSI_FINAL_CC")
        # verify the software paths that should exist
        check_env_endswith("EESSI_SOFTWARE_PATH", "EESSI_SOFTWARE_SUBDIR")
        check_env_endswith("EESSI_SITE_SOFTWARE_PATH", "EESSI_SOFTWARE_SUBDIR")
        # verify the module paths that should exist
        check_env_contains("EESSI_MODULEPATH", "EESSI_SOFTWARE_SUBDIR")
        check_env_contains("EESSI_SITE_MODULEPATH", "EESSI_SOFTWARE_SUBDIR")
        if expected_eessi_accel_arch:
            check_env_contains("EESSI_MODULEPATH_ACCEL", "EESSI_SOFTWARE_SUBDIR")
            check_env_contains("EESSI_SITE_MODULEPATH_ACCEL", "EESSI_SOFTWARE_SUBDIR")  
            check_env_contains("EESSI_MODULEPATH_ACCEL", "EESSI_ACCELERATOR_TARGET")
            check_env_contains("EESSI_SITE_MODULEPATH_ACCEL", "EESSI_ACCELERATOR_TARGET")
        # Finally, verify that all the expected module path are included
        check_env_contains("MODULEPATH", "EESSI_MODULEPATH")
        check_env_contains("MODULEPATH", "EESSI_SITE_MODULEPATH")
        if expected_eessi_accel_arch:
            check_env_contains("MODULEPATH", "EESSI_MODULEPATH_ACCEL")
            check_env_contains("MODULEPATH", "EESSI_SITE_MODULEPATH_ACCEL")

        # We are done
        print("Environment variable check passed.")
    except EnvVarError as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)
