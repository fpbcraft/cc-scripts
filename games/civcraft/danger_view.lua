local Systems = dofile("/games/civcraft/systems.lua")
local Threats = dofile("/games/civcraft/threats.lua")
local World = dofile("/games/civcraft/world.lua")
local Danger = {}

function Danger.update(ui, state, player)
	if not ui.source or not player.id then
		ui.destinationThreats = {}
		return
	end
	if ui.dangerState == state and ui.dangerChoices == ui.reachable then
		return
	end
	ui.dangerState, ui.dangerChoices = state, ui.reachable
	local unit
	for _, current in ipairs(state.units) do
		if current.owner == player.id and current.x == ui.source.x and current.y == ui.source.y then
			unit = current
		end
	end
	ui.destinationThreats = {}
	if not unit then
		return
	end
	local map = Threats.build(state, player, Systems)
	for _, destination in ipairs(ui.reachable or {}) do
		local risk = Threats.at(map, destination.x, destination.y, unit)
		if risk.attackers > 0 then
			ui.destinationThreats[World.key(destination.x, destination.y)] = risk
		end
	end
end

return Danger
