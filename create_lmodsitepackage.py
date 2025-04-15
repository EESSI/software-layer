#!/usr/bin/env python3
#
# Create SitePackage.lua configuration file for Lmod.
#
import os
import sys
from stat import S_IREAD, S_IWRITE, S_IRGRP, S_IWGRP, S_IROTH

DOT_LMOD = '.lmod'

hook_prologue = """require("strict")
local hook = require("Hook")
local open = io.open

"""

hook_txt = """
local function read_file(path)
    local file = open(path, "rb") -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

local function from_eessi_prefix(t)
    -- eessi_prefix is the prefix with official EESSI modules
    -- e.g. /cvmfs/software.eessi.io/versions/2023.06
    local eessi_prefix = os.getenv("EESSI_PREFIX")

    -- If EESSI_PREFIX wasn't defined, we cannot check if this module was from the EESSI environment
    -- In that case, we assume it isn't, otherwise EESSI_PREFIX would (probably) have been set
    if eessi_prefix == nil then
        return false
    else
        -- NOTE: exact paths for site so may need to be updated later.
        -- See https://github.com/EESSI/software-layer/pull/371

        -- eessi_prefix_host_injections is the prefix with site-extensions (i.e. additional modules)
        -- to the official EESSI modules, e.g. /cvmfs/software.eessi.io/host_injections/2023.06
        local eessi_prefix_host_injections = string.gsub(eessi_prefix, 'versions', 'host_injections')

       -- Check if the full modulepath starts with the eessi_prefix_*
        return string.find(t.fn, "^" .. eessi_prefix) ~= nil or string.find(t.fn, "^" .. eessi_prefix_host_injections) ~= nil
    end
end

local function load_site_specific_hooks()
    -- This function will be run after the EESSI hooks are registered
    -- It will load a local SitePackage.lua that is architecture independent (if it exists) from e.g.
    -- /cvmfs/software.eessi.io/host_injections/2023.06/.lmod/SitePackage.lua
    -- That can define a new hook
    --
    -- function site_specific_load_hook(t)
    --     <some_action_on_load>
    -- end
    --
    -- And the either append to the existing hook:
    --
    -- local function final_load_hook(t)
    --    eessi_load_hook(t)
    --    site_specific_load_hook(t)
    -- end
    --
    -- Over overwrite the EESSI hook entirely:
    --
    -- hook.register("load", final_load_hook)
    --
    -- Note that the appending procedure can be simplified once we have an lmod >= 8.7.36
    -- See https://github.com/TACC/Lmod/pull/696#issuecomment-1998765722
    --
    -- Subsequently, this function will look for an architecture-specific SitePackage.lua, e.g. from
    -- /cvmfs/software.eessi.io/host_injections/2023.06/software/linux/x86_64/amd/zen2/.lmod/SitePackage.lua
    -- This can then register an additional hook, e.g.
    --
    -- function arch_specific_load_hook(t)
    --     <some_action_on_load>
    -- end
    --
    -- local function final_load_hook(t)
    --   eessi_load_hook(t)
    --   site_specific_load_hook(t)
    --   arch_specific_load_hook(t)
    -- end
    --
    -- hook.register("load", final_load_hook)
    --
    -- Again, the host site could also decide to overwrite by simply doing
    --
    -- hook.register("load", arch_specific_load_hook)

    -- get path to to architecture independent SitePackage.lua
    local prefixHostInjections = string.gsub(os.getenv('EESSI_PREFIX') or "", 'versions', 'host_injections')
    local hostSitePackage = prefixHostInjections .. "/.lmod/SitePackage.lua"

    -- If the file exists, run it
    if isFile(hostSitePackage) then
        dofile(hostSitePackage)
    end

    -- build the full architecture specific path in host_injections
    local archHostInjections = string.gsub(os.getenv('EESSI_SOFTWARE_PATH') or "", 'versions', 'host_injections')
    local archSitePackage = archHostInjections .. "/.lmod/SitePackage.lua"

    -- If the file exists, run it
    if isFile(archSitePackage) then
        dofile(archSitePackage)
    end

end


local function eessi_cuda_and_libraries_enabled_load_hook(t)
    local frameStk  = require("FrameStk"):singleton()
    local mt        = frameStk:mt()
    local simpleName = string.match(t.modFullName, "(.-)/")
    local packagesList = { ["CUDA"] = true, ["cuDNN"] = true }
    -- If we try to load any of the modules in packagesList, we check if the
    -- full package was installed on the host in host_injections.
    -- This is required for end users to build additional software that depends
    -- on the package. If the full SDK isn't present, refuse
    -- to load the module and print an informative message on how to set up GPU support for EESSI
    local refer_to_docs = "For more information on how to do this, see https://www.eessi.io/docs/site_specific_config/gpu/.\\n"
    if packagesList[simpleName] then
        -- simpleName is a module in packagesList
        -- get the full host_injections path
        local hostInjections = string.gsub(os.getenv('EESSI_SOFTWARE_PATH') or "", 'versions', 'host_injections')

        -- build final path where the software should be installed
        local packageEasyBuildDir = hostInjections .. "/software/" .. t.modFullName .. "/easybuild"
        local packageDirExists = isDir(packageEasyBuildDir)
        if not packageDirExists then
            local advice = "but while the module file exists, the actual software is not entirely shipped with EESSI "
            advice = advice .. "due to licencing. You will need to install a full copy of the " .. simpleName .. " package where EESSI "
            advice = advice .. "can find it.\\n"
            advice = advice .. refer_to_docs
            LmodError("\\nYou requested to load ", simpleName, " ", advice)
        end
    end
    -- when loading CUDA (and cu*) enabled modules check if the necessary driver libraries are accessible to the EESSI linker,
    -- otherwise, refuse to load the requested module and print error message
    local checkGpu = mt:haveProperty(simpleName,"arch","gpu")
    local overrideGpuCheck = os.getenv("EESSI_OVERRIDE_GPU_CHECK")
    if checkGpu and (overrideGpuCheck == nil) then
        local arch = os.getenv("EESSI_CPU_FAMILY") or ""
        local cvmfs_repo = os.getenv("EESSI_CVMFS_REPO") or ""
        local cudaVersionFile = cvmfs_repo .. "/host_injections/nvidia/" .. arch .. "/latest/cuda_version.txt"
        local cudaDriverFile = cvmfs_repo .. "/host_injections/nvidia/" .. arch .. "/latest/libcuda.so"
        local cudaDriverExists = isFile(cudaDriverFile)
        local singularityCudaExists = isFile("/.singularity.d/libs/libcuda.so")
        if not (cudaDriverExists or singularityCudaExists)  then
            local advice = "which relies on the CUDA runtime environment and driver libraries. "
            advice = advice .. "In order to be able to use the module, you will need "
            advice = advice .. "to make sure EESSI can find the GPU driver libraries on your host system. You can "
            advice = advice .. "override this check by setting the environment variable EESSI_OVERRIDE_GPU_CHECK but "
            advice = advice .. "the loaded application will not be able to execute on your system.\\n"
            advice = advice .. refer_to_docs
            LmodError("\\nYou requested to load ", simpleName, " ", advice)
        else
            -- CUDA driver exists, now we check its version to see if an update is needed
            if cudaDriverExists then
                local cudaVersion = read_file(cudaVersionFile)
                local cudaVersion_req = os.getenv("EESSICUDAVERSION")
                -- driver CUDA versions don't give a patch version for CUDA
                local major, minor = string.match(cudaVersion, "(%d+)%.(%d+)")
                local major_req, minor_req, patch_req = string.match(cudaVersion_req, "(%d+)%.(%d+)%.(%d+)")
                local driver_libs_need_update = false
                if major < major_req then
                    driver_libs_need_update = true
                elseif major == major_req then
                    if minor < minor_req then
                        driver_libs_need_update = true
                    end
                end
                if driver_libs_need_update == true then
                    local advice = "but the module you want to load requires CUDA  " .. cudaVersion_req .. ". "
                    advice = advice .. "Please update your CUDA driver libraries and then "
                    advice = advice .. "let EESSI know about the update.\\n"
                    advice = advice .. refer_to_docs
                    LmodError("\\nYour driver CUDA version is ", cudaVersion, " ", advice)
                end
            end
        end
    end
end

local function eessi_espresso_deprecated_message(t)
    local frameStk  = require("FrameStk"):singleton()
    local mt        = frameStk:mt()
    local simpleName = string.match(t.modFullName, "(.-)/")
    local version = string.match(t.modFullName, "%d.%d.%d")
    if simpleName == 'ESPResSo' and version == '4.2.1' then
    -- Print a message on loading ESPreSso v <= 4.2.1 recommending using v 4.2.2 and above.
    -- A message and not a warning as the exit code would break CI runs otherwise.
        local advice = 'Prefer versions  >= 4.2.2 which include important bugfixes.\\n'
        advice = advice .. 'For details see https://github.com/espressomd/espresso/releases/tag/4.2.2\\n'
        advice = advice .. 'Use version 4.2.1 at your own risk!\\n'
        LmodMessage("\\nESPResSo v4.2.1 has known issues and has been deprecated. ", advice)
    end
end

local function eessi_scipy_2022b_test_failures_message(t)
    local cpuArch = os.getenv("EESSI_SOFTWARE_SUBDIR")
    local graceArch = 'aarch64/nvidia/grace'
    local fullModuleName = 'SciPy-bundle/2023.02-gfbf-2022b'
    local moduleVersionArchMatch = t.modFullName == fullModuleName and cpuArch == graceArch
    if moduleVersionArchMatch and not os.getenv("EESSI_IGNORE_MODULE_WARNINGS") then
    -- Print a message on loading SciPy-bundle version == 2023.02 informing about the higher number of
    -- test failures and recommend using other versions available via EESSI.
    -- A message and not a warning as the exit code would break CI runs otherwise.
        local simpleName = string.match(t.modFullName, "(.-)/")
        local advice = 'The module ' .. t.modFullName .. ' will be loaded. However, note that\\n'
        advice = advice .. 'during its building for the CPU microarchitecture ' .. graceArch .. ' from a\\n'
        advice = advice .. 'total of 52.730 unit tests a larger number (46) than usually (2-4) failed. If\\n'
        advice = advice .. 'you encounter issues while using ' .. t.modFullName .. ', please,\\n'
        advice = advice .. 'consider using one of the other versions of ' .. simpleName .. ' that are also provided\\n'
        advice = advice .. 'for the same CPU microarchitecture.\\n'
        LmodMessage("\\n", advice)
    end
end

-- Combine both functions into a single one, as we can only register one function as load hook in lmod
-- Also: make it non-local, so it can be imported and extended by other lmodrc files if needed
function eessi_load_hook(t)
    eessi_espresso_deprecated_message(t)
    eessi_scipy_2022b_test_failures_message(t)
    -- Only apply CUDA and cu*-library hooks if the loaded module is in the EESSI prefix
    -- This avoids getting an Lmod Error when trying to load a CUDA or cu* module from a local software stack
    if from_eessi_prefix(t) then
        eessi_cuda_and_libraries_enabled_load_hook(t)
    end
end

local function using_eessi_accel_stack ()
    local modulepath = os.getenv("MODULEPATH") or ""
    local accel_stack_in_modulepath = false

    -- Check if we are using an EESSI version 2023 accelerator stack by checking if the $MODULEPATH contains
    -- a path that starts with /cvmfs/software.eessi.io and contains accel/nvidia/ccNN
    for path in string.gmatch(modulepath, '(.-):') do
        if string.sub(path, 1, 41) == "/cvmfs/software.eessi.io/versions/2023.06" then
            if string.find(path, "accel/nvidia/cc%d%d") then
                accel_stack_in_modulepath = true
                break
            end
        end
    end
    return accel_stack_in_modulepath
end

local function eessi_removed_module_warning_startup_hook(usrCmd)
    if usrCmd == 'load' and not os.getenv("EESSI_SKIP_REMOVED_MODULES_CHECK") then
        local CUDA_RELOCATION_MSG = [[All CUDA installations and modules depending on CUDA have been relocated to GPU-specific stacks.
        Please see https://www.eessi.io/docs/site_specific_config/gpu/ for more information.]]

        local RELOCATED_CUDA_MODULES = {
            ['NCCL'] = CUDA_RELOCATION_MSG,
            ['NCCL/2.18.3-GCCcore-12.3.0-CUDA-12.1.1'] = CUDA_RELOCATION_MSG,
            ['UCX-CUDA'] = CUDA_RELOCATION_MSG,
            ['UCX-CUDA/1.14.1-GCCcore-12.3.0-CUDA-12.1.1'] = CUDA_RELOCATION_MSG,
            -- we also have non-CUDA versions of OSU Micro Benchmarks, so only match the CUDA version
            ['OSU-Micro-Benchmarks/7.2-gompi-2023a-CUDA-12.1.1'] = CUDA_RELOCATION_MSG,
            ['UCC-CUDA'] = CUDA_RELOCATION_MSG,
            ['UCC-CUDA/1.2.0-GCCcore-12.3.0-CUDA-12.1.1'] = CUDA_RELOCATION_MSG,
            ['CUDA'] = CUDA_RELOCATION_MSG,
            ['CUDA/12.1.1'] = CUDA_RELOCATION_MSG,
            ['CUDA-Samples'] = CUDA_RELOCATION_MSG,
            ['CUDA-Samples/12.1-GCC-12.3.0-CUDA-12.1.1'] = CUDA_RELOCATION_MSG,
        }

        local REMOVED_MODULES = {
            ['ipympl/0.9.3-foss-2023a'] = 'This module has been replaced by ipympl/0.9.3-gfbf-2023a',
        }

        local masterTbl = masterTbl()
        local error_msg = ""
        -- The CUDA messages should only be shown if the accelerator stack is NOT being used
        if not using_eessi_accel_stack() then
            for _, module in pairs(masterTbl.pargs) do
                if RELOCATED_CUDA_MODULES[module] ~= nil then
                    error_msg = error_msg .. module .. ': ' .. RELOCATED_CUDA_MODULES[module] .. '\\n\\n'
                end
            end
        end
        for _, module in pairs(masterTbl.pargs) do
            if REMOVED_MODULES[module] ~= nil then
                error_msg = error_msg .. module .. ': ' .. REMOVED_MODULES[module] .. '\\n\\n'
            end
        end
        if error_msg ~= "" then
            LmodError('\\n' .. error_msg .. 'If you know what you are doing and you want to ignore this check for removed/relocated modules, set $EESSI_SKIP_REMOVED_MODULES_CHECK to any value.')
        end
    end
end

function eessi_startup_hook(usrCmd)
    eessi_removed_module_warning_startup_hook(usrCmd)
end

hook.register("startup", eessi_startup_hook)
hook.register("load", eessi_load_hook)

"""

hook_epilogue = """
-- Note that this needs to happen at the end, so that any EESSI specific hooks can be overwritten by the site
load_site_specific_hooks()
"""


# This hook is only for zen4.
hook_txt_zen4 = """
local function hide_2022b_modules(modT)
    -- modT is a table with: fullName, sn, fn and isVisible
    -- The latter is a boolean to determine if a module is visible or not

    local tcver = modT.fullName:match("gfbf%-(20[0-9][0-9][ab])") or
                  modT.fullName:match("gompi%-(20[0-9][0-9][ab])") or
                  modT.fullName:match("foss%-(20[0-9][0-9][ab])") or
                  modT.fullName:match("GCC%-([0-9]*.[0-9]*.[0-9]*)") or
                  modT.fullName:match("GCCcore%-([0-9]*.[0-9]*.[0-9]*)")

    -- if nothing matches, return              
    if tcver == nil then return end

    -- if we have matches, check if the toolchain version is either 2022b or 12.2.0
    if parseVersion(tcver) == parseVersion("2022b") or parseVersion(tcver) == parseVersion("12.2.0") then
        modT.isVisible = false
    end
end

hook.register("isVisibleHook", hide_2022b_modules)
"""

# Append conditionally for zen4
eessi_software_subdir_override = os.getenv("EESSI_SOFTWARE_SUBDIR_OVERRIDE")
if eessi_software_subdir_override == "x86_64/amd/zen4":
    hook_txt = hook_txt + hook_txt_zen4

# Concatenate hook prologue, body and epilogue
# Note that this has to happen after any conditional items have been added to the hook_txt
hook_txt = hook_prologue + hook_txt + hook_epilogue

def error(msg):
    sys.stderr.write("ERROR: %s\n" % msg)
    sys.exit(1)


if len(sys.argv) != 2:
    error("Usage: %s <software prefix>" % sys.argv[0])

prefix = sys.argv[1]

if not os.path.exists(prefix):
    error("Prefix directory %s does not exist!" % prefix)

sitepackage_path = os.path.join(prefix, DOT_LMOD, 'SitePackage.lua')

# Lmod itself doesn't care about compute capability so remove this duplication from
# the install path (if it exists)
accel_subdir = os.getenv("EESSI_ACCELERATOR_TARGET")
if accel_subdir:
    sitepackage_path = sitepackage_path.replace("/accel/%s" % accel_subdir, '')
try:
    os.makedirs(os.path.dirname(sitepackage_path), exist_ok=True)
    with open(sitepackage_path, 'w') as fp:
        fp.write(hook_txt)
    # Make sure that the created Lmod file has "read/write" for the user/group and "read" permissions for others
    os.chmod(sitepackage_path, S_IREAD | S_IWRITE | S_IRGRP | S_IWGRP | S_IROTH)

except (IOError, OSError) as err:
    error("Failed to create %s: %s" % (sitepackage_path, err))

print(sitepackage_path)
