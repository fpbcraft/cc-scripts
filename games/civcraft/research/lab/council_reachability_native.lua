local environment = setmetatable({}, { __index = _G })
environment._G = environment
environment.dofile = function(path)
	local file = assert(fs.open(path, "r"))
	local source = file.readAll()
	file.close()
	return assert(load(source, "@" .. path, "t", environment))()
end
environment.dofile("/games/civcraft/module_cache.lua").install(environment)
local Audit = environment.dofile("/games/civcraft/research/lab/council_reachability.lua")
local function checkpoint()
	os.queueEvent("council_audit_yield")
	os.pullEvent("council_audit_yield")
end
local result = Audit.run(checkpoint)
local file = assert(fs.open("/council_reachability_native.json", "w"))
file.write(textutils.serializeJSON({ host = _G._HOST, result = result }))
file.close()
return true
