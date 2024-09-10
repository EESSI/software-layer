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
local eessi_prefix = pathJoin(eessi_repo, "versions", eessi_version)
local eessi_os_type = "linux"
setenv("EESSI_VERSION", eessi_version)
setenv("EESSI_CVMFS_REPO", eessi_repo)
setenv("EESSI_OS_TYPE", eessi_os_type)
function archdetect_cpu()
    local script = pathJoin(eessi_prefix, 'init', 'lmod_eessi_archdetect_wrapper.sh')
    if not os.getenv("EESSI_ARCHDETECT_OPTIONS") then
        if convertToCanonical(LmodVersion()) < convertToCanonical("8.6") then
            LmodError("Loading this modulefile requires using Lmod version >= 8.6, but you can export EESSI_ARCHDETECT_OPTIONS to the available cpu architecture in the form of: x86_64/intel/haswell:x86_64/generic or aarch64/neoverse_v1:aarch64/generic")
        end
        source_sh("bash", script)
    end
    local archdetect_options = os.getenv("EESSI_ARCHDETECT_OPTIONS") or ""
    for archdetect_filter_cpu in string.gmatch(archdetect_options, "([^" .. ":" .. "]+)") do
        if isDir(pathJoin(eessi_prefix, "software", eessi_os_type, archdetect_filter_cpu, "software")) then
            -- use x86_64/amd/zen3 for now when AMD Genoa (Zen4) CPU is detected, 
            -- since optimized software installations for Zen4 are a work-in-progress, 
            -- see https://gitlab.com/eessi/support/-/issues/37 
            if archdetect_filter_cpu == "x86_64/amd/zen4" then
                archdetect_filter_cpu = "x86_64/amd/zen3"
                if mode() == "load" then
                    LmodMessage("Sticking to " .. archdetect_filter_cpu .. " for now, since optimized installations for AMD Genoa (Zen4) are a work in progress.")
                end
            end
            return archdetect_filter_cpu
        end
    end
    LmodError("Software directory check for the detected architecture failed")
end
local archdetect = archdetect_cpu()
local eessi_cpu_family = archdetect:match("([^/]+)")
local eessi_software_subdir = archdetect
local eessi_eprefix = pathJoin(eessi_prefix, "compat", eessi_os_type, eessi_cpu_family)
local eessi_software_path = pathJoin(eessi_prefix, "software", eessi_os_type, eessi_software_subdir)
local eessi_module_path = pathJoin(eessi_software_path, "modules", "all")
local eessi_site_module_path = string.gsub(eessi_module_path, "versions", "host_injections")
setenv("EPREFIX",  eessi_eprefix)
setenv("EESSI_CPU_FAMILY", eessi_cpu_family)
setenv("EESSI_SITE_MODULEPATH", eessi_site_module_path)
setenv("EESSI_SOFTWARE_SUBDIR", eessi_software_subdir)
setenv("EESSI_PREFIX", eessi_prefix)
setenv("EESSI_EPREFIX", eessi_eprefix)
prepend_path("PATH", pathJoin(eessi_eprefix, "bin"))
prepend_path("PATH", pathJoin(eessi_eprefix, "usr/bin"))
setenv("EESSI_SOFTWARE_PATH", eessi_software_path)
setenv("EESSI_MODULEPATH", eessi_module_path)
if ( mode() ~= "spider" ) then
    prepend_path("MODULEPATH", eessi_module_path)
end
prepend_path("LMOD_RC", pathJoin(eessi_software_path, "/.lmod/lmodrc.lua"))
prepend_path("MODULEPATH", eessi_site_module_path)
setenv("LMOD_PACKAGE_PATH", pathJoin(eessi_software_path, ".lmod"))
if mode() == "load" then
    LmodMessage("EESSI/" .. eessi_version .. " loaded successfully")
end
