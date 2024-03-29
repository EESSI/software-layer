#!/usr/bin/env python3
#
# Create SitePackage.lua configuration file for Lmod.
#
import os
import sys

DOT_LMOD = '.lmod'

hook_txt ="""require("strict")
local hook = require("Hook")
local open = io.open

local function read_file(path)
    local file = open(path, "rb") -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

local function load_sitespecific_hooks()
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
    local prefixHostInjections = string.gsub(os.getenv('EESSI_PREFIX'), 'versions', 'host_injections')
    local hostSitePackage = prefixHostInjections .. "/.lmod/SitePackage.lua"

    -- If the file exists, run it
    if isDir(hostSitePackage) then
        dofile(hostSitePackage)
    end

    -- build the full architecture specific path in host_injections
    local archHostInjections = string.gsub(os.getenv('EESSI_SOFTWARE_PATH') or "", 'versions', 'host_injections')
    local archSitePackage = archHostInjections .. "/.lmod/SitePackage.lua"

    -- If the file exists, run it
    if isDir(archSitePackage) then
        dofile(archSitePackage)
    end
    
end


local function eessi_cuda_enabled_load_hook(t)
    local frameStk  = require("FrameStk"):singleton()
    local mt        = frameStk:mt()
    local simpleName = string.match(t.modFullName, "(.-)/")
    -- If we try to load CUDA itself, check if the full CUDA SDK was installed on the host in host_injections. 
    -- This is required for end users to build additional CUDA software. If the full SDK isn't present, refuse
    -- to load the CUDA module and print an informative message on how to set up GPU support for EESSI
    local refer_to_docs = "For more information on how to do this, see https://www.eessi.io/docs/gpu/.\\n"
    if simpleName == 'CUDA' then
        -- get the full host_injections path
        local hostInjections = string.gsub(os.getenv('EESSI_SOFTWARE_PATH') or "", 'versions', 'host_injections')
        -- build final path where the CUDA software should be installed
        local cudaEasyBuildDir = hostInjections .. "/software/" .. t.modFullName .. "/easybuild"
        local cudaDirExists = isDir(cudaEasyBuildDir)
        if not cudaDirExists then
            local advice = "but while the module file exists, the actual software is not entirely shipped with EESSI "
            advice = advice .. "due to licencing. You will need to install a full copy of the CUDA SDK where EESSI "
            advice = advice .. "can find it.\\n"
            advice = advice .. refer_to_docs
            LmodError("\\nYou requested to load ", simpleName, " ", advice)
        end
    end
    -- when loading CUDA enabled modules check if the necessary driver libraries are accessible to the EESSI linker,
    -- otherwise, refuse to load the requested module and print error message
    local haveGpu = mt:haveProperty(simpleName,"arch","gpu")
    if haveGpu then
        local arch = os.getenv("EESSI_CPU_FAMILY") or ""
        local cudaVersionFile = "/cvmfs/software.eessi.io/host_injections/nvidia/" .. arch .. "/latest/cuda_version.txt"
        local cudaDriverFile = "/cvmfs/software.eessi.io/host_injections/nvidia/" .. arch .. "/latest/libcuda.so"
        local cudaDriverExists = isFile(cudaDriverFile)
        local singularityCudaExists = isFile("/.singularity.d/libs/libcuda.so")
        if not (cudaDriverExists or singularityCudaExists)  then
            local advice = "which relies on the CUDA runtime environment and driver libraries. "
            advice = advice .. "In order to be able to use the module, you will need "
            advice = advice .. "to make sure EESSI can find the GPU driver libraries on your host system.\\n"
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

-- Combine both functions into a single one, as we can only register one function as load hook in lmod
-- Also: make it non-local, so it can be imported and extended by other lmodrc files if needed
function eessi_load_hook(t)
    eessi_cuda_enabled_load_hook(t)
end


hook.register("load", eessi_load_hook)

-- Note that this needs to happen at the end, so that any EESSI specific hooks can be overwritten by the site
load_site_specific_hooks()
"""

def error(msg):
    sys.stderr.write("ERROR: %s\n" % msg)
    sys.exit(1)


if len(sys.argv) != 2:
    error("Usage: %s <software prefix>" % sys.argv[0])

prefix = sys.argv[1]

if not os.path.exists(prefix):
    error("Prefix directory %s does not exist!" % prefix)

sitepackage_path = os.path.join(prefix, DOT_LMOD, 'SitePackage.lua')
try:
    os.makedirs(os.path.dirname(sitepackage_path), exist_ok=True)
    with open(sitepackage_path, 'w') as fp:
        fp.write(hook_txt)

except (IOError, OSError) as err:
    error("Failed to create %s: %s" % (sitepackage_path, err))

print(sitepackage_path)
