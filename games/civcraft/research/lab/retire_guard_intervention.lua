-- One-time legal strategic decision, not an upkeep or production-rule change.
local Actions = dofile("/games/civcraft/actions.lua")
local Events = dofile("/games/civcraft/events.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Intervention = {}

function Intervention.install(actor, round, count)
	local data, attempted, voluntary = { requests = {}, removals = {} }, false, false
	local original = Events.notice
	Events.notice = function(state, kind, entity, content, recipient)
		if kind == "disband" and entity and entity.owner == actor then
			data.removals[#data.removals + 1] = {
				round = state.round,
				id = entity.id,
				kind = entity.kind,
				hp = entity.hp or 100,
				voluntary = voluntary,
			}
		end
		return original(state, kind, entity, content, recipient)
	end
	local callbacks = {}
	callbacks.before = function(state, player)
		if attempted or player.id ~= actor or state.round ~= round then
			return
		end
		attempted = true
		data.goldBefore, data.netBefore = player.gold, Systems.treasury(player, state).net
		local candidates, totalGuards = {}, 0
		for _, unit in ipairs(state.units or {}) do
			if unit.owner == actor and unit.kind == "warrior" then
				totalGuards = totalGuards + 1
				if (unit.aiRole or {}).name ~= "garrison" and not unit.escortID then
					candidates[#candidates + 1] = unit
				end
			end
		end
		table.sort(candidates, function(a, b)
			if (a.xp or 0) ~= (b.xp or 0) then
				return (a.xp or 0) < (b.xp or 0)
			end
			return a.id < b.id
		end)
		for index = 1, math.min(count, #candidates, math.max(0, totalGuards - 1)) do
			local unit = candidates[index]
			local request = { action = "disband", unitID = unit.id, x = unit.x, y = unit.y }
			voluntary = true
			local ok, why = Actions.apply(state, actor, request, Systems)
			voluntary = false
			data.requests[#data.requests + 1] =
				{ round = state.round, id = unit.id, accepted = ok, reason = why }
		end
		data.goldAfter, data.netAfter = player.gold, Systems.treasury(player, state).net
	end
	return callbacks, data
end

return Intervention
