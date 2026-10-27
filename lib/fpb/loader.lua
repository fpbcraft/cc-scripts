-- A fresh module cache and globals for each program, including shell-less CraftOS.
local L = {}
function L.environment(root, parent, entry)
	parent = parent or _G
	local env = setmetatable({ __fpbRoot = root }, { __index = parent })
	env._G = env
	local cache = {}
	env.package =
		{ path = root .. "/?.lua;" .. root .. "/?/init.lua", loaded = cache, preload = {} }
	if parent.shell then
		env.shell = setmetatable({
			getRunningProgram = function()
				return root .. "/" .. entry
			end,
		}, { __index = parent.shell })
	end
	function env.load(source, name, mode, scope)
		return parent.load(source, name, mode or "t", scope or env)
	end
	function env.loadfile(path, mode, scope)
		return parent.loadfile(path, mode or "t", scope or env)
	end
	function env.dofile(path)
		local fn, err = env.loadfile(path)
		assert(fn, err)
		return fn()
	end
	local prefix = root:sub(2):gsub("/", ".") .. "."
	function env.require(name)
		assert(type(name) == "string", "Module name must be a string")
		if name:sub(1, #prefix) == prefix then
			name = name:sub(#prefix + 1)
		end
		assert(not name:find("..", 1, true) and not name:find("[/\\]"), "Invalid module name")
		if cache[name] ~= nil then
			return cache[name]
		end
		local relative = name:gsub("%.", "/")
		if name:sub(1, 8) == "lib.fpb." then
			relative = "_lib/fpb/" .. name:sub(9):gsub("%.", "/")
		end
		local fn, err = env.loadfile(root .. "/" .. relative .. ".lua")
		if not fn then
			fn, err = env.loadfile(root .. "/" .. relative .. "/init.lua")
		end
		-- Basalt can be supplied by the host or installed beside the program.
		if not fn and name == "basalt" and parent.require then
			return parent.require(name)
		end
		assert(fn, "Cannot load " .. name .. " from " .. root .. ": " .. tostring(err))
		cache[name] = true
		local ok, result = pcall(fn, name)
		if not ok then
			cache[name] = nil
			error(result, 0)
		end
		if result ~= nil then
			cache[name] = result
		end
		return cache[name]
	end
	return env
end
function L.run(root, entry, parent, ...)
	local env = L.environment(root, parent, entry)
	local fn, err = env.loadfile(root .. "/" .. entry)
	assert(fn, err)
	return fn(...)
end
return L
