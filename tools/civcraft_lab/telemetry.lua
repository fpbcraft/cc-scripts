-- Optional dispatch instrumentation, isolated to a research runtime's module cache.
local Actions = dofile("/games/civcraft/actions.lua")
local Telemetry = {}

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in pairs(value) do
		result[key] = copy(item)
	end
	return result
end

function Telemetry.install(options)
	local original = Actions.apply
	local data = { attempted = 0, accepted = 0, rejected = 0, reasons = {}, trace = {} }
	local actorCounts, round = {}, nil
	Actions.apply = function(state, actor, request, systems)
		if round ~= state.round then
			actorCounts, round = {}, state.round
		end
		actorCounts[actor] = (actorCounts[actor] or 0) + 1
		assert(actorCounts[actor] <= (options.actionBudget or 4096), "LAB_ACTION_BUDGET")
		data.attempted = data.attempted + 1
		local ok, why, outcome = original(state, actor, request, systems)
		if ok then
			data.accepted = data.accepted + 1
		else
			data.rejected = data.rejected + 1
			data.reasons[tostring(why)] = (data.reasons[tostring(why)] or 0) + 1
		end
		if options.trace then
			data.trace[#data.trace + 1] = {
				round = state.round,
				actor = actor,
				request = copy(request),
				accepted = ok,
				reason = why,
			}
		end
		return ok, why, outcome
	end
	return data
end

return Telemetry
