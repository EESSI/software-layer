#!/usr/bin/env python3
#
# Create lmodrc.lua configuration file for Lmod.
#
import os
import sys

DOT_LMOD = '.lmod'

TEMPLATE_LMOD_RC = """propT = {
}
scDescriptT = {
    {
        ["dir"] = "%(prefix)s/%(dot_lmod)s/cache",
        ["timestamp"] = "%(prefix)s/%(dot_lmod)s/cache/timestamp",
    },
}
"""

GPU_LMOD_RC ="""require("strict")
local hook = require("Hook")
local open = io.open

local function read_file(path)
    local file = open(path, "rb") -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

local function cuda_enabled_load_hook(t)
    local frameStk  = require("FrameStk"):singleton()
    local mt        = frameStk:mt()
    local simpleName = string.match(t.modFullName, "(.-)/")
    -- If we try to load CUDA itself, check if the full CUDA SDK was installed on the host in host_injections. 
    -- This is required for end users to build additional CUDA software. If the full SDK isn't present, refuse
    -- to load the CUDA module and print an informative message on how to set up GPU support for EESSI
    if simpleName == 'CUDA' then
        -- get the full host_injections path
        local hostInjections = string.gsub(os.getenv('EESSI_SOFTWARE_PATH') or "", 'versions', 'host_injections')
        -- build final path where the CUDA software should be installed
        local cudaEasyBuildDir = hostInjections .. "/software/" .. t.modFullName .. "/easybuild"
        local cudaDirExists = isDir(cudaEasyBuildDir)
        if not cudaDirExists then
            local advice = "While the module file exists, the actual software is not shipped with EESSI. "
            advice = advice .. "In order to be able to use the CUDA module, please follow the instructions "
            advice = advice .. "available under https://www.eessi.io/docs/gpu/ \\n"
            LmodError("\\nYou requested to load ", simpleName, " ", advice)
        end
    end
    -- when loading CUDA enabled modules check if the necessary driver libraries are accessible to the EESSI linker,
    -- otherwise, refuse to load the requested module and print error message
    local haveGpu = mt:haveProperty(simpleName,"arch","gpu")
    if haveGpu then
        local arch = os.getenv("EESSI_CPU_FAMILY") or ""
        local cudaVersionFile = "/cvmfs/pilot.eessi-hpc.org/host_injections/nvidia/" .. arch .. "/latest/cuda_version.txt"
        local cudaDriverFile = "/cvmfs/pilot.eessi-hpc.org/host_injections/nvidia/" .. arch .. "/latest/libcuda.so"
        local cudaDriverExists = isFile(cudaDriverFile)
        local singularityCudaExists = isFile("/.singularity.d/libs/libcuda.so")
        if not (cudaDriverExists or singularityCudaExists)  then
            local advice = "which relies on the CUDA runtime environment and driver libraries. "
            advice = advice .. "In order to be able to use the module, please follow the instructions "
            advice = advice .. "available under https://www.eessi.io/docs/gpu/ \\n"
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
                    advice = advice .. "Please update your CUDA driver libraries and then follow the instructions "
                    advice = advice .. "under https://www.eessi.io/docs/gpu/ to let EESSI know about the update.\\n"
                    LmodError("\\nYour driver CUDA version is ", cudaVersion, " ", advice)
                end
            end
        end
    end
end

hook.register("load", cuda_enabled_load_hook)
"""

def error(msg):
    sys.stderr.write("ERROR: %s\n" % msg)
    sys.exit(1)


if len(sys.argv) != 2:
    error("Usage: %s <software prefix>" % sys.argv[0])

prefix = sys.argv[1]

if not os.path.exists(prefix):
    error("Prefix directory %s does not exist!" % prefix)

lmodrc_path = os.path.join(prefix, DOT_LMOD, 'lmodrc.lua')
lmodrc_txt = TEMPLATE_LMOD_RC % {
    'dot_lmod': DOT_LMOD,
    'prefix': prefix,
}
lmodrc_txt += '\n' + GPU_LMOD_RC
try:
    os.makedirs(os.path.dirname(lmodrc_path), exist_ok=True)
    with open(lmodrc_path, 'w') as fp:
        fp.write(lmodrc_txt)

except (IOError, OSError) as err:
    error("Failed to create %s: %s" % (lmodrc_path, err))

print(lmodrc_path)
