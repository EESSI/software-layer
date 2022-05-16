require("strict")
local hook = require("Hook")

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

hook.register("isVisibleHook", visible_hook)
