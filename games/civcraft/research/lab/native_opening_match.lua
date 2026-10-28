-- Native conformance for a research-only initial queue intervention.
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
local config = dofile("/opening_config.lua")
environment.dofile("/lab/policies.lua").install(config.players)
local Cooperative = environment.dofile("/games/civcraft/cooperative.lua")
local work = {}
local function checkpoint()
	Cooperative.checkpoint(work, false, true)
end
environment.dofile("/games/civcraft/systems.lua").checkpoint = checkpoint
environment.dofile("/games/civcraft/world.lua").checkpoint = checkpoint
local state = Engine.newGame(config)
local personalities = environment.dofile("/games/civcraft/ai_personalities.lua")
local forge = personalities.forCivilization("forge")
personalities.forCivilization = function()
	local copy = {}
	for key, value in pairs(forge) do
		copy[key] = value
	end
	return copy
end
local initial = Canonical.encode(state)
local options = { trace = true, actionBudget = 4096 }
local telemetry = environment.dofile("/lab/telemetry.lua").install(options)
if config.opening ~= "default" then
	local view = Engine.observe(state, config.targetSeat)
	local city
	for _, c in ipairs(view.cities) do
		if c.owner == config.targetSeat then
			city = c
			break
		end
	end
	assert(Engine.applyAction(state, config.targetSeat, {
		action = "queue",
		kind = config.opening == "scout" and "unit" or "building",
		id = config.opening,
		cityX = city.x,
		cityY = city.y,
	}))
end
while not Engine.isFinished(state) and state.round <= config.maxRounds do
	if state.round > 30 then
		options.trace = false
	end
	Engine.pump(state)
	if Engine.isFinished(state) or state.round >= config.maxRounds then
		break
	end
	Engine.advance(state)
	os.queueEvent("opening_native_yield")
	os.pullEvent("opening_native_yield")
end
local file = assert(fs.open("/opening_result.json", "w"))
file.write(textutils.serializeJSON({
	initialState = initial,
	canonicalState = Canonical.encode(state),
	round = state.round,
	victoryReason = state.victoryReason,
	winnerIds = state.winnerIDs,
	dispatchCounts = {
		attempted = telemetry.attempted,
		accepted = telemetry.accepted,
		rejected = telemetry.rejected,
		reasons = telemetry.reasons,
	},
	host = _G._HOST,
	yields = work.yieldToken,
}))
file.close()
return true
