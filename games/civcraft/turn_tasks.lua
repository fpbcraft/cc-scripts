-- Required turn decisions, shared by the primary button and end-turn reminders.
local Stacks = dofile("/games/civcraft/unit_stacks.lua")
local Tasks = {}

function Tasks.stamp(state, owner)
	local reaction = state.scheduler and state.scheduler.reactions[owner]
	return tostring(state.round or 1) .. (reaction and ":response" or ":turn")
end

function Tasks.idle(state, unit, owner)
	local partner = Stacks.partner(state, unit)
	local queue = unit.moveQueue or partner and partner.moveQueue
	return not (Stacks.isCivilian(unit) and Stacks.partner(state, unit))
		and not (queue and not queue.paused)
		and not unit.workQueue
		and not (partner and partner.workQueue)
		and unit.owner == owner
		and not unit.standby
		and not unit.autoExplore
		and unit.skippedTurn ~= Tasks.stamp(state, owner)
		and (unit.movesLeft or (unit.moved and 0 or 1)) > 0
end

function Tasks.pending(state, owner, systems)
	local pending = {}
	if not state then
		return pending
	end
	for _, unit in ipairs(state.units or {}) do
		if Tasks.idle(state, unit, owner) then
			pending[#pending + 1] = {
				text = unit.kind .. " at " .. unit.x .. "," .. unit.y .. " has moves left.",
				kind = "unit",
				item = unit,
			}
		end
	end
	for _, city in ipairs(state.cities or {}) do
		if city.owner == owner and not city.project and not city.productionIdle then
			pending[#pending + 1] = {
				text = (city.name or ("City " .. city.x .. "," .. city.y)) .. " has no production.",
				kind = "city",
				item = city,
			}
		end
	end
	for _, player in ipairs(state.players or {}) do
		if player.id == owner and not player.researchTarget then
			for id in pairs(systems.techs) do
				if systems.canResearch(player, id) then
					pending[#pending + 1] = { text = "No research selected.", kind = "research" }
					break
				end
			end
		end
	end
	return pending
end

return Tasks
