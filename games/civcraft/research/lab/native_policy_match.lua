-- Full native match for policy export/conformance evidence, in an isolated profile.
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
local config = dofile("/parity_config.lua")
if fs.exists("/exported_policy.lua") then
	config.players[1].policy = dofile("/exported_policy.lua")
end
environment.dofile("/lab/policies.lua").install(config.players)
local Cooperative = environment.dofile("/games/civcraft/cooperative.lua")
local work = {}
local function checkpoint()
	Cooperative.checkpoint(work, false, true)
end
environment.dofile("/games/civcraft/systems.lua").checkpoint = checkpoint
environment.dofile("/games/civcraft/world.lua").checkpoint = checkpoint
local state = Engine.newGame(config)
local started = os.epoch("utc")
local actorStarted, worstActor, peakKilobytes = 0, 0, 0
while not Engine.isFinished(state) and state.round < 270 do
	Engine.pump(state, {
		before = function()
			actorStarted = os.epoch("utc")
		end,
		after = function()
			worstActor = math.max(worstActor, os.epoch("utc") - actorStarted)
		end,
	})
	if not Engine.isFinished(state) then
		Engine.advance(state)
	end
	-- Native adapter work only: no sleeps or gameplay time passes here.
	local ok, memory = pcall(collectgarbage, "count")
	if ok and type(memory) == "number" then
		peakKilobytes = math.max(peakKilobytes, memory)
	end
	pcall(collectgarbage, "collect")
	os.queueEvent("lab_native_yield")
	os.pullEvent("lab_native_yield")
end
local file = assert(fs.open("/full_policy_match.json", "w"))
file.write(textutils.serializeJSON({
	host = _G._HOST,
	round = state.round,
	phase = state.phase,
	winnerIds = state.winnerIDs,
	victoryReason = state.victoryReason,
	gcCycles = work.gcCycles,
	yields = work.yieldToken,
	elapsedMillis = os.epoch("utc") - started,
	worstActorMillis = worstActor,
	peakSampledLuaKilobytes = peakKilobytes,
	canonicalState = Canonical.encode(state),
}))
file.close()
return true
