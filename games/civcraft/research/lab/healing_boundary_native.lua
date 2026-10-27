-- Native CraftOS companion for healing_boundary_validation.py.
local environment = setmetatable({}, { __index = _G })
environment._G = environment
environment.dofile = function(path)
	local file = assert(fs.open(path, "r"))
	local source = file.readAll()
	file.close()
	return assert(load(source, "@" .. path, "t", environment))()
end

environment.dofile("/games/civcraft/module_cache.lua").install(environment)
local Engine = environment.dofile("/lab/engine.lua")
local Canonical = environment.dofile("/lab/canonical.lua")
local Fixture = environment.dofile("/lab/healing_boundary_fixture.lua")

local config = {
	seed = 867530,
	mapSize = "compact",
	mapType = "pangaea",
	hostileMode = "off",
	players = {
		{ civilization = "forge", ai = false },
		{ civilization = "verdant", ai = false },
	},
	maxRounds = 2,
}

local function capture(state)
	return {
		state = Canonical.encode(state),
		observation0 = Canonical.encode(Engine.observe(state, 0)),
		observation1 = Canonical.encode(Engine.observe(state, 1)),
	}
end

local outputs = {}
for _, spec in ipairs(Fixture.cases()) do
	local state = Engine.newGame(config)
	Fixture.setupOnly(state, spec)
	local before = capture(state)
	local result = Fixture.run(state, spec)
	local after = capture(state)
	result.beforeState = before.state
	result.beforeObservation0 = before.observation0
	result.beforeObservation1 = before.observation1
	result.afterState = after.state
	result.afterObservation0 = after.observation0
	result.afterObservation1 = after.observation1
	outputs[#outputs + 1] = result
end

local output = assert(fs.open("/healing_boundary_native.json", "w"))
output.write(textutils.serializeJSON({ config = config, cases = outputs, host = _G._HOST }))
output.close()
return true
