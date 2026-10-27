-- Run the actual bootstraps and installed programs in an in-memory CraftOS disk.
local H = {}
local hostLoadfile, hostLoad = loadfile, load
function H.new()
	local t =
		{ files = {}, dirs = { ["/"] = true }, requests = {}, failDownload = nil, failMove = nil }
	local blocked = {}
	local env = setmetatable({}, {
		__index = function(_, key)
			if not blocked[key] then
				return _G[key]
			end
		end,
	})
	env._G = env
	t.env = env
	local function parent(path)
		return (path:match("^(.*)/[^/]*$") or ""):gsub("^$", "/")
	end
	local fs = {}
	env.fs = fs
	function fs.exists(p)
		return t.files[p] ~= nil or t.dirs[p] == true
	end
	function fs.isDir(p)
		return t.dirs[p] == true
	end
	function fs.getDir(p)
		return parent(p)
	end
	function fs.combine(a, b)
		return (a .. "/" .. b):gsub("//+", "/")
	end
	function fs.makeDir(p)
		local path = ""
		for part in p:gmatch("[^/]+") do
			path = path .. "/" .. part
			t.dirs[path] = true
		end
	end
	function fs.list(p)
		local found = {}
		for _, collection in ipairs({ t.files, t.dirs }) do
			for name in pairs(collection) do
				if name:sub(1, #p + 1) == p .. "/" then
					local child = name:sub(#p + 2):match("^[^/]+")
					if child then
						found[child] = true
					end
				end
			end
		end
		local names = {}
		for name in pairs(found) do
			names[#names + 1] = name
		end
		table.sort(names)
		return names
	end
	function fs.delete(p)
		for _, collection in ipairs({ t.files, t.dirs }) do
			local remove = {}
			for name in pairs(collection) do
				if name == p or name:sub(1, #p + 1) == p .. "/" then
					remove[#remove + 1] = name
				end
			end
			for _, name in ipairs(remove) do
				collection[name] = nil
			end
		end
	end
	function fs.move(a, b)
		if a == t.failMove then
			error("Simulated move failure: " .. a)
		end
		assert(t.files[a] ~= nil, "Missing move source: " .. a)
		assert(not fs.exists(b), "Destination exists: " .. b)
		assert(t.dirs[parent(b)], "Missing destination parent: " .. b)
		t.files[b] = t.files[a]
		t.files[a] = nil
	end
	function fs.open(p, mode)
		if mode == "r" then
			if not t.files[p] then
				return nil
			end
			return {
				readAll = function()
					return t.files[p]
				end,
				read = function(n)
					return t.files[p]:sub(1, n)
				end,
				close = function() end,
			}
		end
		assert(t.dirs[parent(p)], "Parent does not exist: " .. p)
		if p == t.failWrite then
			return nil, "Simulated disk full"
		end
		local body = ""
		return {
			write = function(value)
				body = body .. value
			end,
			close = function()
				t.files[p] = body
			end,
		}
	end
	env.load = function(body, name, mode, scope)
		return hostLoad(body, name, mode, scope or env)
	end
	env.loadfile = function(path, mode, scope)
		if path:sub(1, 1) == "/" then
			if not t.files[path] then
				return nil, "File not installed: " .. path
			end
			return hostLoad(t.files[path], "@" .. path, mode or "t", scope or env)
		end
		return hostLoadfile(path, mode or "t", scope or env)
	end
	env.dofile = function(path)
		local f, e = env.loadfile(path)
		assert(f, e)
		return f()
	end
	env.print = function() end
	env.http = {
		get = function(url)
			t.requests[#t.requests + 1] = url
			if url:find("api.github.com", 1, true) then
				return nil, "Offline API"
			end
			local path = url:match("cc%-scripts/[^/]+/(.-)%?")
				or url:match("cc%-scripts/[^/]+/(.*)")
			if path == t.failDownload then
				return nil, "Simulated HTTP failure"
			end
			local f = path and io.open(path, "r")
			if not f then
				return nil, "Not found: " .. url
			end
			local body = f:read("*a")
			f:close()
			return {
				getResponseCode = function()
					return 200
				end,
				readAll = function()
					return body
				end,
				close = function() end,
			}
		end,
	}
	env.textutils = {
		serialize = function(v)
			local function encode(x)
				if type(x) == "table" then
					local parts = {}
					for k, v in pairs(x) do
						parts[#parts + 1] = "[" .. encode(k) .. "]=" .. encode(v)
					end
					return "{" .. table.concat(parts, ",") .. "}"
				end
				return type(x) == "string" and string.format("%q", x) or tostring(x)
			end
			return encode(v)
		end,
		unserialize = function(s)
			local fn = hostLoad("return " .. s, "@data", "t", {})
			return fn and fn() or nil
		end,
		unserializeJSON = function()
			return nil
		end,
	}
	env.shell = {
		run = function(_, _, _, _, destination)
			fs.makeDir(parent(destination))
			t.files[destination] = "return {}"
			return true
		end,
		getRunningProgram = function()
			return ""
		end,
	}
	function t.withoutRuntime()
		for _, key in ipairs({ "package", "require", "shell" }) do
			blocked[key] = true
			env[key] = nil
		end
	end
	function t.seed(path, body)
		fs.makeDir(parent(path))
		t.files[path] = body
	end
	function t.install(id, ...)
		return assert(env.loadfile("installers/" .. id .. ".lua"))(...)
	end
	function t.run(id, ...)
		local spec = assert(hostLoadfile("lib/fpb/packages.lua"))().packages[id]
		return assert(env.loadfile(spec.root .. "/" .. spec.entry))(...)
	end
	return t
end
return H
