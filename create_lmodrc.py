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

-- from https://stackoverflow.com/a/40195356
--- Check if a file or directory exists in this path
function exists(file)
    local ok, err, code = os.rename(file, file)
    if not ok then
        if code == 13 then
            -- Permission denied, but it exists
            return true
        end
    end
    return ok, err
end

local function visible_hook(modT)
    local frameStk  = require("FrameStk"):singleton()
    local mt        = frameStk:mt()
    local cudaDir = string.gsub(os.getenv('EESSI_SOFTWARE_PATH') or "", 'versions', 'host_injections')
    local cudaDirExists = exists(cudaDir)
    if not cudaDirExists then
        local haveGpu = mt:haveProperty(modT.sn,"arch","gpu")
        if haveGpu then
            modT.isVisible = false
        end
    end
end

local function cuda_enabled_load_hook(t)
    local frameStk  = require("FrameStk"):singleton()
    local mt        = frameStk:mt()
    local simpleName = string.match(t.modFullName, "(.-)/")
    local eprefix = os.getenv('EESSI_PREFIX') .. "/init/gpu_support"
    -- if we try to load CUDA itself, check if the software exists in host_injections
    -- otherwise, refuse to load CUDA and print error message
    if simpleName == 'CUDA' then
        -- get the full host_injections path
        local hostInjections = string.gsub(os.getenv('EESSI_SOFTWARE_PATH') or "", 'versions', 'host_injections')
        -- build final path where the CUDA software should be installed
        local cudaEasyBuildDir = hostInjections .. "/software/" .. t.modFullName .. "/easybuild"
        local cudaDirExists = exists(cudaEasyBuildDir)
        if not cudaDirExists then
            io.stderr:write("You requested to load ",simpleName,"\\n")
            io.stderr:write("While the module file exists, the actual software is not shipped with EESSI.\\n")
            io.stderr:write("In order to be able to use the CUDA module, please follow the instructions in the\\n")
            io.stderr:write("gpu_support folder. Adding the CUDA software can be as easy as:\\n")
            io.stderr:write("export INSTALL_CUDA=true && ./add_nvidia_gpu_support.sh\\n")
            frameStk:__clear()
        end
    end
    -- when loading CUDA enabled modules check if the necessary matching compatibility libraries are installed
    -- otherwise, refuse to load the requested module and print error message
    local haveGpu = mt:haveProperty(simpleName,"arch","gpu")
    if haveGpu then
        local arch = os.getenv("EESSI_CPU_FAMILY") or ""
        local cudaVersionFile = "/cvmfs/pilot.eessi-hpc.org/host_injections/nvidia/" .. arch .. "/latest/version.txt"
        local cudaDriverExists = exists(cudaVersionFile)
        local singularityCudaExists = exists("/.singularity.d/libs/libcuda.so")
        if not (cudaDriverExists or singularityCudaExists)  then
            io.stderr:write("You requested to load ",simpleName,"\\n")
            io.stderr:write("which relies on the CUDA runtime environment and its compatibility libraries.\\n")
            io.stderr:write("In order to be able to use the module, please follow the instructions in the\\n")
            io.stderr:write("gpu_support folder. Installing the needed compatibility libraries can be as easy as:\\n")
            io.stderr:write("./add_nvidia_gpu_support.sh\\n")
            frameStk:__clear()
        else
            if cudaDriverExists then
                local cudaVersion = read_file(cudaVersionFile)
                local cudaVersion_req = os.getenv("EESSICUDAVERSION")
                local major, minor, patch = string.match(cudaVersion, "(%d+)%.(%d+)%.(%d+)")
                local major_req, minor_req, patch_req = string.match(cudaVersion_req, "(%d+)%.(%d+)%.(%d+)")
                local compat_libs_need_update = false
                if major < major_req then
                    compat_libs_need_update = true
                elseif major == major_req then
                    if minor < minor_req then
                        compat_libs_need_update = true
                    elseif minor == minor_req then
                        if patch < patch_req then
                            compat_libs_need_update = true
                        end
                    end
                end
                if compat_libs_need_update == true then
                    io.stderr:write("You requested to load CUDA version ",cudaVersion)
                    io.stderr:write("but the module you want to load requires CUDA version ",cudaVersion_req,".\\n")
                    io.stderr:write("Please update your CUDA compatibility libraries in order to use ",simpleName,".\\n")
                    frameStk:__clear()
                end
            end
        end
    end
end

hook.register("load", cuda_enabled_load_hook)
hook.register("isVisibleHook", visible_hook)
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
