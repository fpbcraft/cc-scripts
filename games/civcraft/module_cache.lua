-- CivCraft uses absolute dofile paths; cache those modules within this program's globals.
local Modules = {}
function Modules.install(environment)
	local installed = rawget(environment, "__civcraftModuleCache")
	if installed then
		return installed
	end
	local native, cache, loading = environment.dofile, {}, {}
	environment.__civcraftModuleCache = cache
	environment.dofile = function(path)
		if type(path) ~= "string" or not path:match("^/games/civcraft/.*%.lua$") then
			return native(path)
		end
		if cache[path] ~= nil then
			return cache[path]
		end
		assert(not loading[path], "Circular CivCraft module: " .. path)
		loading[path] = true
		local ok, result = pcall(native, path)
		loading[path] = nil
		if not ok then
			error(result, 0)
		end
		if result ~= nil then
			cache[path] = result
		end
		return result
	end
	return cache
end
return Modules
