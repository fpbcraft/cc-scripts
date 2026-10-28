-- Isolated native regression fixture for the standard-hostiles capture crash.
-- This intentionally does not repair the production invariant.
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
local config = {
	seed = 95117,
	mapSize = "compact",
	mapType = "pangaea",
	hostileMode = "standard",
	players = {
		{ civilization = "forge" },
		{ civilization = "forge" },
	},
}

local state = Engine.newGame(config)
local successfulAdvances = 0
local status, errorMessage = "finished", nil
for _ = 1, 180 do
	if Engine.isFinished(state) then
		break
	end
	local pumpOK, pumpError = pcall(function()
		Engine.pump(state)
	end)
	if not pumpOK then
		status, errorMessage = "error", tostring(pumpError)
		break
	end
	if Engine.isFinished(state) then
		break
	end
	local advanceOK, advanceError = pcall(function()
		Engine.advance(state)
	end)
	if not advanceOK then
		status, errorMessage = "error", tostring(advanceError)
		break
	end
	successfulAdvances = successfulAdvances + 1
end

local orphanHostileUnits = {}
for _, unit in ipairs(state.units or {}) do
	if unit.owner == -2147483647 and unit.spawner == nil then
		orphanHostileUnits[#orphanHostileUnits + 1] = {
			id = unit.id,
			kind = unit.kind,
			owner = unit.owner,
			x = unit.x,
			y = unit.y,
			spawner = unit.spawner,
			spawnerPresent = unit.spawner ~= nil,
		}
	end
end

local output = assert(fs.open("/hostile_capture_native.json", "w"))
output.write(textutils.serializeJSON({
	status = status,
	error = errorMessage,
	errorRound = status == "error" and state.round or nil,
	completedRounds = status == "error" and state.round - 1 or state.round,
	successfulAdvances = successfulAdvances,
	phase = state.phase,
	host = _G._HOST,
	orphanHostileUnits = orphanHostileUnits,
}))
output.close()
return true
