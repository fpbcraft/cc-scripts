-- Pure attack eligibility, independent of diplomacy UI, events and pathfinding.
local CouncilRules = dofile("/games/civcraft/council_rules.lua")
local Hostility = {}
function Hostility.canAttack(state, a, b)
	if a == b or a == nil or b == nil then
		return false
	end
	if CouncilRules.peaceProtected(state, a, b) then
		return false
	end
	local first, second = false, false
	for _, player in ipairs(state.players or {}) do
		first = first or player.id == a
		second = second or player.id == b
	end
	if not first or not second or not state.diplomacy then
		return true
	end
	for _, war in ipairs(state.diplomacy.wars or {}) do
		if war.a == a and war.b == b or war.a == b and war.b == a then
			return war.active == true
		end
	end
	return false
end
return Hostility
