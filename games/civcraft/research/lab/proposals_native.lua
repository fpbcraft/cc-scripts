-- Small native observer-proposal parity companion.
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
local state = Engine.newGame({
	seed = 75123,
	mapSize = "compact",
	mapType = "continents",
	hostileMode = "off",
	players = {
		{ civilization = "forge", ai = false },
		{ civilization = "scholar", ai = false },
	},
	maxRounds = 4,
})
local proposals, coverage = Engine.legalActions(state, 0)
local metadata = Engine.legalActionMetadata()
local output = assert(fs.open("/proposal_native.json", "w"))
output.write(textutils.serializeJSON({
	host = _G._HOST,
	proposals = Canonical.encode(proposals),
	coverage = coverage,
	metadata = Canonical.encode(metadata),
	state = Canonical.encode(state),
}))
output.close()
return true
