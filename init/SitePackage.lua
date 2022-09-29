require("strict")
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

local function cuda_load_hook(t)
	local frameStk  = require("FrameStk"):singleton()
	-- needed to check if we are trying to load the CUDA module
	local simpleName = string.match(t.modFullName, "(.-)/")
	if string.match(simpleName, 'CUDA') ~= nil then
		-- get the full host_injections path
		local cudaDir = string.gsub(os.getenv('EESSI_SOFTWARE_PATH') or "", 'versions', 'host_injections')
		-- build final path where the CUDA software should be installed
		cudaDir = cudaDir .. "/software/" .. t.modFullName
		local cudaDirExists = exists(cudaDir)
		if not cudaDirExists then
			io.stderr:write("You requested to load ",simpleName,"\n")
			io.stderr:write("While the module file exists, the actual software is not shipped with EESSI.\n")
			io.stderr:write("In order to be able to use the CUDA module, please follow the instructions in the\n")
			io.stderr:write("gpu_support folder. Adding the CUDA software can be as easy as a simple:\n")
			io.stderr:write("export INSTALL_CUDA=true && ./add_nvidia_gpu_support.sh\n")
			frameStk:__clear()
		end
	end
end

local function cuda_enabled_load_hook(t)
	local frameStk  = require("FrameStk"):singleton()
	local mt        = frameStk:mt()
	local simpleName = string.match(t.modFullName, "(.-)/")
	local haveGpu = mt:haveProperty(simpleName,"arch","gpu")
	if haveGpu then
		local compatDir = "/cvmfs/pilot.eessi-hpc.org/host_injections/nvidia/latest/compat/"
		local compatDirExists = exists(compatDir)
		if not compatDirExists then
			io.stderr:write("You requested to load ",simpleName,"\n")
			io.stderr:write("While the module file exists, the actual software is not shipped with EESSI.\n")
			io.stderr:write("In order to be able to use the CUDA module, please follow the instructions in the\n")
			io.stderr:write("gpu_support folder. Adding the CUDA software can be as easy as a simple:\n")
			io.stderr:write("./add_nvidia_gpu_support.sh\n")
			frameStk:__clear()
		end
		local cudaVersion = read_file("/cvmfs/pilot.eessi-hpc.org/host_injections/nvidia/latest/version.txt")
		local cudaVersion_req = os.getenv("EESSICUDAVERSION")
		local major, minor, patch = string.match(cudaVersion, "(%d+)%.(%d+)%.(%d+)")
		local major_req, minor_req, patch_req = string.match(cudaVersion, "(%d+)%.(%d+)%.(%d+)")
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
			io.stderr:write("but the module you want to load requires CUDA version ",cudaVersion_req,".\n")
			io.stderr:write("Please update your CUDA compatibility libraries in order to use ",simpleName,".\n")
			frameStk:__clear()
		end
	end
end

hook.register("load", cuda_load_hook)
hook.register("load", cuda_enabled_load_hook)
hook.register("isVisibleHook", visible_hook)
