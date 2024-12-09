help([[
Description
===========
The European Environment for Scientific Software Installations (EESSI, pronounced as easy) is a collaboration between different European partners in HPC community.The goal of this project is to build a common stack of scientific software installations for HPC systems and beyond, including laptops, personal workstations and cloud infrastructure. 

More information
================
 - URL: https://www.eessi.io/docs/
]])
whatis("Description: The European Environment for Scientific Software Installations (EESSI, pronounced as easy) is a collaboration between different European partners in HPC community. The goal of this project is to build a common stack of scientific software installations for HPC systems and beyond, including laptops, personal workstations and cloud infrastructure.")
whatis("URL: https://www.eessi.io/docs/")
conflict("EESSI")
local eessi_version = myModuleVersion()
local eessi_repo = "/cvmfs/software.eessi.io"
if (capture("uname -m"):gsub("\n$","") == "x86_64") then
    eessi_version = "20240402"
    eessi_repo = "/cvmfs/riscv.eessi.io"
    LmodMessage("RISC-V architecture detected, but there is no RISC-V support yet in the production repository.\n" ..
                "Automatically switching to version " .. eessi_version .. " of the RISC-V development repository " .. eessi_repo .. ".\n" ..
                "For more details about this repository, see https://www.eessi.io/docs/repositories/riscv.eessi.io/.")
end
local eessi_prefix = pathJoin(eessi_repo, "versions", eessi_version)
local eessi_os_type = "linux"
setenv("EESSI_VERSION", eessi_version)
setenv("EESSI_CVMFS_REPO", eessi_repo)
setenv("EESSI_OS_TYPE", eessi_os_type)
function eessiDebug(text)
    if (mode() == "load" and os.getenv("EESSI_DEBUG_INIT")) then
        LmodMessage(text)
    end
end
function archdetect_cpu()
    local script = pathJoin(eessi_prefix, 'init', 'lmod_eessi_archdetect_wrapper.sh')
    -- make sure that we grab the value for architecture before the module unsets the environment variable (in unload mode)
    local archdetect_options = os.getenv("EESSI_ARCHDETECT_OPTIONS") or (os.getenv("EESSI_ARCHDETECT_OPTIONS_OVERRIDE") or "")
    if not os.getenv("EESSI_ARCHDETECT_OPTIONS_OVERRIDE") then
        if convertToCanonical(LmodVersion()) < convertToCanonical("8.6") then
            LmodError("Loading this modulefile requires using Lmod version >= 8.6, but you can export EESSI_ARCHDETECT_OPTIONS_OVERRIDE to the available cpu architecture in the form of: x86_64/intel/haswell:x86_64/generic or aarch64/neoverse_v1:aarch64/generic")
        end
        source_sh("bash", script)
    end
    -- EESSI_ARCHDETECT_OPTIONS is set by the script (_if_ it was called)
    archdetect_options = os.getenv("EESSI_ARCHDETECT_OPTIONS") or archdetect_options
    if archdetect_options then
        eessiDebug("Got archdetect CPU options: " .. archdetect_options)
        -- archdetect_options is a colon-separated list of CPU architectures that are compatible with
        -- the host CPU and ordered from most specific to least specific, e.g.,
        --     x86_64/intel/skylake_avx512:x86_64/intel/haswell:x86_64/generic
        -- We loop over the list, and return the highest matching arch for which a directory exists for this EESSI version
        for archdetect_filter_cpu in string.gmatch(archdetect_options, "([^" .. ":" .. "]+)") do
            if isDir(pathJoin(eessi_prefix, "software", eessi_os_type, archdetect_filter_cpu, "software")) then
                -- use x86_64/amd/zen3 for now when AMD Genoa (Zen4) CPU is detected,
                -- since optimized software installations for Zen4 are a work-in-progress,
                -- see https://gitlab.com/eessi/support/-/issues/37
                if (archdetect_filter_cpu == "x86_64/amd/zen4" and not os.getenv("EESSI_SOFTWARE_SUBDIR_OVERRIDE") == "x86_64/amd/zen4") then
                    archdetect_filter_cpu = "x86_64/amd/zen3"
                    if mode() == "load" then
                        LmodMessage("Sticking to " .. archdetect_filter_cpu .. " for now, since optimized installations for AMD Genoa (Zen4) are a work in progress.")
                    end
                end
                eessiDebug("Selected archdetect CPU: " .. archdetect_filter_cpu)
                return archdetect_filter_cpu
            end
        end
        LmodError("Software directory check for the detected architecture failed")
    else
        -- Still need to return something
        return nil
    end
end
function archdetect_accel()
    local script = pathJoin(eessi_prefix, 'init', 'lmod_eessi_archdetect_wrapper_accel.sh')
    -- for unload mode, we need to grab the value before it is unset
    local archdetect_accel = os.getenv("EESSI_ACCEL_SUBDIR") or (os.getenv("EESSI_ACCELERATOR_TARGET_OVERRIDE") or "")
    if not os.getenv("EESSI_ACCELERATOR_TARGET_OVERRIDE ") then
        if convertToCanonical(LmodVersion()) < convertToCanonical("8.6") then
            LmodError("Loading this modulefile requires using Lmod version >= 8.6, but you can export EESSI_ACCELERATOR_TARGET_OVERRIDE to the available accelerator architecture in the form of: accel/nvidia/cc80")
        end
        source_sh("bash", script)
    end
    archdetect_accel = os.getenv("EESSI_ACCEL_SUBDIR") or archdetect_accel
    eessiDebug("Got archdetect accel option: " .. archdetect_accel)
    return archdetect_accel
end
-- archdetect finds the best compatible architecture, e.g., x86_64/amd/zen3
local archdetect = archdetect_cpu()
-- archdetect_accel() attempts to identify an accelerator, e.g., accel/nvidia/cc80
local archdetect_accel = archdetect_accel()
-- eessi_cpu_family is derived from  the archdetect match, e.g., x86_64
local eessi_cpu_family = archdetect:match("([^/]+)")
local eessi_software_subdir = archdetect
-- eessi_eprefix is the base location of the compat layer, e.g., /cvmfs/software.eessi.io/versions/2023.06/compat/linux/x86_64
local eessi_eprefix = pathJoin(eessi_prefix, "compat", eessi_os_type, eessi_cpu_family)
-- eessi_software_path is the location of the software installations, e.g.,
-- /cvmfs/software.eessi.io/versions/2023.06/software/linux/x86_64/amd/zen3
local eessi_software_path = pathJoin(eessi_prefix, "software", eessi_os_type, eessi_software_subdir)
local eessi_modules_subdir = pathJoin("modules", "all")
-- eessi_module_path is the location of the _CPU_ module files, e.g.,
-- /cvmfs/software.eessi.io/versions/2023.06/software/linux/x86_64/amd/zen3/modules/all
local eessi_module_path = pathJoin(eessi_software_path, eessi_modules_subdir)
local eessi_site_software_path = string.gsub(eessi_software_path, "versions", "host_injections")
-- Site module path is the same as the EESSI one, but with `versions` changed to `host_injections`, e.g.,
--  /cvmfs/software.eessi.io/host_injections/2023.06/software/linux/x86_64/amd/zen3/modules/all
local eessi_site_module_path = pathJoin(eessi_site_software_path, eessi_modules_subdir)
setenv("EPREFIX",  eessi_eprefix)
eessiDebug("Setting EPREFIX to " .. eessi_eprefix)
setenv("EESSI_CPU_FAMILY", eessi_cpu_family)
eessiDebug("Setting EESSI_CPU_FAMILY to " .. eessi_cpu_family)
setenv("EESSI_SITE_SOFTWARE_PATH", eessi_site_software_path)
eessiDebug("Setting EESSI_SITE_SOFTWARE_PATH to " .. eessi_site_software_path)
setenv("EESSI_SITE_MODULEPATH", eessi_site_module_path)
eessiDebug("Setting EESSI_SITE_MODULEPATH to " .. eessi_site_module_path)
setenv("EESSI_SOFTWARE_SUBDIR", eessi_software_subdir)
eessiDebug("Setting EESSI_SOFTWARE_SUBDIR to " .. eessi_software_subdir)
setenv("EESSI_PREFIX", eessi_prefix)
eessiDebug("Setting EESSI_PREFIX to " .. eessi_prefix)
setenv("EESSI_EPREFIX", eessi_eprefix)
eessiDebug("Setting EPREFIX to " .. eessi_eprefix)
prepend_path("PATH", pathJoin(eessi_eprefix, "bin"))
eessiDebug("Adding " .. pathJoin(eessi_eprefix, "bin") .. " to PATH")
prepend_path("PATH", pathJoin(eessi_eprefix, "usr", "bin"))
eessiDebug("Adding " .. pathJoin(eessi_eprefix, "usr", "bin") .. " to PATH")
setenv("EESSI_SOFTWARE_PATH", eessi_software_path)
eessiDebug("Setting EESSI_SOFTWARE_PATH to " .. eessi_software_path)
setenv("EESSI_MODULEPATH", eessi_module_path)
eessiDebug("Setting EESSI_MODULEPATH to " .. eessi_module_path)
-- We ship our spider cache, so this location does not need to be spider-ed
if ( mode() ~= "spider" ) then
    prepend_path("MODULEPATH", eessi_module_path)
    eessiDebug("Adding " .. eessi_module_path .. " to MODULEPATH")
end
prepend_path("LMOD_RC", pathJoin(eessi_software_path, ".lmod", "lmodrc.lua"))
eessiDebug("Adding " .. pathJoin(eessi_software_path, ".lmod", "lmodrc.lua") .. " to LMOD_RC")
-- Use pushenv for LMOD_PACKAGE_PATH as this may be set locally by the site
pushenv("LMOD_PACKAGE_PATH", pathJoin(eessi_software_path, ".lmod"))
eessiDebug("Setting LMOD_PACKAGE_PATH to " .. pathJoin(eessi_software_path, ".lmod"))

-- the accelerator may have an empty value and we need to give some flexibility
-- * construct the path we expect to find
-- * then check it exists
-- * then update the modulepath
if not (archdetect_accel == nil or archdetect_accel == '') then
    -- The CPU subdirectory of the accelerator installations is _usually_ the same as host CPU, but this can be overridden
    eessi_accel_software_subdir = os.getenv("EESSI_ACCEL_SOFTWARE_SUBDIR_OVERRIDE") or eessi_software_subdir
    -- CPU location of the accelerator installations, e.g.,
    -- /cvmfs/software.eessi.io/versions/2023.06/software/linux/x86_64/amd/zen3
    eessi_accel_software_path = pathJoin(eessi_prefix, "software", eessi_os_type, eessi_accel_software_subdir)
    -- location of the accelerator modules, e.g.,
    -- /cvmfs/software.eessi.io/versions/2023.06/software/linux/x86_64/amd/zen3/accel/nvidia/cc80/modules/all
    eessi_module_path_accel = pathJoin(eessi_accel_software_path, archdetect_accel, eessi_modules_subdir)
    eessiDebug("Checking if " .. eessi_module_path_accel .. " exists")
    if isDir(eessi_module_path_accel) then
        setenv("EESSI_MODULEPATH_ACCEL", eessi_module_path_accel)
        prepend_path("MODULEPATH", eessi_module_path_accel)
        eessiDebug("Using acclerator modules at: " .. eessi_module_path_accel)
    end
end

-- prepend the site module path last so it has priority
prepend_path("MODULEPATH", eessi_site_module_path)
eessiDebug("Adding " .. eessi_site_module_path .. " to MODULEPATH")
if mode() == "load" then
    LmodMessage("EESSI/" .. eessi_version .. " loaded successfully")
end
