local Modules = dofile("games/civcraft/module_cache.lua")
local calls, fail = {}, true
local function native(path)
	calls[path] = (calls[path] or 0) + 1
	if path == "/games/civcraft/failure.lua" and fail then
		error("deliberate load failure")
	end
	if path == "/games/civcraft/script.lua" then
		return
	end
	return { path = path }
end
local env = { dofile = native }
local cache = Modules.install(env)
local first = env.dofile("/games/civcraft/world.lua")
assert(first == env.dofile("/games/civcraft/world.lua") and calls["/games/civcraft/world.lua"] == 1)
assert(Modules.install(env) == cache)
env.dofile("/other/program.lua")
env.dofile("/other/program.lua")
assert(calls["/other/program.lua"] == 2, "Other programs' loading semantics stay independent")
env.dofile("/games/civcraft/script.lua")
env.dofile("/games/civcraft/script.lua")
assert(
	calls["/games/civcraft/script.lua"] == 2,
	"Entry scripts without a module return still execute"
)
assert(not pcall(env.dofile, "/games/civcraft/failure.lua"))
fail = false
assert(env.dofile("/games/civcraft/failure.lua") and calls["/games/civcraft/failure.lua"] == 2)
local child = setmetatable({ dofile = native }, { __index = env })
Modules.install(child)
assert(
	child.dofile("/games/civcraft/world.lua") ~= first,
	"A new program gets its own modules even with inherited globals"
)
local recursive
recursive = {
	dofile = function(path)
		return recursive.dofile(path)
	end,
}
Modules.install(recursive)
assert(
	not pcall(recursive.dofile, "/games/civcraft/cycle.lua"),
	"Circular loads fail explicitly rather than overflowing"
)
print(
	"CIVCRAFT: internal module reuse, external scripts, nil returns, failure recovery, isolated program globals and cycle detection passed."
)
