-- Native CraftOS differential fixture. It never touches production saves.
local environment = setmetatable({}, { __index = _G })
environment._G = environment
environment.dofile = function(path)
	local handle = assert(fs.open(path, "r"))
	local source = handle.readAll()
	handle.close()
	return assert(load(source, "@" .. path, "t", environment))()
end
environment.dofile("/games/civcraft/module_cache.lua").install(environment)
local Engine = environment.dofile("/lab/engine.lua")
local Canonical = environment.dofile("/lab/canonical.lua")
local config = dofile("/parity_config.lua")
environment.dofile("/lab/policies.lua").install(config.players)
local state = Engine.newGame(config)
local checkpoints = {}
local function capture(label)
	checkpoints[#checkpoints + 1] = {
		label = label,
		state = Canonical.encode(state),
		observation = Canonical.encode(Engine.observe(state, 0)),
	}
end
capture("initial")
assert(Engine.applyAction(state, 0, { action = "researchTech", id = "mining" }))
capture("research")
local ok = Engine.applyAction(state, 0, { action = "researchTech", id = "netherite" })
assert(not ok)
capture("rejection")
for round = 1, 3 do
	Engine.pump(state)
	capture("actors" .. round)
	Engine.advance(state)
	capture("boundary" .. round)
end
local output = assert(fs.open("/parity_results.json", "w"))
output.write(textutils.serializeJSON({ host = _G._HOST, checkpoints = checkpoints }))
output.close()
return true
